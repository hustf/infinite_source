using Test
using Luxor
# Imports, snap etc.:
include("LuxorLayout.jl")
using .LuxorLayout: margins_get, scale_limiting_get
using .LuxorLayout: inkextent_reset, inkextent_user_get, encompass,
     point_device_get, inkextent_user_with_margin
using .LuxorLayout: snap, countimage_setvalue
using .LuxorLayout: mark_cs, rotation_device_get

# We have some old images we won't overwrite. Start after:
countimage_setvalue(19)


"Noone likes decimal points"
roundpt(pt) = Point(round(pt.x), round(pt.y))

"An overlay showing coordinate systems: user, device, output"
function t_overlay(; pt)
    # The origin here, o4, overlaps o1.
    mark_cs(O; labl = "o4", color = "black", r = 70, dir=:SW)
    mark_cs(roundpt(pt); labl = "pt4", color = "white", r = 80, dir=:SE)
    translate(pt)
    mark_cs(O; labl = "o5", color = "navy", r = 90, dir=:E)
end 

@testset "Target a user space point in an overlay." begin
    @testset "Rotation, but no ink extension past default. Pic. 20 -21" begin
        Drawing(NaN, NaN, :rec)
        background("coral")
        inkextent_reset()
        sethue("grey")
        mark_cs(O, labl = "o1", color = "red", r = 20)
        p = O + (200, -50)
        p |> encompass
        θ = π / 6
        mark_cs(p, labl = "p1", dir =:S, color = "green", r = 30)
        brush(O, p, 2)
        translate(p)
        mark_cs(O, labl = "o2", dir =:E, color = "blue", r = 40)
        rotate(-θ)
        mark_cs(O, labl = "o3", dir =:NW, color = "yellow", r = 50)
        @test point_device_get(O) == p 
        outscale = scale_limiting_get()
        cb = inkextent_user_with_margin()
        # The origin of output in user coordinates:
        pto = midpoint(cb)
        mark_cs(roundpt(pto), labl = "pto", dir =:SE, color = "indigo", r = 60)
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
        snap(t_overlay, cb, outscale; pt)
    end
    @testset "Rotation and also ink extension. Pic. 22" begin
        Drawing(NaN, NaN, :rec)
        background("darksalmon")
        inkextent_reset()
        sethue("grey")
        mark_cs(O, labl = "o1", color = "red", r = 20)
        p = O + 3 .* (200, -50)
        p |> encompass
        θ = π / 6
        mark_cs(p, labl = "p1", dir =:S, color = "green", r = 30)
        brush(O, p, 2)
        translate(p)
        mark_cs(O, labl = "o2", dir =:E, color = "blue", r = 40)
        rotate(-θ)
        @test rotation_device_get() ≈ -θ
        mark_cs(O, labl = "o3", dir =:NW, color = "yellow", r = 50)
        @test point_device_get(O) == p 
        outscale = scale_limiting_get()
        cb = inkextent_user_with_margin()
        # The origin of output in user coordinates:
        pto = midpoint(cb)
        mark_cs(roundpt(pto), labl = "pto", dir =:SE, color = "indigo", r = 60)
        # The current user origin in output coordinates
        pt = (O - pto) * outscale
        snapshot(;cb, scalefactor = outscale)  # No overlay, no file output
        snap(t_overlay, cb, outscale; pt)
    end
end
