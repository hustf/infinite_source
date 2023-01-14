# Part of the test is checking defaults.
# So this can't be run after other tests.
include("test_scale.jl")
inkextent_reset()
include("test_snap.jl")
inkextent_reset()
include("snowblind –  whirl.jl")
inkextent_reset()
include("test_long_svg_paths.jl")