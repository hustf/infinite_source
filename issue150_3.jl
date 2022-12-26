# This file contains imports and functions
# related to snap(), inkextents(), inkextent_user()
@assert Threads.nthreads() > 1
using Revise, Luxor
using Luxor: get_current_cr
import Luxor.Cairo
using Cairo: user_to_device!, device_to_user!
import Base.show
mutable struct Margins
    t::Int64
    b::Int64
    l::Int64
    r::Int64
end
Margins(;t = 24, b = 24, l = 32, r = 32) = Margins(t, b, l, r)
show(io::IO, ::MIME"text/plain", m::Margins) = print(io, "Margins(t = $(m.t), b = $(m.b), l = $(m.l), r = $(m.r))")
"Margins outside of ink extents, in pixel / user / canvas coordinates"
const MARGINS::Ref{Margins} = Margins()
margins() = MARGINS[]
set_margins(m::Margins) = begin;MARGINS[] = m;end
# Values from Drawing()
const DEFAULT_DRAWING_WIDTH = 800
const DEFAULT_DRAWING_HEIGHT = 800

function inkextent_default()
    m = margins()
    bl = Point(-DEFAULT_DRAWING_WIDTH / 2, -DEFAULT_DRAWING_HEIGHT / 2)
    tr = -bl
    # Subtract margins, scale from device to user is 1.0.
    BoundingBox(bl + (m.l, m.b), tr - (m.r, m.t))
end 

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

"A bounding box centered on a point, including margins."
function bb_with_margin(c::Point)
    m = margins() # user size margins
    bl = c - Point(m.l, m.b)
    tr = c + Point(m.r, m.t)
    BoundingBox(bl, tr)
end
function bb_with_margin(bb::BoundingBox)
    pts = [bb.corner1, bb.corner2, Point(bb.corner1.x, bb.corner2.y), Point(bb.corner2.x, bb.corner1.y)]
    bbs = bb_with_margin.(pts)
    bb = first(bbs)
    for b in bbs[2:end]
        bb += b
    end
    bb
end 
# Ink extents are always stored in device ("world") coordinates.
const INK_EXTENT = Ref{BoundingBox}(inkextent_default())
"""
    update_INK_EXTENT(pt; c = get_current_cr())

Update a bounding box to include 'pt' mapped to device coordinates.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function update_INK_EXTENT(pt; c = get_current_cr())
    # pt is in user coordinates, i.e., are affected by
    # possibly temporary translations and rotations. 
    # We're storing the device / world coordinates instead.
    wpt = device_point(pt)
    INK_EXTENT[] += BoundingBox(wpt, wpt)
    # TEMP for checking
    rect_INKEXTENT()
    nothing
end
"""
   device_point(pt; c = get_current_cr())

Map from user to device coordinates. Related to 'getworldposition', 'getmatrix', 'juliatocairomatrix',
'cairotojuliamatrix'.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function device_point(pt; c = get_current_cr())
    # There's a related function in Luxor, 'getworldposition()' we could use,
    # but it returns NaN for boundless recording surfaces.
    # This Cairo function doesn't actually modify the arguments like the '!' indicates.
    wx, wy = user_to_device!(c, [pt.x, pt.y])
    Point(wx, wy)
end
"""
   user_point(pt; c = get_current_cr())

Map from device to user coordinates. Related to 'getworldposition', 'getmatrix', 'juliatocairomatrix',
'cairotojuliamatrix'.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function user_point(pt; c = get_current_cr())
    # This Cairo function doesn't actually modify the arguments like the '!' indicates.
    wx, wy = device_to_user!(c, [pt.x, pt.y])
    Point(wx, wy)
end

"""
    four_corners(bb::BoundingBox)

When dealing with user space, a bounding box is described fully by two points.
When rotating to device space, the other two corners matter as well.
"""
function four_corners(bb::BoundingBox)
    wpt1, wpt3 = bb
    wpt2 = Point(wpt3.x, wpt1.y)
    wpt4 = Point(wpt1.x, wpt3.y)
    [wpt1, wpt2, wpt3, wpt4]
end
"""
Return the INK_EXTENT bounding box,
mapped to the user / current coordinate system.
"""
function inkextent_user()
    # Corner points in device coordinates
    bb = INK_EXTENT[]
    wpts = four_corners(bb)
    c = get_current_cr()
    # Corners mapped to user coordinates
    upts = map(wpt-> user_point(wpt; c), wpts)
    BoundingBox(upts)
end

"For debugging"
function rect_INKEXTENT()
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
function inkextent_reset()
    INK_EXTENT[] = inkextent_default()
end

"""
    encompass(point or (points))

Update boundaries of drawing including a margin.

    encompass(bb::BoundingBox)

Update boundaries to the union of bb and previous boundaries.
"""
encompass(pt::Point; c = get_current_cr()) = update_INK_EXTENT(pt; c)
function encompass(pts; c = get_current_cr())
    for pt in pts
        @assert pt isa Point "pt is not a Point, but a $(typeof(pt)) contained in a $(typeof(pts))"
        encompass(pt; c)
    end
    nothing
end

"""
    get_scale_inkextents_margins()

Not quite sure that this is needed, but there is some complexity regarding margins.
If not needed, `getscale` will do the trick.
"""
function get_scale_inkextents_margins()
    m = margins()
    bl, tr = inkextent_user()
    bbw = INK_EXTENT[]
    userwidth = m.l + m.r + boxwidth(bbw)
    userheight = m.t + m.b + boxheight(bbw)
    userdiagonal = √(userwidth^2 + userheight^2)
    # The margins, in 'world' coordinates, depend upon the current scaling
    sx, sy = getscale()
    worldwidth = userwidth / sx
    worldheight = userheight / sy
    worlddiagonal = √(worldwidth^2 + worldheight^2)
    userdiagonal / worlddiagonal
end

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
    inkextent_reset() # Not necessary in a fresh session
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
snap(f_overlay::Function) = snap(f_overlay, bb_with_margin(inkextent_user()), get_scale_inkextents_margins())
snap(text::String) = snap() do 
    setcolor("black")
    setfont("Sans", 24)
    settext(text, O + (-200, -120); markup=true)
end
snap() = snap( () -> nothing, bb_with_margin(inkextent_user()), get_scale_inkextents_margins())

#= Dead code; scaling works anyway!
function scaled_path(pt::Path, sc)
    nv = Vector{PathElement}()
    for pe in pt
        ne = scaled_path_element(pe, sc)
        push!(nv, ne)
    end
    Path(nv)
end
function scaled_path_element(pe::T, sc) where {T<:PathElement}
    v = Vector{Any}()
    for i in 1:nfields(pe)
        detail = getfield(pe, i)
        newdetail = scaled_path_detail(detail, sc)
        push!(v, newdetail)
    end
    T(v...)
end
function scaled_path_detail(pe::Point, sc)
    pe * sc
end
=#