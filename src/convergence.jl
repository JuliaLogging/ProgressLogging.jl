
export @logconvergence

@enum Direction::UInt8 Descending Ascending

const FN = Union{Float64,Nothing}
const DN = Union{Direction,Nothing}

struct Convergence
    id::UUID
    parentid::UUID
    names::Vector{String}
    values::Vector{FN}
    thresholds::Vector{FN}
    directions::Vector{DN}
    done::Bool
    step::Union{Int,Nothing}
    function Convergence(id, parentid, names, values, thresholds, directions, done, step)
        values = convert(Vector{FN}, values)
        thresholds = convert(Vector{FN}, thresholds)
        @. values[isnan_safe(values)] = nothing
        @. thresholds[isnan_safe(thresholds)] = nothing
        return new(id, parentid, names, values, thresholds, directions, done, step)
    end
end

isnan_safe(v::Real) = isnan(v)
isnan_safe(::Nothing) = false

Convergence(;
        id::UUID,
        parentid::UUID = ROOTID,  # not nested by default
        values=FN[nothing],
        names=fill("", length(values)),
        thresholds=Vector{FN}(nothing, length(values)),
        directions=Vector{DN}(nothing, length(values)),
        done::Bool = false,
        step::Union{Int,Nothing} = nothing
    ) = Convergence(id, parentid, names, values, thresholds, directions, done, step)

Convergence(id::UUID; kwargs...) = Convergence(; id = id, kwargs...)

# Define `string`/`print` so that progress log records are (somewhat)
# readable even without specific log monitors.
function Base.print(io::IO, c::Convergence)
    for args in zip(c.names, c.values, c.thresholds, c.directions)
        c.step !== nothing && print(io, "$(c.step) ")
        _print_convergence(io, c.parentid, args...)
        println(io)
    end
    return nothing
end

dir_char(d::Direction) = d === Descending ? '\u2193' : '\u2191' # ↓ : ↑
dir_char(::Nothing) = '|'

# print a single minutia of the convergence struct
function _print_convergence(io, parentid, name, value, threshold, direction)
    print(io, isempty(name) ? "Convergence" : name)
    if parentid !== ROOTID
        print(io, " (sub)")
    end
    print(io, ": ")
    value === nothing ? print(io, "??") : print(io, value)
    print(io, dir_char(direction))
    threshold === nothing ? print(io, "??") : print(io, threshold)

    return nothing
end

macro logconvergence()
    :(nothing)
end