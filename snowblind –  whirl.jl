# Imports, snap, etc.
include("AdaptiveScaling.jl")
using .AdaptiveScaling: countimage_setvalue, inkextent_set, encompass,
    snap, get_scale_limiting, inkextent_user_with_margin, mark_inkextent
using Test
using Luxor
# We have some old images we won't overwrite. Start after:
countimage_setvalue(99)

"A storage for some text since font scaling is hard"
const SKI_DECAL = Ref{Path}(Path([PathClose()]))

# Example specifics
include("drawingfuncs.jl")

#############################################################
#
# Note, we're not starting with a simple overlay here. 
# Our overlay needs to know the scaling from user scale
# to output scale (800 x 800), as well as the position
# of the user space orgin relative to the output image.
# The overlay function use this to place a 'sprite' at the
# current user-space origin.
# Hence, we calculate these scales and positions explicitly,
# and then convey these as keywords to the 'overlay' function
# through 
#    snap(overlay, cb, outscale; pt, scale = outscale, text)
#
# Most use cases can simply call snap() or snap(overlay)!
#
#############################################################

###
# 1
###
Drawing(NaN, NaN, :rec)
background("snow1")
# In this first image, we're going to zoom in when making an image.
# If we were using inkextent_reset(), that would set us up for a larger
# area than intended.
inkextent_set(BoundingBox(Point(-190, -170), Point(360, 50)))
p, θₑ = trail_next_length(150, 0, 0, 0)
translate(p)
rotate(-θₑ)
outscale = get_scale_limiting()
cb = inkextent_user_with_margin()
# The origin of output in user coordinates:
pto = midpoint(cb)
# The current user origin in output coordinates
pt = (O - pto) * outscale
mark_inkextent()
snapshot(;cb, scalefactor = outscale) # No overlay, no file output
function overlay(;pt, scale, text)
    @layer begin
        translate(pt)
        ski_tourist(;scale)
    end
    _text_on_overlay(text)
end
text = """

A sombrero is just a hat. It does not
protect against the sun while skiing.
"""
snap(overlay, cb, outscale; pt, scale = outscale, text)

###
# 2
###

p, θₑ = trail_next_length(283, 0, 0.00095, 0)
translate(p)
rotate(-θₑ)
# Increase default margin, lest the skis poke out
set_margins(;r = 200)
outscale = get_scale_limiting()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
text = """

Pretty soon, the sombrero-skier will turn 
snowblind. And turn to veering off course.
"""
snap(overlay, cb, outscale; pt, scale = outscale, text)

###
# 3
###
# Revert to default margins
set_margins(Margins())
inkextent_reset() # Back to scale 1:1 for 800x800 pixels
θ´max = 0.00095
p, θₑ = trail_next_length(6000, 0, θ´max, 0)
translate(p)
rotate(-θₑ)
outscale = get_scale_limiting()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
text = """
Scientists know that sober students, when blindfolded, 
curve around in loops as tight as 20 meter diameter.

Perhaps skis help keep the course better? 
Then again, the students were sober.
"""
snap(overlay, cb, outscale; pt, scale = outscale, text)

###
# 4
###

Drawing(NaN, NaN, :rec)
background("snow2")
inkextent_reset()
text = """

This skier is Mr. Professor Statistician. He assumes the 
20 meter diameter represents 2.25σ in a 
normal distribution of veering samples:
"""
angvel = randn(200) * θ´max / 2.25
for a in angvel
    trail_next_length(1000, 0, a, 0)
end
outscale = get_scale_limiting()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
snap(overlay, cb, outscale; pt, scale = outscale, text)

###
# 5
###

Drawing(NaN, NaN, :rec)
background("snow2")
inkextent_reset()
text = """

The most probable diameter of veering is,
most probably, μ = 67m. Probably. 
And veering probably changes linearly while walking.
Professor expects to walk in Euler spirals, not circles.
"""
@layer begin 
    sethue("green")
    r = 6700 / 2 #cm
    setopacity(0.2)
    circle(O + (0, r), r, :fill) |> encompass
end
angvel = randn(20) * θ´max / 2.25
angacc = randn(20) * θ´max / (2.25 * 100^2)
for (a, acc) in zip(angvel, angacc)
    trail_next_length(10000, 0, a, acc)
end
outscale = get_scale_limiting()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
snap(overlay, cb, outscale; pt, scale = outscale, text)

###
# 6
###

Drawing(NaN, NaN, :rec)
background("snow2")
inkextent_reset()
function randomstep()
    angle = 0.05 * rand() * 2π
    angvel = randn(1)[1] * θ´max / 2.25
    angacc = randn(1)[1] * θ´max / (2.25 * 100^2)
    p, θₑ = trail_next_length(5300, angle, angvel, angacc)
    translate(p)
    rotate(-θₑ)
    outscale = get_scale_limiting()
    cb = inkextent_user_with_margin()
    pt = (O - midpoint(cb)) * outscale
    cb, outscale, pt
end

cb, outscale, pt = randomstep()
text = """
Mr. Professor, steeped in knowledge, decides to:
- walk μ·π / 4 = 53m
- take a moment of academic contemplation to 
  reset his bearings
- call the above a random step and repeat

After the first random step, direct 
distance from start is $(distance_device_origin() / 100)m.
"""
snap(overlay, cb, outscale; pt, scale = outscale, text)

###
# 7
###

N = 500

for i = 2:N
    local cb, outscale, pt = randomstep()
    println(i)
    if i == N
        local text = """
        After $i 'random steps' and walking $(round(i * 0.053; digits = 1))km, 
        his straight distance from start is just $(distance_device_origin() / 100)m.
        You may need to zoom in to see the trail?
        
        Mr. Professor now realizes what a poor sod he is, 
        stuck in a nightmare statistics example.

        Why didn't he
        - explain random steps better?
        - use sunglasses?
        - give certain students better marks?
        """
        global sn = snap(overlay, cb, outscale; pt, scale = outscale, text)
    end
end
sn