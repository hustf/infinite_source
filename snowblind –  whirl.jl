using Test
using Luxor
# Imports, snap, etc.
include("LuxorLayout.jl")
using .LuxorLayout: margins_set, Margins, scale_limiting_get
using .LuxorLayout: encompass, inkextent_set, inkextent_reset, 
    inkextent_user_with_margin, point_device_get, point_user_get
using .LuxorLayout: snap, countimage_setvalue, text_on_overlay
using .LuxorLayout: mark_inkextent, distance_device_origin
# We have some old images we won't overwrite. Start after:
countimage_setvalue(99)

"A storage for pathified text since font scaling is hard"
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
#    snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)
#
# Most use cases can simply call snap() or snap(overlay)!
#
#############################################################

#####
# 100
#####
Drawing(NaN, NaN, :rec)
background("snow1")
# In this first image, we're going to zoom in when making an image.
# If we were using inkextent_reset(), that would set us up for a larger
# area than intended.
inkextent_set(BoundingBox(Point(-190, -170), Point(360, 50)))
p, θₑ = trail_next_length(150, 0, 0, 0)
translate(p)
rotate(-θₑ)
outscale = scale_limiting_get()
cb = inkextent_user_with_margin()
# The origin of output in user coordinates:
pto = midpoint(cb)
# The current user origin in output coordinates
pt = (O - pto) * outscale
mark_inkextent()
snapshot(;cb, scalefactor = outscale) # No overlay, no file output
function sn_overlay(;pt, scale, txt, markdistance = false, startpt = O)
    if markdistance
        @layer begin
            setopacity(0.5)
            sethue("blue")
            format(x) = string(Int(round(x / (100 * scale)))) * "m"
            offset = -20
            textrotation = -π / 2 -atan(startpt.y - pt.y, startpt.x - pt.x)
            dimension(pt, startpt; format, offset, textrotation)
        end
    end
    @layer begin
        translate(pt)
        ski_tourist(;scale)
    end
    text_on_overlay(txt)
end
txt = """

A sombrero is just a hat. It does not
protect against the sun while skiing.
"""
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)

#####
# 101
#####


txt = """
Sombrerial radius is 40. In this story of caution, 
lengths are in centimeters. The computer knows it not.

Output is 800 points wide or tall. Margins are 24 / 32 points.

We break a trail on a limitless drawing, but update <small>inkextent</small>.

Skis point right for easy reading.
"""
cb = BoundingBox(O + (35, -60), O + (150, 2))
outscale = LuxorLayout.LIMITING_WIDTH[] / boxwidth(cb)
pt = (O - midpoint(cb)) * outscale
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)


#####
# 102
#####

p, θₑ = trail_next_length(283, 0, 0.00095, 0)
translate(p)
rotate(-θₑ)
# Increase default margin, lest the skis poke out
margins_set(;r = 200)
outscale = scale_limiting_get()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
txt = """

Pretty soon, the sombrero-skier will turn 
snowblind. And turn to veering off course.

    <small>inkextent_user_get()</small> is dashed.
"""
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)

#####
# 103
#####
# Revert to default margins
margins_set(Margins())
inkextent_reset() # Back to scale 1:1 for 800x800 pixels
θ´max = 0.00095
p, θₑ = trail_next_length(6000, 0, θ´max, 0)
translate(p)
rotate(-θₑ)
outscale = scale_limiting_get()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
txt = """
Scientists know that sober students, when blindfolded, 
curve around in loops as tight as 20 meter diameter.

Perhaps skis help keep the course better? 
Then again, the students were sober.
"""
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)

#####
# 104
#####

Drawing(NaN, NaN, :rec)
background("snow2")
inkextent_reset()
txt = """

This skier is Mr. Professor Statistician. He assumes the 
20 meter diameter represents 2.25σ in a 
normal distribution of veering samples:
"""
angvel = randn(200) * θ´max / 2.25
for a in angvel
    trail_next_length(1000, 0, a, 0)
end
outscale = scale_limiting_get()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)

#####
# 105
#####

Drawing(NaN, NaN, :rec)
background("snow2")
inkextent_reset()
txt = """

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
angvel = randn(50) * θ´max / 2.25
angacc = randn(50) * θ´max / (2.25 * 100^2)
for (a, acc) in zip(angvel, angacc)
    trail_next_length(10000, 0, a, acc)
end
outscale = scale_limiting_get()
cb = inkextent_user_with_margin()
pt = (O - midpoint(cb)) * outscale
mark_inkextent()
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt)

#####
# 106
#####

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
    outscale = scale_limiting_get()
    cb = inkextent_user_with_margin()
    pt = (O - midpoint(cb)) * outscale
    cb, outscale, pt
end

cb, outscale, pt = randomstep()
txt = """
Mr. Professor, steeped in knowledge, decides to:
- walk μ·π / 4 = 53m
- take a moment of academic contemplation to 
  reset his bearings
- call the above a random step and repeat

After the first random step, direct 
distance from start is $(distance_device_origin() / 100)m.
"""
# Device origin referred to user space
odu = point_user_get(O)
startpt = (odu - midpoint(cb)) * outscale
snap(sn_overlay, cb, outscale; pt, scale = outscale, txt, markdistance = true, startpt) 


###########
# 107 - 109
###########

N = 889
println("Random step no: ")
for i = 2:N
    local cb, outscale, pt = randomstep()
    if i == 2 || 100 < i < 102 || i == N
        local txt = """
        After $i 'random steps' and walking $(round(i * 0.053; digits = 1))km, 
        his straight distance from start is just $(Int(round(distance_device_origin() / 100)))m.
        """
        if i > 100
            txt *= """
            You may need to zoom in to see the trail?
        
            """
        end
        if i > 200
            txt *= """
            Mr. Professor realizes what a poor sod he is, 
            stuck in a nightmare statistics example.

            Why didn't he
            - explain random steps better?
            - use sunglasses?
            - give certain students better marks?
           """
        end
        local startpt = (point_user_get(O)- midpoint(cb)) * outscale
        # This call marks the distance to start in the overlay.
        global sn = snap(sn_overlay, cb, outscale; pt, scale = outscale, txt, markdistance = true, startpt)
    else
        print(i, " ")
    end
end
println()
sn
