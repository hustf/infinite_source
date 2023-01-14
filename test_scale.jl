using Test
using Luxor
# Imports, snap etc.:
@isdefined(LuxorLayout) && throw("This test file relies on inital state at loading.")
include("LuxorLayout.jl")
using .LuxorLayout: margins_get, margins_set, Margins, scale_limiting_get, LIMITING_WIDTH, LIMITING_HEIGHT
using .LuxorLayout: inkextent_reset, inkextent_user_get, inkextent_device_get, encompass,
     point_device_get, point_user_get
using .LuxorLayout: snap, countimage_setvalue
using .LuxorLayout: mark_inkextent
# We have some old images we won't overwrite. Start after:
countimage_setvalue(49)
@testset "Viewport extension without work (user)-space scaling. Pic. 50-52" begin
    Drawing(NaN, NaN, :rec)
    # Margins are set in 'output' points.
    # They are scaled to user coordinates where needed.
    m = margins_set(Margins())
    t1, b1, l1, r1 = m.t, m.b, m.l, m.r
    inkextent_reset()
    s1 = scale_limiting_get()
    @test s1 == 1
    mark_inkextent()
    # Add a background with transparency - the old inkextent
    # will show.
    background(Luxor.RGBA(1.0,0.922,0.804, 0.5))
    # Expand inkextent by adding graphics and |> encompass
    setcolor("darkblue")
    for y in range(0, 1200, step = 300)
        text("y $y", Point(0, y)) |> encompass
    end
    mark_inkextent()
    snap("This is overlain")
    # Desired output with margins is either
    #   800 x   800 
    #   800 x <=800
    # <=800 x   800
    # scale_limiting_get() returns the scaling to fit within margins.
    bb2 = inkextent_user_get()
    s2 = scale_limiting_get() 
    # svg file + png file + png in memory.
    pic2 = snap() 
    @test pic2.width == 415
    @test pic2.height == 800
    # Increasing (the left) margin by 100 expands inwards
    # (possibly changing the scale to fit inkextent), not outwards
    # (the output image will not grow larger)
    margins_set(;l = 32 + 100)
    bb3 = inkextent_user_get()
    s3 = scale_limiting_get() 
    @test boxwidth(bb2) == boxwidth(bb3)
    # In this case, the necessary scaling was unchanged,
    # as the height of inkextent, top and bottom margin
    # determines the scaling. We had room to add a wider 
    # left margin and could still fit in the output image. 
    @test s2 == s3

    # We can add rectangles as normal - they are not taken to be background
    setcolor("burlywood")
    setopacity(0.65)
    rect(O + (-1000, 0), 1000, 1200, action = :fill) |> encompass
    setopacity(1.0)
    bb3 = inkextent_user_get()
    @test boxwidth(bb3) == 1368
    @test boxheight(bb3) == 1576
    setcolor("darkblue")
    mark_inkextent()
    s4 = scale_limiting_get()
    @test s4 < s3
    pic3 = snap() # svg file + png file + png in memory
    @test pic3.height < 800
    @test pic3.width == 800
end



@testset "User / work -space to device space: Zooming out. No pic." begin
    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    margins_set(Margins())
    bbo = inkextent_user_get()
    @test all(inkextent_device_get() .== bbo)
    #
    # Set scaling transformation from user to device space.
    sc = 0.5
    scale(sc)
    # i.e. (1,1) in user space now maps to (0.5, 0.5) in device space.
    # Inkextents are "really" set in device coordinates.
    # So the unchanged ink extents, when mapped to user coordinates,
    # just doubled in width and height.
    bbn = inkextent_user_get()
    @test boxwidth(bbn) / boxwidth(bbo) == 2
    @test boxheight(bbo) / boxheight(bbn) == sc
    @test round(scale_limiting_get(), digits = 5) == sc
end

@testset "User to device space: Zooming in. Pic. 53-54" begin
    Drawing(NaN, NaN, :rec)
    margins_set(Margins())
    inkextent_reset()
    background("chocolate")
    bbo = inkextent_user_get()
    #
    # Set scaling transformation from user to device space.
    sc = 4
    scale(sc)
    # i.e. (1,1) in user space now maps to (4, 4) in device space.
    w = boxwidth(inkextent_user_get())
    h = boxheight(inkextent_user_get())
    @test w / boxwidth(bbo) == 0.25
    @test boxheight(bbo) / h == sc
    @test w == 184
    setcolor("burlywood")
    format = (x) -> string(Int64(round(x)))
    dimension(O + (-w / 2, 50), O + (w / 2 , 50); format)
    dimension(O, O + (w / 2 , 0); format)
    dimension(O + (60, h / 2) , O + (60 , 0); format)
    dimension(O + (70, h / 2) , O + (70 , -h / 2); format)
    mark_inkextent()
    pic1 = snap("""
        User to device space: Zooming in
        by calling `scale($sc)`.""")
    # Drawing outside inkextents enlarges output too.
    pt = inkextent_user_get().corner2
    encompass(circle(pt, 50, :stroke))
    dbb = BoundingBox(inkextent_user_get().corner1, pt + (50, 50))
    @test all(inkextent_user_get() .== dbb)
    @test scale_limiting_get() < sc
    mark_inkextent()
    pic2 = snap("""
        We increased ink extents by (50,50 )
        without changing user space scaling ($sc).

        <small>snap()</small> will still output an image with
        the same outside dimensions.

        The scaling applied internally in 'snap' is:
            <small>scale_limiting_get()</small> = $(round(scale_limiting_get(), digits=4)).
        """)
    # There's a 0 / 1 thing going on with png output. 799 ≈ 800 anyway.
    @test abs(pic2.width - pic1.width) <= 1
end

@testset "Rotation. Pic. 56" begin
    Drawing(NaN, NaN, :rec)
    margins_set(Margins())
    inkextent_reset()
    background("blanchedalmond")
    ubb = inkextent_user_get()
    w1 = boxwidth(ubb)
    h1 = boxheight(ubb)
    ad = atan(h1 / w1)
    setopacity(0.5)
    rect(ubb.corner1, w1, h1, :fill)
    snap()
    a = 30 * π / 180
    # x is right, y is down, positive z is into the canvas.
    # Hence, positive rotation around z means the output / the device projection is 
    # rotated positive around z. That is, clockwise as seen from negative z.
    rotate(a)
    # This leads to scaling, which is complicated to foresee because
    # the margins in output are kept the same after scaling.
    @test round(scale_limiting_get(), digits = 4) == 0.7263
    setopacity(0.3)
    sethue("lightblue")
    # This demonstrates why we must keep track of
    # ink extents in device space rather than in 'user / work' space:
    # We're marking the inkextents in current user space,
    # but we do not encompass the user space.
    mark_inkextent()
    rect(ubb.corner1, w1, h1, :fill) |> encompass
    rotate(-a) # Back to normal. What we did last should be rotated clockwise
                # at output.
    setopacity(0.1)
    mark_inkextent()
    pic1 = snap("""
        This demonstrates why we keep track of
        ink extents in <i>device</i> space rather than in
        <i>user / work</i> space:
          1) Mark default <i>inkextent</i> - solid grey. It's slightly higher 
             than wide because side margins are larger.
          2) Set a clockwise rotation mapping from <i>user</i> to <i>device</i>.
          3) Draw a solid blue rectangle - same width and height.
          4) Encompass the blue rectangle, too, within <i>ink extent</i>.
          5) Mark <small>inkextent_user_get()</small> - dashed.
          6) Rotate back - <i>user</i> and <i>device</i> are aligned again
          7) Mark <small>inkextent_user_get()</small> - dashed and lighter. 
             This is larger than the solid grey one.

        A scale mapping is applied during output, to fit ink extents 
        as well as scaled margins within 800x800 points. 
            <small>scale_limiting_get()</small> = $(round(scale_limiting_get(), digits=3))

        In this case, width limits scaling. Output is 800 x 788.
    """)
    wr = boxwidth(inkextent_user_get()) / boxwidth(ubb)
    wre = cos(ad - a) / cos(ad)
    @test wr ≈ wre
    @test abs(pic1.width - 800) <= 1
    @test abs(pic1.height - 788) <= 1
end

@testset "Changing output size, blend background. Pic. 57" begin
    LIMITING_WIDTH[] = 400
    LIMITING_HEIGHT[] = 300
    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    margins_set(Margins())
    w = boxwidth(inkextent_user_get())
    h = boxheight(inkextent_user_get())
    @test w == 336
    @test h == 252
    @test w + margins_get().l + margins_get().r == 400  
    @test h + margins_get().t + margins_get().b == 300
    # We're making a special kind of background here...
    # .svg output is post-processed as normal.
    orangered = blend(Point(-150, 0), Point(150, 0), "orange", "darkred")
    rotate(π/3)
    setblend(orangered)
    paint()
    rotate(-π/3)
    setcolor("burlywood")
    format = (x) -> string(Int64(round(x)))
    dimension(O + (-w / 2, 50), O + (w / 2 , 50); format)
    dimension(O, O + (w / 2 , 0); format)
    dimension(O + (40, h / 2) , O + (40 , 0); format)
    dimension(O + (100, h / 2) , O + (100 , -h / 2); format)
    mark_inkextent()
    pic1 = snap("""\r
         <small>snap()</small> outputs 400 x 300. 
         <small>scale_limiting_get()</small> = $(round(scale_limiting_get(), digits=4)).
         svg colors ≠ png colors 
    """)
    @test abs(pic1.width - 400) <= 1
    @test abs(pic1.height - 300) <= 1
end
@testset "Transform both ways - translate" begin
    Drawing(NaN, NaN, :rec)
    background("orange")
    @test point_device_get(O) == O
    @test point_user_get(O) == O
    translate(O + (100, 0))
    @test point_device_get(O) == O + (100, 0)
    @test point_user_get( O + (100, 0)) == O 
end
@testset "Transform both ways - translate 2" begin
    Drawing(NaN, NaN, :rec)
    @test point_device_get(O) == O
    @test point_user_get(O) == O
    translate(O + (100, 100))
    @test point_device_get(O) == O + (100, 100)
    @test point_user_get( O + (100, 100)) == O 
end

@testset "Transform both ways - rotate " begin
    Drawing(NaN, NaN, :rec)
    @test point_device_get(O) == O
    @test point_user_get(O) == O
    rotate(atan(1))
    pu = O + (100, 0)
    pd =  O + cos(atan(1)) .* (100, 100)
    @test point_device_get(pu) == pd
    @test point_user_get(pd) == pu 
end
@testset "Transform both ways - transform " begin
    Drawing(NaN, NaN, :rec)
    @test point_device_get(O) == O
    @test point_user_get(O) == O
    rotate(atan(1))
    translate(O + (100, 0))
    pu = O
    pd =  O + cos(atan(1)) .* (100, 100)
    @test point_device_get(pu) == pd
    @test point_user_get(pd) == pu 
end
@testset "Transform both ways - opposite order transform " begin
    Drawing(NaN, NaN, :rec)
    @test point_device_get(O) == O
    @test point_user_get(O) == O
    translate(O + (100, 0))
    rotate(atan(1))
    pu = O
    pd =  O + (100, 0)
    @test point_device_get(pu) == pd
    @test point_user_get(pd) == pu
    pu1 = O + (100, 0)
    pd1 =  O + (100, 0) + cos(atan(1)) .* (100, 100)
    @test point_device_get(pu1) == pd1
    @test point_user_get(pd1) == pu1 
end
# Don't cause harm, reset
LIMITING_WIDTH[] = 800
LIMITING_HEIGHT[] = 800