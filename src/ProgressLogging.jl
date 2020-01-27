module ProgressLogging

# Use README as the docstring of the module:
@doc read(joinpath(dirname(@__DIR__), "README.md"), String) ProgressLogging

export @progress, @progressid, @withprogress, @logprogress

using Base.Meta: isexpr
using UUIDs: UUID, uuid4, uuid5
using Logging: Logging, @logmsg, LogLevel

const ProgressLevel = LogLevel(-1)

"""
    ProgressLogging.ROOTID

This is used as `parentid` of root [`Progress`](@ref)es.
"""
const ROOTID = UUID(0)

"""
    ProgressLogging.Progress(id, [fraction]; [parentid, name, done])

# Usage: Progress log record provider

Progress log record can be created by using the following pattern

```julia
id = uuid4()
try
    @info Progress(id)  # create a progress bar
    # some time consuming task
    # ...
    @info Progress(id, 0.1)  # update progress to 10%
    # ...
finally
    @info Progress(id, done = true)  # close the progress bar
end
```

It is recommended to use [`@withprogress`](@ref),
[`@logprogress`](@ref), and optionally [`@progressid`](@ref) to create
log records.

# Usage: Progress log record consumer (aka progress monitor)

It is recommended to use [`ProgressLogging.asprogress`](@ref) instead
of checking `message isa Progress`.  Progress monitors can retrieve
progress-related information from the following properties.

# Properties
- `fraction::Float64`: it can take following values:
  - `0 <= fraction < 1`
  - `fraction = NaN`: indeterminate progress
  - `fraction >= 1`: completed
- `id::UUID`: Identifier of the task whose progress is at `fraction`.
- `parentid::UUID`: The ID of the parent progress.  It is set to
  [`ProgressLogging.ROOTID`](@ref) when there is no parent progress.
  This is used for representing progresses of nested tasks.  Note that
  sub-tasks may be executed concurrently; i.e., there can be multiple
  child tasks for one parent task.
- `name::String`: Name of the progress bar.
- `done::Bool`: `true` if the task is done.
"""
Base.@kwdef struct Progress
    id::UUID
    parentid::UUID = ROOTID  # not nested by default
    fraction::Float64 = NaN
    name::String = ""
    done::Bool = false
end

Progress(id::UUID, fraction::Real = NaN; kwargs...) =
    Progress(; kwargs..., fraction = fraction, id = id)

# Define `string`/`print` so that progress log records are (somewhat)
# readable even without specific log monitors.
function Base.print(io::IO, progress::Progress)
    print(io, isempty(progress.name) ? "Progress" : progress.name)
    if progress.parentid !== ROOTID
        print(io, " (sub)")
    end
    print(io, ": ")
    if isnan(progress.fraction)
        print(io, "??%")
    else
        print(io, floor(Int, progress.fraction * 100), '%')
    end
    return
end

const PROGRESS_LOGGING_UUID_NS = UUID("1e962757-ea70-431a-b9f6-aadf988dcb7f")

asuuid(id::UUID) = id
asuuid(id) = uuid5(PROGRESS_LOGGING_UUID_NS, string(id))

asfraction(progress::Nothing) = NaN
asfraction(progress::AbstractString) = progress == "done" ? NaN : nothing
asfraction(progress::Real) = convert(Float64, progress)


"""
    ProgressLogging.asprogress(_, name, _, _, id, _, _; progress, ...) :: Union{Progress, Nothing}

Pre-process log record to obtain a [`Progress`](@ref) object if it is
one of the supported format.  This is mean to be used with the
`message` positional argument and _all_ keyword arguments passed to
`Logging.handle_message`.  Example:

```julia
function Logging.handle_message(logger::MyLogger, args...; kwargs...)
    progress = ProgressLogging.asprogress(args...; kwargs...)
    if progress !== nothing
        return # handle progress log record
    end
    # handle normal log record
end
```
"""
asprogress(_level, progress::Progress, _args...; _...) = progress
asprogress(_level, name, _module, _group, id, _file, _line; progress = undef, kwargs...) =
    if progress isa Union{Nothing,Real,AbstractString}
        _asprogress(name, id; progress = progress, kwargs...)
    else
        nothing
    end

# `parentid` is used from `@logprogress`.
function _asprogress(name, id, parentid = ROOTID; progress, _...)
    fraction = asfraction(progress)
    fraction === nothing && return nothing
    return Progress(
        fraction = fraction,
        name = name,
        id = asuuid(id),
        parentid = parentid,
        done = progress == "done"
    )
end

# To pass `Progress` value without breaking progress monitors with the
# previous `progress` key based specification, we create an abstract
# string type that has `Progress` attached to it.  This is used as the
# third argument `message` of `Logging.handle_message`.
struct ProgressString <: AbstractString
    progress::Progress
end

asprogress(_level, str::ProgressString, _args...; _...) = str.progress

Base.string(str::ProgressString) = str.progress.name
Base.print(io::IO, str::ProgressString) = print(io, string(str))
Base.convert(::Type{ProgressString}, str::ProgressString) = str
Base.convert(::Type{T}, str::ProgressString) where {T<:AbstractString} =
    convert(T, str.progress.name)

function Base.show(io::IO, str::ProgressString)
    if get(io, :typeinfo, Any) === ProgressString
        show(io, string(str.progress))
        return
    end
    print(io, @__MODULE__, ".")
    print(io, "ProgressString(")
    show(io, str.progress)
    print(io, ")")
end

"""
    progress(f::Function; name = "")

Evaluates `f` with `id` as its argument and makes sure to destroy the progress
bar afterwards. To update the progress bar in `f` you can call a logging statement
like `@info` or even just `@logmsg` with `_id=id` and `progress` as arguments.

`progress` can take either of the following values:
  - `0 <= progress < 1`: create or update progress bar
  - `progress == nothing || progress = NaN`: set progress bar to indeterminate progress
  - `progress >= 1 || progress == "done"`: destroy progress bar

The logging message (e.g. `"foo"` in `@info "foo"`) will be used as the progress
bar's name.

Log level must be higher or equal to `$ProgressLevel`.

```julia
ProgressLogging.progress() do id
    for i = 1:10
        sleep(0.5)
        @info "iterating" progress=i/10 _id=id
    end
end
```
"""
function progress(f; name = "")
    _id = uuid4()
    @logmsg ProgressLevel name progress = NaN _id = _id
    try
        f(_id)
    finally
        @logmsg ProgressLevel name progress = "done" _id = _id
    end
end

const _id_var = gensym(:progress_id)
const _parentid_var = gensym(:progress_parentid)
const _name_var = gensym(:progress_name)

"""
    @withprogress [name=""] [parentid=uuid4()] ex

Create a lexical environment in which [`@logprogress`](@ref) can be used to
emit progress log events without manually specifying the log level, `_id`,
and name (log message).

```julia
@withprogress name="iterating" begin
    for i = 1:10
        sleep(0.5)
        @logprogress i/10
    end
end
```
"""
macro withprogress(exprs...)
    _withprogress(exprs...)
end

function _withprogress(exprs...)
    length(exprs) == 0 &&
        throw(ArgumentError("`@withprogress` requires at least one expression."))

    m = @__MODULE__

    kwargs = Dict(:name => "", :parentid => :($m.@progressid()))
    unsupported = []
    for kw in exprs[1:end-1]
        if isexpr(kw, :(=)) && length(kw.args) == 2 && haskey(kwargs, kw.args[1])
            kwargs[kw.args[1]] = kw.args[2]
        else
            push!(unsupported, kw)
        end
    end

    # Error on invalid input expressions:
    if !isempty(unsupported)
        msg = sprint() do io
            println(io, "Unsupported optional arguments:")
            for kw in unsupported
                println(io, kw)
            end
            print(io, "`@withprogress` supports only following keyword arguments: ")
            join(io, keys(kwargs), ", ")
        end
        throw(ArgumentError(msg))
    end

    ex = exprs[end]
    quote
        let $_parentid_var = $(kwargs[:parentid]),
            $_id_var = $uuid4(),
            $_name_var = $(kwargs[:name])
            $m.@logprogress NaN
            try
                $ex
            finally
                $m.@logprogress "done"
            end
        end
    end |> esc
end

"""
    @logprogress [name] progress [key1=val1 [key2=val2 ...]]

This macro must be used inside [`@withprogress`](@ref) macro.

Log a progress event with a value `progress`.  The expression
`progress` must be evaluated to be a real number between `0` and `1`
(inclusive), a `NaN`, or a string `"done"`.

Optional first argument `name` can be used to change the name of the
progress bar.  Additional keyword arguments are passed to `@logmsg`.
"""
macro logprogress(name, progress = nothing, args...)
    name_expr = :($Base.@isdefined($_name_var) ? $_name_var : "")
    if progress == nothing
        # Handle: @logprogress progress
        kwargs = (:(progress = $name), args...)
        progress = name
        name = name_expr
    elseif isexpr(progress, :(=)) && progress.args[1] isa Symbol
        # Handle: @logprogress progress key1=val1 ...
        kwargs = (:(progress = $name), progress, args...)
        progress = name
        name = name_expr
    else
        # Otherwise, it's: @logprogress name progress key1=val1 ...
        kwargs = (:(progress = $progress), args...)
    end

    id_err = "`@logprogress` must be used inside @withprogress or `_id` keyword argument"
    id_expr = :($Base.@isdefined($_id_var) ? $_id_var : $error($id_err))
    for x in kwargs
        if isexpr(x, :(=)) && x.args[1] === :_id
            id_expr = :($asuuid($(x.args[2])))
            # last set wins; so not `break`ing
        end
    end

    @gensym id_tmp
    # Emitting progress log record as old/open API (i.e., using
    # `progress` key) and also new API based on `Progress` type.
    msgexpr = :($ProgressString($_asprogress(
        $name,
        $id_tmp,
        $_parentid_var;
        progress = $progress,
    )))
    quote
        $id_tmp = $id_expr
        $Logging.@logmsg($ProgressLevel, $msgexpr, $(kwargs...), _id = $id_tmp)
    end |> esc
end

"""
    @progressid

Get the progress ID of current lexical scope.
"""
macro progressid()
    quote
        $Base.@isdefined($_id_var) ? $_id_var : $ROOTID
    end |> esc
end

"""
    @progress [name="", threshold=0.005] for i = ..., j = ..., ...
    @progress [name="", threshold=0.005] x = [... for i = ..., j = ..., ...]

Show a progress meter named `name` for the given loop or array comprehension
if possible. Update frequency is limited by `threshold` (one update per 0.5% of
progress by default).
"""
macro progress(args...)
    _progress(args...)
end

_progress(ex) = _progress("", 0.005, ex)
_progress(name::Union{AbstractString,Expr}, ex) = _progress(name, 0.005, ex)
_progress(thresh::Real, ex) = _progress("", thresh, ex)

function _progress(name, thresh, ex)
    if ex.head == Symbol("=") &&
       ex.args[2].head == :comprehension && ex.args[2].args[1].head == :generator
        # comprehension: <target> = [<body> for <iter_var> in <range>,...]
        loop = _comprehension
        target = esc(ex.args[1])
        result = target
        gen_ex = ex.args[2].args[1]
        body = esc(gen_ex.args[1])
        iter_exprs = gen_ex.args[2:end]
        iter_vars = [e.args[1] for e in iter_exprs]
        ranges = [e.args[2] for e in iter_exprs]
    elseif ex.head == :for && ex.args[1].head == Symbol("=") && ex.args[2].head == :block
        # single-variable for: for <iter_var> = <range>; <body> end
        loop = _for
        target = :_
        result = :nothing
        iter_vars = [ex.args[1].args[1]]
        ranges = [ex.args[1].args[2]]
        body = esc(ex.args[2])
    elseif ex.head == :for && ex.args[1].head == :block && ex.args[2].head == :block
        # multi-variable for: for <iter_var> = <range>,...; <body> end
        loop = _for
        target = :_
        result = :nothing
        # iter_vars and ranges are ordered from inner loop to outer loop, for
        # consistent computation of progress between for loops and comprehensions
        iter_vars = reverse([e.args[1] for e in ex.args[1].args])
        ranges = reverse([e.args[2] for e in ex.args[1].args])
        body = esc(ex.args[2])
    else
        error("@progress requires a for loop (for i in irange, j in jrange, ...; <body> end) " *
              "or array comprehension with assignment (x = [<body> for i in irange, j in jrange, ...])")
    end
    _progress(name, thresh, ex, target, result, loop, iter_vars, ranges, body)
end

function _progress(name, thresh, ex, target, result, loop, iter_vars, ranges, body)
    count_vars = [Symbol("i$k") for k = 1:length(iter_vars)]
    iter_exprs = [:(($i, $(esc(v))) = enumerate($(esc(r)))) for (i, v, r) in zip(
        count_vars,
        iter_vars,
        ranges,
    )]
    _id = "progress_$(gensym())"
    quote
        @logmsg($ProgressLevel, $(esc(name)), progress = 0.0, _id = Symbol($_id))
        $target =
            try
                ranges = $(Expr(:vect, esc.(ranges)...))
                nranges = length(ranges)
                lens = length.(ranges)
                n = prod(lens)
                strides = cumprod([1; lens[1:end-1]])
                _frac(i) = (sum((i - 1) * s for (i, s) in zip(i, strides)) + 1) / n
                lastfrac = 0.0

                $(loop(
                    iter_exprs,
                    quote
                        val = $body
                        frac = _frac($(Expr(:vect, count_vars...)))
                        if frac - lastfrac > $thresh
                            @logmsg(
                                $ProgressLevel,
                                $(esc(name)),
                                progress = frac,
                                _id = Symbol($_id),
                            )
                            lastfrac = frac
                        end
                        val
                    end,
                ))

            finally
                @logmsg($ProgressLevel, $(esc(name)), progress = "done", _id = Symbol($_id))
            end
        $result
    end
end

_comprehension(iter_exprs, body) =
    Expr(:comprehension, Expr(:generator, body, iter_exprs...))
_for(iter_exprs, body) = Expr(:for, Expr(:block, reverse(iter_exprs)...), body)

end # module
