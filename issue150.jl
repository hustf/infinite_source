#=
 I hadn't updated packages in a while, since there's no progress on 
 # the text issue, https://github.com/JuliaGraphics/Cairo.jl/issues/349. 
 # These steps fix that issue.

mkdir infinite_source
cd .\infinite_source\
julia --project=. -t=auto # if in vscode settings: "julia.NumThreads": "auto"
(@infinite_source) pkg> gc
(@infinite_source) pkg> update
(@infinite_source) pkg> dev Luxor
(@infinite_source) pkg> add Revise
(@infinite_source) pkg> add Pango_jll
(@infinite_source) pkg> pin Pango_jll@v1.42.4 
(@infinite_source) pkg> status
      Status `C:\Users\frohu_h4g8g6y\.julia\environments\infinite_source\Project.toml`
  [ae8d54c2] Luxor v3.5.0 `C:\Users\frohu_h4g8g6y\.julia\dev\Luxor`
  [295af30f] Revise v3.4.0
  [36c8627f] Pango_jll v1.42.4+10 
=#

# For easy pasting or running this line-by-line in vscode, we drop the prompt, 
# 'julia>' from now on:
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
# An alternative to keeping track ourselves is `cairo_recording_surface_ink_extents`
# but that is not yet implemented in Cairo.jl.

"A bounding box centered on a point with fixed margins."
bb_with_margin(c::Point) = BoundingBox(c - 0.5 .* (480, 360), c + 0.5 .* (480, 360))
start_bb() = bb_with_margin(O)
const INK_EXTENTS = Ref{BoundingBox}(start_bb())
"Include this point with some margin in INK_EXTENTS"
update_INK_EXTENTS(pt) = begin;INK_EXTENTS[] += bb_with_margin(pt);nothing;end
reset_INK_EXTENTS() = begin;INK_EXTENTS[] = start_bb();nothing;end
"""
    encompass(point or (points))

Update boundaries of drawing including a margin.

    encompass(bb::BoundingBox)

Update boundaries to the union of bb and previous boundaries.
"""
encompass(pt::Point) = update_INK_EXTENTS(pt)
encompass(pts::Tuple) = begin encompass.(pts);nothing;end
encompass(pts::Vector) = begin encompass.(pts);nothing;end
encompass(bb::BoundingBox) = begin;INK_EXTENTS[] += bb_with_margin(pt);nothing;end

current_scalefactor() = √(480^2 + 360^2) / boxdiagonal(INK_EXTENTS[])


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
    reset_INK_EXTENTS() # Not necessary in a fresh session
    background("deepskyblue2")
    setcolor("yellow")
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
snap(f_overlay::Function) = snap(f_overlay, INK_EXTENTS[], current_scalefactor())
snap(text::String) = snap() do 
    setcolor("black")
    setfont("Sans", 24)
    settext(text, O + (-200, -120); markup=true)
end
snap() = snap( () -> nothing, INK_EXTENTS[], current_scalefactor())
