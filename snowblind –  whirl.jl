# For text on Windows, we still need to pin
# a dependency of Cairo:
#import Pkg
#Pkg.pin(name = "Pango_jll", version = "v1.42.4")
# Some imports, some functions defined earlier
include("issue150_3.jl")
"A storage for some text since font scaling is hard"
const SKI_DECAL = Ref{Path}(Path([PathClose()]))

# For drawing multiple times
include("drawingfuncs.jl")


# A long time ago, a passing satelite took note of 
# a ski tourist at EU89, UTM 33, latitude 6862878.24 
# longitude 75574.22. It's an ice waste.
begin
 
#    snapshot(;cb)
   # snap() do
   #     ski_tourist(;scale = 1)
   # end
end
# Despite the sombrero, the tourist was fast becoming snow-blind.
# Luckily, our scientists have been studying veering for
# decades. Walking velocity is constant, angular acceleration is not!

Drawing(NaN, NaN, :rec)
background("snow1")
inkextent_reset()
begin
    # Draw trail, 1m = 100cm. This includes 100cm behind the start.
    p, θₑ = trail_next_length(100, 0, 0, 0)
    # Move origin to end of trail

    translate(p)
    snap() do
        scale = current_scalefactor()
        @show scale
        ski_tourist(;scale)
    end
end
p, θₑ = trail_next_length(1000, π / 10, 0, 0)
p |> encompass
translate(-p)
rotate(-θₑ)
snap() do
    ski_tourist(;scale = current_scalefactor())
end
p, θₑ = trail_next_length(1000, 0, (π / 10) / (10 * 100), 0)
@layer begin
    translate(p)
    rotate(-θₑ)
    snap(ski_tourist)
end
snap()
trail_next_length(1000, 0, -(π / 10) / (10 * 100), (π / 5) / (10 * 100)^2) |> encompass
snap()



# We shall need a way to add text, then revert. It is tempting to use the drawing stack for 
# storing a copy. However, I am not sure if the stack is intended for holding several drawings 
# per thread of execution. So we'll just use a new global container instead,
# and worry about using several threads later (if this works).




snap()
Drawing(NaN, NaN, :rec)
background("snow")
circle(O, 100, :fillstroke)
snap()



f = () -> begin
    setcolor("blue")
    settext("<big>Forward</big> ➡", O + (0, 0); markup=true)
end

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
