# This file contains imports and functions
# related to `snap`:
# Margins, LIMITING_WIDTH / HEIGHT, ink extent
@assert Threads.nthreads() > 1
module AdaptiveScaling

using Revise, Luxor
using Luxor: _get_current_cr
import Luxor.Cairo
using Cairo: user_to_device!, device_to_user!
import ThreadPools
using ThreadPools: @tspawnat
import Base.show
import Base.*

########################################
# 1 Margins and limiting width or height
########################################

"Ref. `set-margins`"
mutable struct Margins
    t::Int64
    b::Int64
    l::Int64
    r::Int64
end
Margins() = Margins(24, 24, 32, 32)
show(io::IO, ::MIME"text/plain", m::Margins) = print(io, "Margins(t = $(m.t), b = $(m.b), l = $(m.l), r = $(m.r))")
function *(m::Margins, x)
    t, b, l, r = m.t, m.b, m.l, m.r
    Margins(round(t * x), round(b * x), round(l * x), round(r * x))
end
"Ref. `set-margins`"
const MARGINS::Ref{Margins} = Margins()
"Ref. `set-margins`"
margins() = MARGINS[]

"Ref. `set-margins`"
function margins_scaled(;scale = get_scale_limiting())
    margins() * scale
end
"""
    set_margins(m::Margins)
    set_margins(;t = margins().t, b = margins().b, l = margins().l, r = margins().r)

Margins here merge the .css terms 'margin', 'border' and 'padding'.

Margins are set as unscaled. They are scaled as needed. If m = margins(), then
    content height = LIMITING_HEIGHT[] - m.t - m.b
    content width = LIMITING_WIDTH[] - m.l - m.r
"""
set_margins(m::Margins) = begin;MARGINS[] = m;end
function set_margins(;t = margins().t, b = margins().b, l = margins().l, r = margins().r)
    set_margins(Margins(t, b, l, r))
end

# Values are from Drawing(). Storing these values here is
# is not quite cool, since Drawing is there for almost the 
# same purpose already. Maybe these ought to be stored in Luxor, if
# Luxor were to include the concept of margins.
# One way to bunch these realated function together would be
# to have a baremodule inside, import functions to here,
# re-export-them: 
# using Luxor.AdaptiveScaling
# would load this into the user's Main module.
const LIMITING_WIDTH::Ref{Int64} = 800
const LIMITING_HEIGHT::Ref{Int64} = 800

"""
    get_scale_limiting(;s0 = 1)
    -> ::Float64

Scaling factor from user space to output.
This recursive function finds the scaling factor
which fits the ink extents plus outside margins into 
LIMITING_WIDTH[], LIMITING_HEIGHT[].
"""
function get_scale_limiting(;s0 = 1)
    m = margins()
    dw = LIMITING_WIDTH[] 
    dh = LIMITING_HEIGHT[]
    uw = boxwidth(inkextent_user()) + (m.l + m.r) / s0
    uh = boxheight(inkextent_user()) + (m.t + m.b) / s0
    sw = dw / uw
    sh = dh / uh
    s = min(sw, sh)
    if abs((s / s0) - 1 ) > 0.00001
        # Recursion here
        s = get_scale_limiting(;s0 = s)
    end
    s
end

"""
    assert_file_exists(filename)
    -> nothing or throws error
"""
function assert_file_exists(filename)
    if !isfile(filename)
        print("filename = $filename in $(pwd()), threadid $(Threads.threadid()) ")
        printstyled("does NOT exist, threadid $(Threads.threadid()).\n", color =:176)
        throw("Don´t call me without the file.")
    end
end

##############
# 2 ink extent
##############

"""
    inkextent_default()
    --> BoundingBox
Default drawing width, height minus current margins.
"""
function inkextent_default()
    m = margins()
    tl = Point(-LIMITING_WIDTH[] / 2, -LIMITING_HEIGHT[] / 2)
    br = -tl
    # Subtract margins, default scale is 1.0.
    BoundingBox(tl + (m.l, m.t), br - (m.r, m.b))
end

# Ink extents are always stored in device ("world") coordinates.
const INK_EXTENT = Ref{BoundingBox}(inkextent_default())
inkextent_set(m::BoundingBox) = INK_EXTENT[] = m



"""
    update_INK_EXTENT(pt; c = _get_current_cr()()())

Update a bounding box to include 'pt' mapped to device coordinates.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function update_INK_EXTENT(pt; c = _get_current_cr())
    # pt is in user coordinates, i.e., are affected by
    # possibly temporary translations and rotations.
    # We're storing the device / world coordinates instead.
    wpt = device_point(pt)
    INK_EXTENT[] += BoundingBox(wpt, wpt)
    nothing
end
"""
   device_point(pt; c = _get_current_cr())

Map from user to device coordinates. Related to 'getworldposition', 'getmatrix', 'juliatocairomatrix',
'cairotojuliamatrix'.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function device_point(pt; c = _get_current_cr())
    # There's a related function in Luxor, 'getworldposition()' we could use,
    # but it returns NaN for boundless recording surfaces.
    # This Cairo function doesn't actually modify the arguments like the '!' indicates.
    wx, wy = user_to_device!(c, [pt.x, pt.y])
    Point(wx, wy)
end
"""
   user_point(pt; c = _get_current_cr())

Map from device to user coordinates. Related to 'getworldposition', 'getmatrix', 'juliatocairomatrix',
'cairotojuliamatrix'.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function user_point(pt; c = _get_current_cr())
    # This Cairo function doesn't actually modify the arguments like the '!' indicates.
    wx, wy = device_to_user!(c, [pt.x, pt.y])
    Point(wx, wy)
end

"""
    four_corners(bb::BoundingBox)

When dealing with user space, a bounding box is described fully by two points.
When rotating to device space, the other two corners matter as well.

Similar to `Luxor.box`, but doesn't create a path.
"""
function four_corners(bb::BoundingBox)
    wpt1, wpt3 = bb
    wpt2 = Point(wpt3.x, wpt1.y)
    wpt4 = Point(wpt1.x, wpt3.y)
    [wpt1, wpt2, wpt3, wpt4]
end

"""
Return the INK_EXTENT bounding box in device
coordinates.
"""
inkextent_device() = INK_EXTENT[]

"""
Return the INK_EXTENT bounding box,
mapped to the user / current coordinate system.
"""
function inkextent_user()
    # Two corner points in device coordinates
    bb = inkextent_device()
    # Since rotation may be involved in the mapping,
    # two points do not describe a bounding box fully.
    wpts = four_corners(bb)
    c = _get_current_cr()
    # Corners mapped to user coordinates
    upts = map(wpt-> user_point(wpt; c), wpts)
    BoundingBox(upts)
end

"""
    inkextent_user_with_margin()
    -> BoundingBox

    Consider INK_EXTENT and margins scaled from LIMITING_..., 
mapped to the user / current coordinate system.
"""
function inkextent_user_with_margin()
    ie = inkextent_user()
    s = get_scale_limiting()
    sm = margins() * (1 / s)
    tl = ie.corner1 + (-sm.l, -sm.t)
    br = ie.corner2 + (sm.r, sm.b)
    BoundingBox(tl, br)
end

function inkextent_reset()
    INK_EXTENT[] = inkextent_default()
end

"""
    encompass(point)
    encompass(pts)

Update inkextents to also include point or pts. 
Pts may be a Vector, Tuple or other containers of points.
"""
encompass(pt::Point; c = _get_current_cr()) = update_INK_EXTENT(pt; c)
function encompass(pts; c = _get_current_cr())
    @assert isa(pts, Tuple) || !isbits(pts) "pts is a $(typeof(pts)). We can only encompass Point, and containers of Point."
    for pt in pts
        @assert pt isa Point "pt is not a Point, but a $(typeof(pt)), contained in a $(typeof(pts))."
        encompass(pt; c)
    end
    nothing
end


##################################
# 3 Overlay file
#    This is normally run in a second
#    thread with a separate Cairo 
#    instance.
##################################
"""
    overlay_file(filename, text)
    overlay_file(f_overlay::Function, filename::String)
    overlay_file(f_overlay::Function, filename::String; fkwds)

Annotate finished images. Using a second thread of execution, we can modify
existing files, without finishing the current drawing in memory.

    # Examples
```
    Drawing(480, 360, "1.png")
    background("coral")
    finish()
    # Start working on another drawing in memory
    Drawing(NaN, NaN, :rec)
    fetch(@tspawnat 2 overlay_file("1.png", "ɯ-(ꞋʊꞋ)-ɯ"))
    currentdrawing() # Drawing in memory survived!
```

If simply placing text over the image is not satisfactory, pass in a function 'f_overlay'.
`f_overlay` will run in a context where the 'filename' drawing is the current one.
  - origin is initally at the middle
  - access currentdrawing().height and currentdrawing().width
  - states of hue, opacity, stroke width and line style may be different.
  - current scale is 1, i.e:

       lowerleft = Point(currentdrawing().width / 2, currentdrawing().height / 2)
  - if any scaling was applied when 'filename' was produced, this is lost. Use the keywords
    to pass such information to the overlay. Alternatively, define 'f_overlay' with captured variables.

You can pass your own keyword arguments to `f_overlay` (if you define it to take such arguments!).
"""
function overlay_file(f_overlay::Function, filename::String; fkwds...)
    if !isempty(fkwds)
        if first(fkwds)[1] == :fkwds
            throw(ArgumentError("Optional keywords: Use splatting in call: fkwds..."))
        end
    end
    assert_second_thread()
    assert_file_exists(filename)
    if endswith(filename, ".svg")
        # The following line failed for a large file. The smallest file with failure was 9801Kb.
        # rimg = readsvg(filename) 
        # Ref. https://github.com/lobingera/Rsvg.jl/issues/26 - the fix seems to be 
        # implemented for large strings, but not for reading directly from file.
        st = read(filename, String);
        rimg = readsvg(st)
    elseif endswith(filename, ".png")
        rimg = readpng(filename)
    else
        throw("Unknown file suffix for overlay: $filename")
    end
    Drawing(rimg.width, rimg.height, filename)
    placeimage(rimg)
    @layer begin
        # Place origin at centre
        origin()
        # Call user overlay function
        if isempty(fkwds)
            f_overlay()
        else
            f_overlay(;fkwds...)
        end
    end
    finish()
    if endswith(filename, ".svg")
        # Reading the overlain svg is more complicated (often includes text)
        # than necessary, and errors are sometimes triggered at this step.
        # Currently, there is no size limit set here.
        st = read(filename, String);
        out = readsvg(st)
    elseif endswith(filename, ".png")
        out = readpng(filename)
    else
        throw("never happens")
    end
    out
end
overlay_file(filename, text) = overlay_file(filename) do
    setcolor("black")
    setfont("Sans", 24)
    settext(text, O + (-200, -120); markup=true)
end


"""
    assert_second_thread()
    -> nothing or throws error
"""
function assert_second_thread()
    if Threads.nthreads() == 1
        printstyled("Creating overlay with one thread => The drawing in memory (if any) is overwritten.\n", color=:yellow) 
    end
    if Threads.threadid() == 1
        printstyled("Creating overlay while threadid() == 1 is unexpected. \nNormal usage is `@tspawnat 2 overlay_file(...)`.\n", color=:yellow)
        throw("Currently not allowed, debugging!")
    end
    Threads.nthreads() == 1 && throw("Minumum two threads required now.")
end


#####################################
#  4 snap
#     -> png and svg sequential files
#     -> png in memory
#     uses a second thread
#     to add overlays.
# 
#####################################


"""
A stateful image sequence counter for procedural (aka scripting) work.
For next value: COUNTIMAGE(). For current value: COUNTIMAGE.value
"""
mutable struct Countimage;value::Int;end
(::Countimage)() = COUNTIMAGE.value += 1
const COUNTIMAGE = Countimage(0)
countimage_setvalue(n) = COUNTIMAGE.value = n

"""
    snap()
    snap(text)
    snap(f_overlay::Function)
    snap(f_overlay::Function; yourkeyword = Point(2,2))

  -> png image for display
  -> Output N.svg and N.png to files without changing the state of the current drawing in memory.
N is a global counter, COUNTIMAGE.value.

You can pass a function `f_overlay` which draws on top of the produced image files. See 'overlay_file'.
You can also pass keyword argument to that function, for example telling it about scales and margins.

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
function snap(f_overlay::Function, cb::BoundingBox, scalefactor::Float64; fkwds...)
    # Update counter to the next value.
    COUNTIMAGE()
    fsvg = "$(COUNTIMAGE.value).svg"
    snapshot(fsvg, cb, scalefactor)
    assert_file_exists(fsvg)
    tsk = @tspawnat 2 overlay_file(f_overlay, fsvg; fkwds...)
    res = fetch(tsk) # This triggers an error if the task failed, and shows stack traces.
    @assert res isa Luxor.SVGimage
    fpng = "$(COUNTIMAGE.value).png"
    # Crashes experienced during Cairo.paint() within the following call
    # to snapshot. Seems related to large allocations.
    # Writing the corresponding svg was OK. The .svg file size was 6237 kB.
    if filesize(fsvg) > 6237000
        @warn "The $fsvg file size was $(filesize(fsvg)/1000)kB > 6237kB. Rendering this as a png may allocate too much memory. \n .png output is dropped, and the svg image is returned instead."
        return res
    else
        snapshot(fpng, cb, scalefactor)
        assert_file_exists(fpng)
    end
    tsk = @tspawnat 2 overlay_file(f_overlay, fpng; fkwds...)
    res = fetch(tsk) # This triggers an error if the task failed, and shows stack traces.
    res
end
function snap(f_overlay::Function; fkwds...)
    outscale = get_scale_limiting(;s0 = 1)
    snap(f_overlay, inkextent_user_with_margin(), outscale; fkwds...)
end
snap(text::String) = snap() do
    _text_on_overlay(text)
end
function _text_on_overlay(text)
    setcolor("black")
    fs = 24
    setfont("Sans", 24)
    em = fs * 1.3 # used to be 7 / 6. Complicated!
    w = currentdrawing().width
    h = currentdrawing().height
    ctext = replace(text, "\n" => "\r")
    lins = countlines(IOBuffer(ctext); eol = '\r')
    settext(ctext, O + (-0.45w, -0.45h + em * lins); markup=true)
end
snap() = snap( () -> nothing, inkextent_user_with_margin(), get_scale_limiting())




########################################
# Utilities for user and debugging below
########################################
"""
    distance_device_origin()

What is the distance in user space points due to all of our
transformations so far? How far has the origin moved?
"""
distance_device_origin() = Int64(round(hypot(device_point(Point(0.0,0.0))...)))


"""
    mark_inkextent()

    Outlines inkextent_user(). For visual debugging"
"""
function mark_inkextent()
    bb = inkextent_user()
    lwi = max(1, 4 / get_scale_limiting())
    @layer begin
        sethue("brown")
        setline(lwi)
        setdash([1, 5] * lwi, 0)
        setlinecap("round")
        box(bb, 5 * lwi, action =:stroke)
    end
    nothing
end

roundpt(pt) = Point(round(pt.x), round(pt.y))

"For debugging. Position + axis orientation."
function markcs(p; labl = "", color = "", r = 50, dir=:S)
    @layer begin
        setopacity(0.5)
        color !== "" && sethue(color)
        circle(p, r,:stroke)
        line(p, p + (r, 0), :stroke)
        line(p, p + (0, r), :stroke)
        setopacity(1.0)
        label("$labl $p", dir, p; leader=true)
    end
end
end # module
nothing