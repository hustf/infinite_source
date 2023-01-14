# Part of the test is checking defaults.
# So this can't be run after other tests.
include("test_scale.jl")
inkextent_reset()
@show LuxorLayout.margins_get()
include("test_snap.jl")
@show LuxorLayout.margins_get()
inkextent_reset()
inkextent_reset()
include("test_long_svg_paths.jl")
@show LuxorLayout.margins_get()


@info("""
 This next one, "snowblind –  whirl.jl" includes a lot of randomness
 in order to test the limits of Cairo. That's the purpose.
 We only speculate about the actual limits so far, and
 don't want to be too conservative - we warn instead of exiting
 when encountering intermediate images that are too large.
 
 A successful run takes < 25 seconds.  If it crashes instead, run it again!
 
 Here is an example of output from a crash - we pressed `Ctrl + c`.
 4 855 856 857 858 859 860 861 862 863 864 865 866 867 868 869 870 871 
 872 873 874 875 876  877 878 879 880 881 882 883 884 885 886 887 888 
 ┌ Warning: Size of svg  36778kB  > 13705kB
 └ @ Main.LuxorLayout C:/Users/.../.julia/environments/infinite_source/LuxorLayout.jl:315
 filesize(109.svg) = 6.833kB
 WARNING: Force throwing a SIGINT
""")
printstyled("Press 'Y + enter' to continue, any other key to skip 'snowblind-whirl.jl'!\n", color=:yellow)
keypress = read(stdin, Char)
if keypress == 'Y' 
    include("snowblind –  whirl.jl")
end
println()
