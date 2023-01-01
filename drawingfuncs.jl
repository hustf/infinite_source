## These functions are used for the 'skier' example.
using QuadGK

"""
    ski_decal()

To use: drawpath(ski_decal(), :fill)
Refers mutable const SKI_DECAL = Ref{Path}(Path([PathClose()]))
"""
function ski_decal()
    # Reuse if possible, given that text scaling is problematic
    length(SKI_DECAL[]) > 1 && return SKI_DECAL[]
    # forget any current path, start a new one
    newpath() 
    fontsize(12)
    str = "Forward >"
    # Make text the current path
    textoutlines(str, O + (70, 5))
    SKI_DECAL[] = storepath()
end

# Our tourist had skis, 180cm long and 12cm wide, pointing right:
function one_ski(;scale = 1.0)
    # Symmetric ski
    squircle(O, 180 * scale, 6 * scale; action =:fillstroke)
    # More squared ski at the back
    squircle(O + (-90, 0) .* scale, 90 * scale, 6* scale; rt = 0.1, action =:fillstroke)
    # decal
    @layer begin
        setcolor("yellow")
        Luxor.scale(scale)
        drawpath(ski_decal(), :fill)
    end
end

# The skis were 12cm apart
function skis(; scale = 1.0)
    @layer begin
        setcolor("coral")
        translate(25 * scale, 12 * scale)
        one_ski(;scale)
        translate(0, -24 * scale)
        one_ski(;scale)
    end
end

# The ski tourist had a nice sombrero on (though no sunglasses):
function ski_tourist(;scale = 1.0)
    setline(scale)
    skis(;scale)
    # Sombrero
    setblend(blend(O, 0, O, 20 * scale, "cornsilk", "navajowhite3"))
    circle(O, 40 * scale, :fill)
end

# There is some overlapping, adding darker patches
function trail_last_metre()
    @layer begin
        setcolor("snow4")
        setopacity(0.3)
        translate(0, 12)
        box(O + (-50, 0), 100, 12, action =:fillstroke)
        translate(0, -24)
        box(O + (-50, 0), 100, 12, action =:fillstroke)
    end
    BoundingBox(O + (-125, -17.5), O + (125, 17.5))
end

"""
    trail_next_length(l, θ₀,  θ´₀, θ´´₀)
    -> (p::Point,  θ::Float64)

# Effects

- Walk and draw distance 'l' from origin along a constant velocity path defined by arguments
-- θ₀,  θ´₀, θ´´₀.
  This is done in segments of length 100 (plus one from s=-100 to s=0). If l = 300, there will be four segments.
- Update global INK_EXTENT through
- Return position and direction at end of this trail.
"""
function trail_next_length(l, θ₀,  θ´₀, θ´´₀)
    f = func_pos(θ₀, θ´₀, θ´´₀)
    p = O
    θₑ = zero(θ₀)
    for s in range(zero(l), l; length = 1 + Int(ceil(l / 100)))
        @layer begin
            p = f(s)
            encompass(p)
            θₑ = θ(s, θ₀, θ´₀, θ´´₀)
            translate(p)
            rotate(-θₑ)
            trail_last_metre()
        end
    end
    p, θₑ
end

# Luckily, our scientists have been studying veering for
# decades. Walking velocity is constant, angular acceleration too!
# Until you stop for academic contemplation.
"""
    θ´(s, θ´₀, θ´´₀)
dθ/ds @ s

limited to absolute value 0.00095
    given

- ds/ds = 1
- dθ´´/ds = 0
"""
function θ´(s, θ´₀, θ´´₀)
    x = θ´´₀ * s + θ´₀
    sign(x) * min(abs(x), 0.00095)
end
θ(s, θ₀, θ´₀, θ´´₀) = 1/2 * θ´´₀ * s^2 + θ´₀ * s + θ₀

function func_pos(θ₀, θ´₀, θ´´₀)
    # iszero(θ´´₀) && iszero(θ´₀) => straight line - easy 
    # iszero(θ´´₀)                => circle
    # Non-zero θ´´₀  requires Fresnel functions, which requires a beautiful mind.
    # Instead, we use numerical integration for dirty minds. 
    s-> begin
            fθ = s -> θ(s, θ₀, θ´₀, θ´´₀)
            x = quadgk(s ->  cos(fθ(s)), zero(s), s)[1]
            y = quadgk(s -> -sin(fθ(s)), zero(s), s)[1]
            Point(x,y)
        end
end

