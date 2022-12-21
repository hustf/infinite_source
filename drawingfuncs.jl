# Our tourist had skis, 180cm long and 12cm wide, pointing right:
function one_ski()
    # Symmetric ski
    squircle(O, 180, 6; action =:fillstroke)
    # More square back
    squircle(O + (-90, 0), 90, 6; rt = 0.1, action =:fillstroke)
end
# The skis were 12cm apart
function skis()
    @layer begin
        setcolor("coral")
        translate(25, 12)
        one_ski()
        @layer begin
            setcolor("cornsilk")
            settext("<small>Forward</small> ➡", O + (70, 8); markup=true)
        end
        translate(0, -24)
        one_ski()
    end
end

# The ski tourist had a nice sombrero on (though no sunglasses):
function ski_tourist()
    @layer begin
        skis()
        setblend(blend(O, 0, O, 20, "cornsilk", "navajowhite3"))
        circle(O, 40, :fill)
    end
end

function trail_last_metre()
    @layer begin
        setcolor("snow4")
        setopacity(0.2)
        translate(25, 12)
        squircle(O + (-100, 0), 50, 6; rt = 0.1, action =:fillstroke)
        translate(0, -24)
        squircle(O + (-100, 0), 50, 6; rt = 0.1, action =:fillstroke)
    end
    BoundingBox(O + (-125, -17.5), O + (125, 17.5))
end

# Despite the sombrero, the tourist was fast becoming snow-blind.
# Luckily, our scientists have been studying veering for
# decades. Walking velocity is constant, angular acceleration is not!
θ´(s, θ´₀, θ´´₀) = θ´´₀ * s + θ´₀
θ(s, θ₀, θ´₀, θ´´₀) = 1/2 * θ´´₀ * s^2 + θ´₀ * s + θ₀
using QuadGK
func_pos(θ₀, θ´₀, θ´´₀) = begin
    # iszero(θ´´₀) && iszero(θ´₀) => straight line - easy 
    # iszero(θ´´₀)                => circle
    # Non-zero θ´´₀  requires Fresnel functions, which requires a beautiful mind.
    # Instead, we use numerical integration, which covers all these curves. 
    s-> begin
            fθ = s -> θ(s, θ₀, θ´₀, θ´´₀)
            x = quadgk(s ->  cos(fθ(s)), zero(s), s)[1]
            y = quadgk(s -> -sin(fθ(s)), zero(s), s)[1]
            Point(x,y)
        end
end
function trail_next_length(l, θ₀,  θ´₀, θ´´₀)
    f = func_pos(θ₀, θ´₀, θ´´₀)
    p = O
    θₑ = zero(θ₀)
    for s in range(zero(l), l; length = 1 + Int(ceil(l / 100)))
        @layer begin 
            p = f(s)
            θₑ = θ(s, θ₀, θ´₀, θ´´₀)
            translate(p)
            rotate(-θₑ)
            trail_last_metre() |> encompass
        end
    end
    p, θₑ
end
#=

trail_next_length(1000, 0, 0, 0)
snap()
trail_next_length(1000, π / 10, 0, 0)
snap()
p, θₑ = trail_next_length(1000, 0, (π / 10) / (10 * 100), 0)
@layer begin
    translate(p)
    rotate(-θₑ)
    ski_tourist()
end
snap()
trail_next_length(1000, 0, -(π / 10) / (10 * 100), (π / 5) / (10 * 100)^2)
snap()



"""
This function extracts the current recording as text for debugging purposes.
We have no way of changing the internal Cairo language and 'send it back'
to Cairo after manipulation. The text is perhaps more compact than svg text.
"""
function current_recording_binary(recsurf)
    @assert Luxor.current_surface_type() == :rec "$(Luxor.current_surface_type())"
    io = IOBuffer()
    script = Luxor.Cairo.CairoScript(io)
    Luxor.Cairo.script_from_recording_surface(script, recsurf)
    text_record = take!(script.stream)
    Luxor.Cairo.destroy(script)
    text_record
end
current_recording_binary() = current_recording_binary(currentdrawing().surface)

function snap_prepare_record(cb)
    rd = currentdrawing()
    isbits(rd) && return false  # currentdrawing provided 'info'
    rs = Luxor.current_surface()
    @assert rd isa Drawing
    @assert Luxor.current_surface_type() == :rec "$(Luxor.current_surface_type())"
    # The check for an 'alive' drawing should be performed by currentdrawing()
    # Working on a dead drawing causes ugly crashes.
    # Empty the working buffer to the recording surface:
    Luxor.Cairo.flush(rs)
    # Recording surface current transformation matrix (ctm)
    rma = getmatrix()
    # Recording surface inverse ctm - for device to user coordinates
    rmai = juliatocairomatrix(cairotojuliamatrix(rma)^-1)
    # Recording surface user coordinates of crop box top left
    rtlxu, rtlyu = boxtopleft(cb)

    # Recording surface device coordinates of crop box top left
    rtlxd, rtlyd, _ = cairotojuliamatrix(rma) * [rtlxu, rtlyu, 1]

    # Recording surface device origin is assumed to be the
    # upper left corner of extents (which is true given how Luxor currently makes these,
    # but Cairo now has more options)

    # Position of recording surface device origin, in new drawing user space.
    x, y = -rtlxd, -rtlyd

    # Return what's useful to what we do
    rd, rs, rmai, x, y
end
snap_prepare_record() = snap_prepare_record(inkextents[])

function inspect(c)
    @show c.width
    @show c.height
    @show c.filename
    @show c.surface
    @show c.cr
    @show c.surfacetype
    @show c.redvalue
    @show c.greenvalue
    @show c.bluevalue
    @show c.alpha
    @show c.buffer
    @show c.bufferdata
    @show c.strokescale
end

#=
function copy_surface(ctx::Luxor.CairoContext, s::T) where T<: Luxor.CairoRecordingSurface
   # ccall((:cairo_paint_with_alpha, Luxor.Cairo.libcairo),
   # Nothing, (Ptr{Nothing}, Float64), ctx.ptr, a)

   # Most surface types allow accessing the surface without using Cairo functions. If you do this, keep in mind that it is mandatory that you call cairo_surface_flush() before reading from or writing to the surface and that you must use cairo_surface_mark_dirty() after modifying it.

    cairo_surface_mark_dirty()
end
=#
# We shall need a way to add text, then revert. It is tempting to use the drawing stack for 
# storing a copy. However, I am not sure if the stack is intended for holding several drawings 
# per thread of execution. So we'll just use a new global container instead,
# and worry about using several threads later (if this works).

#const quicksaved = Ref{Drawing}(Luxor._current_drawing()[Luxor._current_drawing_index()])
#=function quicksave()
    c = Luxor._current_drawing()[Luxor._current_drawing_index()]
    @assert c isa Drawing
    @assert Luxor.current_surface_type() == :rec "$(Luxor.current_surface_type())"
    inspect(c)
    w = c.width
    h = c.height
    f = c.filename
    #s = c.surface
    cr = c.cr
    st = c.surfacetype
    r = c.redvalue
    g = c.greenvalue
    b = c.bluevalue
    a = c.alpha
    bu = c.buffer
    bd = c.bufferdata
    sc = c.strokescale
    nothing
end
=#
#quicksave()


function snapshot_testing(fname, cb, scalefactor)
    # Prefix r: recording
    # Prefix n: new snapshot
    # Device coordinates, device space: (x_d, y_d), origin at top left for Luxor implemented types
    # ctm: current transformation matrix - since it's symmetric, Cairo simplifies to a vector.
    # User coordinates, user space: (x_u,y_u ) = ctm⁻¹ * (x_d, y_d)


    rd, rs, rmai, x, y = snap_prepare_record(cb)

    # Make a quicksave copy of the :rec drawing.
#    quicksave()

    # New drawing dimensions
    nw = Float64(round(scalefactor * boxwidth(cb)))
    nh = Float64(round(scalefactor * boxheight(cb)))

    # New drawing ctm - user space origin and device space origin at top left
    nm = scalefactor.* [rmai[1], rmai[2], rmai[3], rmai[4], 0.0, 0.0]

    # Create new drawing, to which we'll project a snapshot
    nd = Drawing(round(nw), round(nh), fname)
    setmatrix(nm)

    # Define where to play the recording
    # The proper Cairo.jl name would be set_source_surface,
    # which is actually called by this Cairo.jl method.
    # Cairo docs phrases this as "Desination user space coordinates at which the
    # recording surface origin should appear". This seems to mean DEVICE origin.
    Luxor.Cairo.set_source(nd.cr, rs, x, y)

    # Draw the recording here
    paint()

    # Even in-memory drawings are finished, since such drawings are displayed.
    finish()

    # Switch back to continue recording
    Luxor._current_drawing()[Luxor._current_drawing_index()] = rd
    # Return the snapshot in case it should be displayed
    nd
end

function snap(cb::BoundingBox; scalefactor = 1.0)
    # Let's store the 
    COUNTIMAGE()
    snapshot_testing("$(COUNTIMAGE.value)_test.png", cb, scalefactor)
end

snap()
Drawing(NaN, NaN, :rec)
background("snow")
circle(O, 100, :fillstroke)
snap()

function snap_overlay(f)
    if Threads.nthreads() == 1 && Threads.threadid() == 1
        @info "Drawing in memory (if any) was overwritten. Run `julia -t auto`" 
    end
    snap()
    # Start with overlaying on the svg we just created
    file = "$(COUNTIMAGE.value  -1).svg"
    println("Overlaying function $f on $file")
    @assert isfile(file)
    rimg = readsvg(file)
    # Make a new drawing and place the one from the file there.
    width = Int(rimg.width)
    height = Int(rimg.height)
    Drawing(width, height, file)
    placeimage(rimg)
    origin()
    f()
    finish()
    # Now read the png we just created
    file = "$(COUNTIMAGE.value  -1).png"
    println("Overlaying function $f on $file")
    @assert isfile(file)
    rimg = readpng(file)
    # Make another new drawing and place the png from the file there.
    width = Int(rimg.width)
    height = Int(rimg.height)
    Drawing(width, height, file)
    placeimage(rimg)
    origin()
    f()
    finish()
end
snap_overlay() = snap_overlay(() -> begin
    setcolor("black")
    settext("<big>$(COUNTIMAGE.value)</big>", O; markup=true)
end)



f = () -> begin
    setcolor("blue")
    settext("<big>Forward</big> ➡", O + (0, 0); markup=true)
end

COUNTIMAGE.value = 9
snap_overlay(f)
# The satelite could see a long history of 'last-metre-trails', but 
# only one sombrero-wearing ski tourist. 
#
# How can we draw the tourist only once, while keeping the recorded history of 
# last-metre ski trails?
#
# Currently, each time we call `snap` -> `snapshot`, we
# internally 
#    1)  create a new internal drawing with a filename 
#    2)  play (paint actually) the previously existing record of commands on the new surface
#    3)  `finish` the internal drawing, which outputs a file.
#    4)  switch back to the previously existing recording
#    5) Return the finished internal drawing, which is displayed depending on the calling context.
#
# Is that not obvious? We would take a copy of the :rec, add the tourist, take a snapshot like above, 
# and retur-n to the old recording. 
# This solution is harder than it sounds, because Cairo sort of owns the internals of the recording.
# If we were able to do that, we could very easily add an 'undo' function too! 
# Another, way to do this is to have two :rec drawings, and paint them both onto the snapshot.
# Let's do that, although it's not quite as cool!













# A sombrero was a poor choice. 



#Blindfolded people show the same tendency; lacking external reference points, they curve around in loops as tight as 66 feet (20 meters) in diameter,

# Blindfolded people show the same tendency; lacking external reference points, they curve around in loops as tight as 66 feet (20 meters) in diameter,


=#