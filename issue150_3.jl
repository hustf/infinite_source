# This file contains imports and functions
# related to snap(), inkextents(), inkextent_user()
@assert Threads.nthreads() > 1
using Revise, Luxor

"""
    overlay_file(filename, text)
    overlay_file(f_overlay::Function, filename::String)

Annotate finished images. Using threads, we can modify existing files without 
finishing the current drawing as a side effect. 

    # Examples
```
    Drawing(480, 360, "1.png")
    background("coral")
    finish()
    # Start working on another drawing in memory
    Drawing(NaN, NaN, :rec)
    fetch(Threads.@spawn overlay_file("1.png", "ɯ-(ꞋʊꞋ)-ɯ"))
    currentdrawing() # Drawing in memory survived!
```
"""
function overlay_file(f_overlay::Function, filename::String)
    if Threads.nthreads() == 1 && Threads.threadid() == 1
        @info "Running with one thread => The drawing in memory (if any) was overwritten."
    end
    @assert isfile(filename)
    if endswith(filename, ".svg")
        rimg = readsvg(filename)
    elseif endswith(filename, ".png")
        rimg = readpng(filename)
    else
        error("Unknown file suffix: $filename")
    end
    Drawing(rimg.width, rimg.height, filename)
    placeimage(rimg)
    origin()
    f_overlay()
    finish()
    readpng(filename)
end
overlay_file(filename, text) = overlay_file(filename) do 
    setcolor("black")
    setfont("Sans", 24)
    settext(text, O + (-200, -120); markup=true)
end


# This example explores a scripting workstyle with flexible 'source' borders.
# Below are tools for keeping track of where we have drawn something so far. 
# An alternative to keeping track ourselves is `cairo_recording_surface_INK_EXTENT`
# but that is not yet implemented in Cairo.jl.

"A bounding box centered on a point with fixed margins."
bb_with_margin(c::Point) = BoundingBox(c - 0.5 .* (480, 360), c + 0.5 .* (480, 360))
function bb_with_margin(bb::BoundingBox)
    pts = [bb.corner1, bb.corner2, Point(bb.corner1.x, bb.corner2.y), Point(bb.corner2.x, bb.corner1.y)]
    bbs = bb_with_margin.(pts)
    bb = first(bbs)
    bb .+= bbs[2:end]
    bb
end 
start_bb() = bb_with_margin(O)
# Ink extents are always stored in device ("world") coordinates.
const INK_EXTENT = Ref{BoundingBox}(start_bb())
"Include this point with some margin in INK_EXTENT"
function update_INK_EXTENT(pt)
    # pt is referred to the current coordinates, i.e., are affected by
    # possibly temporary translations and rotations. 
    # We're storing the 'world' coordinates instead.
    wx, wy = cairotojuliamatrix(getmatrix()) * [pt.x, pt.y, 1]
    wpt = Point(wx, wy)
    INK_EXTENT[] += BoundingBox(wpt, wpt)
    # temp for checking
    rect_INKEXTENTS()
    nothing;
end

function userpoint(wpt::Point)
    # Current transformation matrix (ctm) - from user to device ("world")
    rma = getmatrix()
    # Surface inverse ctm - for device("world") to user coordinates
    rmai = juliatocairomatrix(cairotojuliamatrix(rma)^-1)
    # World point
    wx, wy = wpt
    x, y, _ = cairotojuliamatrix(rmai) * [wx, wy, 1]
    Point(x, y)
end

"""
Return the INK_EXTENT bounding box,
but mapped to the user / current coordinate system.
"""
function inkextent_user()
    # Corner points in world coordinates
    wpt1, wpt2 = INK_EXTENT[]
    BoundingBox(userpoint(wpt1), userpoint(userpoint(wpt2)))
end

"For debugging"
function rect_INKEXTENTS()
    @layer begin
        setcolor("green")
        setline(10)
        ie = inkextent_user()
        rect(ie.corner1, boxwidth(ie), boxheight(ie), :stroke)
        setline(4)
        setdash("dashed")
        iwm = bb_with_margin(ie)
        rect(ie.corner1, boxwidth(iwm), boxheight(iwm), :stroke)
    end
end
reset_INK_EXTENT() = begin;INK_EXTENT[] = start_bb();nothing;end
"""
    encompass(point or (points))

Update boundaries of drawing including a margin.

    encompass(bb::BoundingBox)

Update boundaries to the union of bb and previous boundaries.
"""
encompass(pt::Point) = update_INK_EXTENT(pt)
encompass(pts::Tuple{P, P}) where {P<:Point} = begin encompass.(pts);nothing;end
encompass(pts::Vector{Point}) = begin encompass.(pts);nothing;end
encompass(bb::BoundingBox) = begin;encompass.(bb);nothing;end

current_scalefactor() = √(480^2 + 360^2) / boxdiagonal(bb_with_margin(inkextent_user()))


"""
A stateful image sequence counter for procedural (aka scripting) work.
For next value: COUNTIMAGE(). For current value: COUNTIMAGE.value
"""
mutable struct Countimage;value::Int;end
(::Countimage)() = COUNTIMAGE.value += 1
const COUNTIMAGE = Countimage(0)



"""
    snap()
    snap(text)
    snap(f_overlay::Function)

  -> png image for display

Output N.svg and N.png to files without changing the state of the current drawing in memory.
N is a global counter, COUNTIMAGE.value.


# Example
```
    Drawing(NaN, NaN, :rec)
    reset_INK_EXTENT() # Not necessary in a fresh session
    background("deepskyblue2")
    setcolor("gold2")
    circle(O, 100, :fill) |> encompass
    setcolor("white")
    setfont("Sans", 100)
    settext("☼", O + (-34, 50); markup=true)
    snap("The sun")
    setline(10)
    ellipse(O, O + (550, 150), 1200, :stroke) |> encompass
    snap("A planetary orbit")
    setline(20)
    ellipse(O, O + (-550, 5500), 7000, :stroke) |> encompass
    snap() do
        setcolor("black")
        circle(O, 3, :fill)
        setcolor("darkgreen")
        settext("Comet's orbit", O + (-100, -120))
        settext("Origin of \nthis overlay", O; markup=true, valign="bottom")
    end
```
"""
function snap(f_overlay::Function, cb::BoundingBox, scalefactor::Float64)
    # Let's store the 
    COUNTIMAGE()
    fsvg = "$(COUNTIMAGE.value).svg"
    snapshot(fsvg, cb, scalefactor)
    Threads.@spawn overlay_file(f_overlay, fsvg)
    fpng = "$(COUNTIMAGE.value).png"
    snapshot(fpng, cb, scalefactor)
    fetch(Threads.@spawn overlay_file(f_overlay, fpng))
end
snap(f_overlay::Function) = snap(f_overlay, bb_with_margin(inkextent_user()), current_scalefactor())
snap(text::String) = snap() do 
    setcolor("black")
    setfont("Sans", 24)
    settext(text, O + (-200, -120); markup=true)
end
snap() = snap( () -> nothing, bb_with_margin(inkextent_user()), current_scalefactor())
