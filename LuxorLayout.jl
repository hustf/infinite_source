# This file contains imports and functions
# for the `snap` functionality with Drawing(:rec, NaN, NaN)
# Basics are defined first, usable last.

@assert Threads.nthreads() > 1
module LuxorLayout

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
#
# margins_get, margins_set, Margins, 
# scale_limiting_get,
# LIMITING_WIDTH[], LIMITING_HEIGHT[]
########################################

"Ref. `margins_set`"
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

"Ref. `margins_set`"
const MARGINS::Ref{Margins} = Margins()
"Ref. `set-margins`"
margins_get() = MARGINS[]


"""
    margins_set(m::Margins)
    margins_set(;t = margins_get().t, b = margins_get().b, l = margins_get().l, r = margins_get().r)

Margins here merge the .css terms 'margin', 'border' and 'padding'.

Margins are set as unscaled. They are scaled as needed. If m = margins_get(), then
    content height = LIMITING_HEIGHT[] - m.t - m.b
    content width = LIMITING_WIDTH[] - m.l - m.r
"""
margins_set(m::Margins) = begin;MARGINS[] = m;end
function margins_set(;t = margins_get().t, b = margins_get().b, l = margins_get().l, r = margins_get().r)
    margins_set(Margins(t, b, l, r))
end

# TODO: If LIMITING_... is a keeper,
# make the function ..._get, _set_, _reset.
# Be consistent with other mutable containers.
"""
LIMITING_... serves a different purpose from
Drawing.width and Drawing.height.

Output files are limited by both,
so that no limit is exceeded, and aspect ratio 
is preserved.

For example, an image with tall 'inkextent' 
will be limited by LIMITED_HEIGHT.
"""
const LIMITING_WIDTH::Ref{Int64} = 800
const LIMITING_HEIGHT::Ref{Int64} = 800

"""
    scale_limiting_get(;s0 = 1)
    -> ::Float64

Scaling factor from user space to output.
This recursive function finds the scaling factor
which fits the ink extents plus outside margins into 
LIMITING_WIDTH[], LIMITING_HEIGHT[].
"""
function scale_limiting_get(;s0 = 1)
    m = margins_get()
    dw = LIMITING_WIDTH[] 
    dh = LIMITING_HEIGHT[]
    iu = inkextent_user_get()
    uw = boxwidth(iu) + (m.l + m.r) / s0
    uh = boxheight(iu) + (m.t + m.b) / s0
    sw = dw / uw
    sh = dh / uh
    s = min(sw, sh)
    if abs((s / s0) - 1 ) > 0.00001
        # Recursion here
        s = scale_limiting_get(;s0 = s)
    end
    s
end

#########################################
# 2 Inkextent
#   encompass, inkextent_user_with_margin
#   inkextent_reset, inkextent_user_get, 
#   inkextent_set, inkextent_device_get, 
#   point_device_get, point_user_get
#########################################

"""
    inkextent_default()
    --> BoundingBox
Default drawing width, height minus current margins.
"""
function inkextent_default()
    m = margins_get()
    tl = Point(-LIMITING_WIDTH[] / 2, -LIMITING_HEIGHT[] / 2)
    br = -tl
    # Subtract margins, default scale is 1.0.
    BoundingBox(tl + (m.l, m.t), br - (m.r, m.b))
end

# Ink extents are always stored in device ("world") coordinates.
const INK_EXTENT = Ref{BoundingBox}(inkextent_default())
inkextent_set(m::BoundingBox) = INK_EXTENT[] = m

"""
    inkextent_extend(pt; c = _get_current_cr()()())

Update a bounding box to include 'pt' mapped to device coordinates.
Access through `encompass`, which accepts more argument types.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function inkextent_extend(pt; c = _get_current_cr())
    # pt is in user coordinates, i.e., are affected by
    # possibly temporary translations and rotations.
    # We're storing the device / world coordinates instead.
    wpt = point_device_get(pt)
    INK_EXTENT[] += BoundingBox(wpt, wpt)
    nothing
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
inkextent_device_get() = INK_EXTENT[]

"""
    inkextent_user_get()

Return the INK_EXTENT bounding box,
mapped to the user / current coordinate system.
"""
function inkextent_user_get()
    # Two corner points in device coordinates
    bb = inkextent_device_get()
    # Since rotation may be involved in the mapping,
    # two points do not describe a bounding box fully.
    wpts = four_corners(bb)
    c = _get_current_cr()
    # Corners mapped to user coordinates
    upts = map(wpt-> point_user_get(wpt; c), wpts)
    BoundingBox(upts)
end

"""
    inkextent_user_with_margin()
    -> BoundingBox

    Consider INK_EXTENT and margins scaled from LIMITING_..., 
mapped to the user / current coordinate system.
"""
function inkextent_user_with_margin()
    ie = inkextent_user_get()
    s = scale_limiting_get()
    sm = margins_get() * (1 / s)
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
encompass(pt::Point; c = _get_current_cr()) = inkextent_extend(pt; c)
function encompass(pts; c = _get_current_cr())
    @assert isa(pts, Tuple) || !isbits(pts) "pts is a $(typeof(pts)). We can only encompass Point, and containers of Point."
    for pt in pts
        @assert pt isa Point "pt is not a Point, but a $(typeof(pt)), contained in a $(typeof(pts))."
        encompass(pt; c)
    end
    nothing
end

"""
   point_device_get(pt; c = _get_current_cr())

`getworldposition`, but works for limitless surfaces too.
Map from user to device coordinuser_pointates. Related to 'getworldposition', 
'getmatrix', 'juliatocairomatrix', 'cairotojuliamatrix'.

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function point_device_get(pt; c = _get_current_cr())
    # There's a related function in Luxor, 'getworldposition()' we could use,
    # but it returns NaN for boundless recording surfaces.
    # This Cairo function doesn't actually modify the arguments like the '!' indicates.
    wx, wy = user_to_device!(c, [pt.x, pt.y])
    Point(wx, wy)
end
"""
   point_user_get(pt; c = _get_current_cr())

Map from device to user coordinates. Related to 'getworldposition', 'getmatrix', 'juliatocairomatrix',
'cairotojuliamatrix'.

Transform a coordinate from device space to user space by multiplying the given point by the inverse of the current transformation matrix (CTM).

# Argument
- pt    Point in user coordinate system.
# Keyword argument
- c     Pointer to the device context.
"""
function point_user_get(pt; c = _get_current_cr())
    # This Cairo function doesn't actually modify the arguments like the '!' indicates.
    wx, wy = device_to_user!(c, [pt.x, pt.y])
    Point(wx, wy)
end


##################################
# 3 Overlay file
#    This is normally run in a second
#    thread with a separate Cairo 
#    instance.
##################################
const LIMIT_fsize_read_svg = 13705152
"""
    overlay_file(filename, txt)
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
        # Reading large svg files sometimes fail.
        # The error messages user receives can be
        # misleading, because the parser fails in complicated ways.
        # The largest file successfully tested was         20 272kB, made with Luxor.
        # The smallest file with failure we encountered is  9 801kB, made with Inkscape.
        # Issue warning if length(st) > 13705
        st = read(filename, String);
        if length(st) > LIMIT_fsize_read_svg
            println()
            @warn "Size of svg  $(byte_description(length(st))) > $(byte_description(LIMIT_fsize_read_svg))"
        end
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
        # Still, there is no size limit set here.
        st = read(filename, String);
        out = readsvg(st)
    elseif endswith(filename, ".png")
        out = readpng(filename)
    else
        throw("never happens")
    end
    out
end
overlay_file(filename, txt) = overlay_file(filename) do
    setcolor("black")
    setfont("Sans", 24)
    settext(txt, O + (-200, -120); markup=true)
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

byte_description(x) = string(Int64(round(x / 1000))) * "kB "
#####################################
#  4 Snap
#     -> png and svg sequential files
#     -> png in memory
#     uses a second thread
#     to add overlays.
#####################################
const LIMIT_fsize_render_to_png = 5626310
const LIMIT_pixel_render_to_png  = 32767
const LIMIT_pixel_area = 5.7e9
const LIMIT_pixel_area_soft = 5.293e9
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
    snap(txt)
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
    if res.width == 1.0 && res.height == 1.0
        println()
        @warn("After adding overlay, the file $fsvg has width 1.0 and height 1.0 and may be corrupted. 
              Rendering this as a .png might cause crashes. 
              .png output is dropped, and the corrupt svg image is returned instead.
              Examine $fsvg to find out why!")
        return res
    end
    fpng = "$(COUNTIMAGE.value).png"
    # Crashes experienced during Cairo.paint() within the following call
    # to snapshot as png. 
    # We have no definite criterion, but we have this complicated process:
    w = round(boxwidth(cb))
    h = round(boxheight(cb))
    ws = round(w * scalefactor)
    hs = round(h * scalefactor)
    if w * h > LIMIT_pixel_area
        println()
        @warn("crop box w·h > $LIMIT_pixel_area @$(fpng)
                .png output is dropped, and the svg image is returned instead.")
        return res
    elseif w * h > LIMIT_pixel_area_soft
        println()
        @warn("Rendering this as $fpng may allocate too much memory. 
                Crop box width is $w, height $h, w·h = $(w * h) < limit $LIMIT_pixel_area.
                Scaled width is $ws, height $hs, ws·hs = $(ws * hs)
                We may try anyway, good luck!")
    end
    if ws > LIMIT_pixel_render_to_png  || hs > LIMIT_pixel_render_to_png
        println()
        @warn("Rendering this as $fpng exceeds limits for crop box.
              w = $w > $LIMIT_pixel_render_to_png  || h = $h > $LIMIT_pixel_render_to_png
              ws = $ws          hs = $hs 
             We try anyway, good luck!")
    end
    if filesize(fsvg) > LIMIT_fsize_render_to_png && w * h > LIMIT_pixel_area_soft
        @warn("filesize = $(byte_description(filesize(fsvg))) > LIMIT_fsize_render_to_png = $(byte_description(LIMIT_fsize_render_to_png))
             .png output is dropped, and the svg image is returned instead.")
        return res
    end
    printstyled("\t filesize($fsvg) = $(filesize(fsvg)/1000)kB\n", color=:grey)
    snapshot(fpng, cb, scalefactor)
    assert_file_exists(fpng)
    tsk = @tspawnat 2 overlay_file(f_overlay, fpng; fkwds...)
    res = fetch(tsk) # This triggers an error if the task failed, and shows stack traces.
    res
end
function snap(f_overlay::Function; fkwds...)
    outscale = scale_limiting_get(;s0 = 1)
    snap(f_overlay, inkextent_user_with_margin(), outscale; fkwds...)
end
snap(txt::String) = snap() do
    text_on_overlay(txt)
end


"""
    text_on_overlay(txt; 
                    color ="black",
                    fs = 24,
                    family= "Sans",
                    lineheightfac = 1.3, # used to be 7 / 6. Complicated!
                    margleftfrac = 0.05,
                    margtopfrac = 0.05
                    )

Multi-line "Pro-API" text placed at upper left.
Newline character is converted to carriage return.

Overlay coordinates and scale differ from user space,
and font configuration is independent.
Tweaking through keyword arguments, but
writing your own version may be easier.
"""
function text_on_overlay(txt; 
                        color ="black",
                        fs = 24,
                        family= "Sans",
                        lineheightfac = 1.3, # used to be 7 / 6. Complicated!
                        margleftfrac = 0.05,
                        margtopfrac = 0.05
                        )
    setcolor(color)
    setfont(family, fs)
    w = currentdrawing().width
    h = currentdrawing().height
    ctext = replace(txt, "\n" => "\r")
    lins = countlines(IOBuffer(ctext); eol = '\r')
    x = (-0.5 + margleftfrac)w
    y = (-0.5 + margtopfrac)h
    em = fs * lineheightfac
    tl = O + (x, y + em * lins)
    settext(ctext, tl; markup=true)
end
snap() = snap( () -> nothing, inkextent_user_with_margin(), scale_limiting_get())




##########################################
# 5 Utilities for user and debugging below
##########################################
"""
    distance_to_device_origin_get()

What is the distance in user space points due to all of our
transformations so far? How far has the origin moved?
"""
distance_to_device_origin_get() = Int64(round(hypot(point_device_get(Point(0.0,0.0))...)))


"""
    mark_inkextent()

    Outlines inkextent_user_get(). For visual debugging"
"""
function mark_inkextent()
    bb = inkextent_user_get()
    lwi = max(1, 4 / scale_limiting_get())
    @layer begin
        sethue("brown")
        setline(lwi)
        setdash([1, 5] * lwi, 0)
        setlinecap("round")
        box(bb, 5 * lwi, action =:stroke)
    end
    nothing
end

"""
    mark_cs(p; labl = "", color = "", r = 50, dir=:S)

For debugging. Position + axis orientation. Similar to `rulers`.
"""
function mark_cs(p; labl = "", color = "", r = 50, dir=:S)
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

"""
    rotation_device_get()
    -> ∈[-π, π>
Assuming no shear transformation is applied, how much is
user space currently rotated with regards to device space?

Sign:
  - x is right 
  - y is down
  - z is in 
  => positive angle is clockwise

NOTE: Cairo is not always updated after calling rotate(). This is experimental.
"""
function rotation_device_get()
    u = Point(1, 0) - O
    du = point_user_get(Point(1,0)) - point_user_get(O)
    @assert hypot(u...) > 0 && hypot(du...) > 0
    d = du / hypot(du...)
    y = d.x * u.y - d.y * u.x
    x = d.x * u.x + d.y * u.y
    @assert hypot(y, x) == 1
    atan(y, x)
end

end # module
nothing