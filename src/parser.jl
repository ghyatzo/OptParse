struct Context{S}
    buffer::Vector{String}
    state::S # accumulator for partial states (eg named tuple, single result, etc)
    optionsTerminated::Bool
end

Context(args::Vector{String}, state) =
    Context{typeof(state)}(args, state, false)


struct ParseSuccess{S}
    consumed::Tuple{Vararg{String}}
    next::Context{S}
end

ParseSuccess(cons::Vector{String}, next::Context{S}) where {S} = ParseSuccess{S}((cons...,), next)
ParseSuccess(cons::String, next::Context{S}) where {S} = ParseSuccess{S}((cons,), next)

struct ParseFailure{E}
    consumed::Int
    error::E
end

const ParseResult{S, E} = Result{ParseSuccess{S}, ParseFailure{E}}

ParseOk(consumed, next::Context{S}) where {S} =
    Ok(ParseSuccess(consumed, next))
ParseErr(consumed, error) =
    Err(ParseFailure(consumed, error))
