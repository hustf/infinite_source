# Some imports, some functions defined earlier
include("issue150_3.jl")
using Test
@testset "No viewport transformation" begin
    Drawing(NaN, NaN, :rec)
    background("coral")
    reset_INK_EXTENT()
    @test all(inkextent_user() .== BoundingBox(Point(-240.0, -180.0), Point(240.0, 180.0)))
    pt = O
    encompass(pt)
    @test all(inkextent_user() .== BoundingBox(Point(-240.0, -180.0), Point(240.0, 180.0)))
    pt = O + (300, 200)
    encompass(pt)
    @test all(inkextent_user() .== BoundingBox(Point(-240.0, -180.0), Point(300, 200)))
    pt = O + (-500, -400)
    encompass(pt)
    @test all(inkextent_user() .== BoundingBox(Point(-500, -400), Point(300, 200)))
end

@testset "Viewport looks at more of the world than viewport size" begin
    Drawing(NaN, NaN, :rec)
    background("gold4")
    reset_INK_EXTENT()
    # The projection is half the size of the object. The object resides in 'world', the projection in 'canvas'.
    scale(0.5)
    @test all(inkextent_user() .== BoundingBox(2 * Point(-240.0, -180.0), 2 * Point(240.0, 180.0)))
    pt = O + (700, 600)
    encompass(pt)
    inkextent_user()
    @test all(inkextent_user() .== BoundingBox(2 * Point(-240.0, -180.0), pt))
    pt1 = O + (-800, -700)
    encompass(pt1)
    @test all(inkextent_user() .== BoundingBox(pt1, pt))
end
@testset "Viewport looks at less of the world than viewport size" begin
    Drawing(NaN, NaN, :rec)
    background("gold2")
    reset_INK_EXTENT()
    # The projection is half the size of the object. The object resides in 'world', the projection in 'canvas'.
    scale(1.5)
    @test all(inkextent_user() .== BoundingBox((1/1.5) * Point(-240.0, -180.0), (1/1.5) * Point(240.0, 180.0)))
    pt = O + (700, 600)
    encompass(pt)
    inkextent_user()
    @test all(inkextent_user() .== BoundingBox((1/1.5) * Point(-240.0, -180.0), pt))
    pt1 = O + (-800, -700)
    encompass(pt1)
    @test all(inkextent_user() .== BoundingBox(pt1, pt))
end
