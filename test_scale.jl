# Some imports, some functions defined earlier
include("issue150_3.jl")
using Test
#@testset "No viewport transformation" begin
    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    background("blanchedalmond")
    # Before any operations, we assume that the desired output 
    # is 800x800, and that that includes default 'margins()'
    bbo = inkextent_user()
    @test boxwidth(bbo) + margins().l + margins().r == 800
    @test boxheight(bbo) + margins().t + margins().b == 800
    pic1 = snap() # svg file + png file + png in memory
    @test pic1.width == 800
    @test pic1.height == 800
    # Increasing margins expands outwards, not inwards
    set_margins(Margins(;l = 32 + 100))
    bbn = inkextent_user()
    @test all(bbo .== bbn)
    pic2 = snap() # svg file + png file + png in memory
    @test pic2.height == 800
    @test pic2.width == 900
    #
    # TODO


    dbb = BoundingBox(Point(-368, -376), Point(368, 376))
    @test all(inkextent_user() .== dbb)
    inkextent_reset()
    @test all(inkextent_user() .== dbb)
    #
    @test get_scale_inkextents_margins() == 1
    rect(dbb.corner1, boxwidth(dbb), boxheight(dbb), :fill)
    setcolor("burlywood")
    circle(O, boxwidth(dbb) / 2, :fill)
    pic1 = snap()
    # Draw outside inkextents, enlarge output too.
    pt = inkextent_user().corner2
    encompass(circle(pt, 50, :fill))
    dbb = BoundingBox(dbb.corner1, pt + (50, 50))
    @test all(inkextent_user() .== dbb)
    @test get_scale_inkextents_margins() == 1
    pic2 = snap()
    @test pic2.width - pic1.width == 50
#end

#@testset "Scaling" begin
    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    background("blanchedalmond")
    # Before any operations, we assume that the desired output 
    # is 800x800, and that that includes default 'margins()'
    bbo = inkextent_user()
    #
    sc = 0.5
    scale(sc)
    bbn = inkextent_user()
    @test all(bbn .== bbo * 1/sc)
    #
    @test get_scale_inkextents_margins() == sc
    rect(dbb.corner1, boxwidth(dbb), boxheight(dbb), :fill)
    setcolor("burlywood")
    circle(O, boxwidth(dbb) / 2, :fill)
    pic1 = snap()
    # Draw outside inkextents, enlarge output too.
    pt = inkextent_user().corner2
    encompass(circle(pt, 50, :fill))
    dbb = BoundingBox(dbb.corner1, pt + (50, 50))
    @test all(inkextent_user() .== dbb)
    @test get_scale_inkextents_margins() == sc
    pic2 = snap()
    @test pic2.width - pic1.width == sc * 50
#end

#@testset "Rotation" begin
    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    background("blanchedalmond")
    ubb = inkextent_user()
    rect(ubb.corner1, boxwidth(ubb), boxheight(ubb), :fill)
    snap()
    a = 30 * π / 180
    # x is right, y is down, positive z is into the canvas.
    # Scaling to 0.5 means the output (user, canvas) is smaller than world drawing.
    # Hence, positive rotation around z means the output / the device projection is 
    # rotated positive around z. That is, clockwise as seen from negative z.
    rotate(a)
    @test get_scale_inkextents_margins() == 1.0
    setcolor("indigo")
    rect(ubb.corner1, boxwidth(ubb), boxheight(ubb), :fill) |> encompass
    rotate(-a) # Back to normal. What we did last should be rotated clockwise on the device output.
    snap()
    cb = BoundingBox(Point(-500, -500), Point(500, 500))
    snapshot(;cb)
    # I don't understand the above. I expected the previous to remain horizontal/ vertical,
    # and the new output to be slanted.
    #
    # Try again by directly manipulating ctm

    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    background("blanchedalmond")
    ubb = inkextent_user()
    rect(ubb.corner1, boxwidth(ubb), boxheight(ubb), :fill)
    tm = [cos(a) -sin(a) 0.0; sin(a) cos(a) 0.0; 0.0 0.0 1.0]
    setmatrix(juliatocairomatrix(tm))
    setcolor("indigo")
    rect(ubb.corner1, boxwidth(ubb), boxheight(ubb), :fill) |> encompass
    snapshot(;cb)
    # This is the exact same result as above. We continue to work in 'user space'...
    snap()
    # 


    Drawing(NaN, NaN, :rec)
    inkextent_reset()
    background("blanchedalmond")
    ubb = inkextent_user()
    rect(ubb.corner1, boxwidth(ubb), boxheight(ubb), :fill)
    pic1 = snap()
    a = 10 * π / 180
    # x is right, y is down, positive z is into the canvas.
    # Scaling to 0.5 means the output (user, canvas) is smaller than world drawing.
    # Hence, positive rotation around z means the output is rotated positive compared to world. 
    rotate(a)
    @test get_scale_inkextents_margins() == 1.0
    setcolor("indigo")
    rect(ubb.corner1, boxwidth(ubb), boxheight(ubb), :fill) |> encompass
    pic2 = snap()
    @test pic1.width == 800
#    @test pic2.width == 800 * ---

# TODO check this strange hypothesis: ctm is applied to drawing commands before they are stored.
# Alternatively, rotate, draw, rotate back, output.
# Other formulation: commands are applied to user space, its effect is stored in world coordinates.