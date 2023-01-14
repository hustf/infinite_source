using Test
using Luxor
# We can play more with this later if we implment
# cairo_get_inkextent().
# Currently, we can read svgs, but we can't get
# their actual extents on screen (which is larger than
# the area that actually has content).
if ! @isdefined LuxorLayout
    include("LuxorLayout.jl")
end
using .LuxorLayout: byte_description, LIMIT_fsize_read_svg

# I made these from a bitmap, a fair use of the LP cover.
svgfiles = [nam for nam in readdir("Santana", join=true) if endswith(nam, ".svg")]
ordered_files = filter(svgfiles) do nam
    f = splitpath(nam)[2]
    tryparse(Int64, f[2:3]) isa Int64
end
# Reordering for display sequence: 
#           Display order -    File order  Emphasis
reorder = [125                 1           0             # 04 Alien.svg
           126                 2           2             # 06 Woman.svg
            01                 3           0             # 07 Scared man.svg
            08                 4           0             # 08 Deep eyes.svg
            09                 5           0             # 09 Large ear.svg
           110                 6           0             # 10 Left singer.svg
           111                 7           0             # 11 Right singer.svg
            12                 8           0             # 12 Small ear.svg
            13                 9           0             # 13 Left whiskerman.svg
            14                 10          1             # 14 Right whiskerman.svg
           115                 11          0             # 16 Lion.svg
           121                 12          1             # 21 Tl.svg
           122                 13          1             # 22 Tr.svg
           123                 14          1             # 23 Bl.svg
           124                 15          1             # 24 Br.svg
            -1                 16          0]            # 30 Background.svg

for (dno, fno, emphasis) in eachrow(sortslices(reorder,dims=1,by=x->x[1]))
    # Set display order negative to neglect.
    # Display order == 1 starts a drawing.
    dno < 0 && continue
    fnam = ordered_files[fno]
    s = read(fnam, String);
    println(lpad(fnam, 40), " ", length(s) / 1000, "kB")
    if length(s) > LIMIT_fsize_read_svg
        @warn "Size of svg  $(byte_description(length(s))) > $(byte_description(LIMIT_fsize_read_svg))"
        println()
        continue
    end
    rimg = try
        readsvg(s)
    catch e
        println(e)
        println()
        continue # jump to next iteration
    end
    if dno == 1
        Drawing(rimg.width, rimg.height, :rec)
        global bl = blend(O, O + (0.2 * rimg.width, rimg.height))
        # Mutate bl
        addstop(bl, 0.0, "darkblue")
        addstop(bl, 0.33, "darkred")
        addstop(bl, 0.375, "gold4")
        addstop(bl, 0.4, "blue")
        addstop(bl, 0.5, "darkblue")
        addstop(bl, 1.0, Luxor.RGB(0.7294117647058823, 0.7333333333333333, 0.5882352941176471))
        setblend(bl)
        paint()
    end
    if emphasis == 0
        setmode("atop")
        placeimage(rimg)
    elseif emphasis == 1
        setmode("darken")
        placeimage(rimg)
    else
        setmode("atop")
        #addstop(bl, 0.85, "red")
        #addstop(bl, 1.0, "green")
        setblend(bl)
        paint_with_alpha(currentdrawing().cr, 0.6)
        setmode("darken")
        placeimage(rimg)
    end

    println()
end

################
# 75.png, 75.svg
################
snapshot(fname = "75.png")
snapshot(fname = "75.svg")
#snapshot()
#setmode("clear")
#placeimage(rimg)
