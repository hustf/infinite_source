# Imports, snap etc.:
include("AdaptiveScaling.jl")
using .AdaptiveScaling: countimage_setvalue
using Test
using Luxor
# We have some old images we won't overwrite. Start after:
countimage_setvalue(19)

using Test
function overlay(; pt)
    # The origin here, o4, overlaps o1.
    markcs(O; labl = "o4", color = "black", r = 70, dir=:SW)
    markcs(roundpt(pt); labl = "pt4", color = "white", r = 80, dir=:SE)
    translate(pt)
    markcs(O; labl = "o5", color = "navy", r = 90, dir=:E)
end 

@testset "Target a user space point in an overlay." begin
    @testset "Rotation, but no ink extension past default." begin
        Drawing(NaN, NaN, :rec)
        background("coral")
        inkextent_reset()
        sethue("grey")
        markcs(O, labl = "o1", color = "red", r = 20)
        p = O + (200, -50)
        p |> encompass
        θ = π / 6
        markcs(p, labl = "p1", dir =:S, color = "green", r = 30)
        brush(O, p, 2)
        translate(p)
        markcs(O, labl = "o2", dir =:E, color = "blue", r = 40)
        rotate(-θ)
        markcs(O, labl = "o3", dir =:NW, color = "yellow", r = 50)
        @test device_point(O) == p 
        outscale = get_scale_limiting()
        cb = inkextent_user_with_margin()
        # The origin of output in user coordinates:
        pto = midpoint(cb)
        markcs(roundpt(pto), labl = "pto", dir =:SE, color = "indigo", r = 60)
        # The current user origin in output coordinates
        pt = (O - pto) * outscale
        snapshot(;cb, scalefactor = outscale) # No overlay, no file output
        snap("""
            An overlay is a transparent graphic that is applied
            on top of another while saving with <small>snap()</small>.
            This text is an overlay to the circles.

            <b>test_snap.jl</b> explores the problem:

            <i>Having defined one or several points in user space,
            how can we target those points in an overlay?</i>

            Two steps to a solution:

            1) We need to find 
            the mapping from 
            <i>user</i> space to
            <i>overlay</i> space

            2) Pass that info to the overlay function.

            We could capture info in an argument-less definintion of an 
            overlay function. We would then need to redefine 'overlay' when
            the info changes.

            Here, we define <small>overlay(;pt)</small>. The value of 'pt' can change.
            """)
        # `snap` will gobble up any keywords and pass them on to 'overlay'.
        snap(overlay, cb, outscale; pt)
    end
    @testset "Rotation and also ink extension." begin
        Drawing(NaN, NaN, :rec)
        background("darksalmon")
        inkextent_reset()
        sethue("grey")
        markcs(O, labl = "o1", color = "red", r = 20)
        p = O + 3 .* (200, -50)
        p |> encompass
        θ = π / 6
        markcs(p, labl = "p1", dir =:S, color = "green", r = 30)
        brush(O, p, 2)
        translate(p)
        markcs(O, labl = "o2", dir =:E, color = "blue", r = 40)
        rotate(-θ)
        markcs(O, labl = "o3", dir =:NW, color = "yellow", r = 50)
        @test device_point(O) == p 
        outscale = get_scale_limiting()
        cb = inkextent_user_with_margin()
        # The origin of output in user coordinates:
        pto = midpoint(cb)
        markcs(roundpt(pto), labl = "pto", dir =:SE, color = "indigo", r = 60)
        # The current user origin in output coordinates
        pt = (O - pto) * outscale
        snapshot(;cb, scalefactor = outscale)  # No overlay, no file output
        snap(overlay, cb, outscale; pt)
    end
end
