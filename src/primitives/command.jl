

const CommandState{X} = Union{Nothing, Option{X}}


struct ArgCommand{T, S, _p, P}
    initialState::S
    parser::P
    #
    name::String
    brief::String
    description::String
    footer::String

    ArgCommand(name, parser::P; brief = "", description = "", footer = "") where {P} =
        new{tval(P), CommandState{tstate(P)}, 15, P}(nothing, parser, name, brief, description, footer)
end

# parse(p::ArgCommand, ctx)::ParseResult{String,String} = ParseErr(0, "Invalid command state. (YOU REACHED AN UNREACHABLE).")


function parse(p::ArgCommand{T, TState}, ctx::Context{Nothing})::ParseResult{TState, String} where {T, TState <: CommandState}
    # command not yet matched
    # check if it starts with our command name
    if length(ctx.buffer) < 1 || ctx.buffer[1] != p.name
        actual = length(ctx.buffer) > 0 ? ctx.buffer[1] : nothing

        if actual === nothing
            return ParseErr(0, "Expected command `$(p.name)`, but got end of input.")
        end

        return ParseErr(0, "Expected command `$(p.name)`, but got `$actual`.")
    end

    # command matched, consume it and move to the matched state
    return ParseOk(
        ctx.buffer[1:1], Context{TState}(
            ctx.buffer[2:end],
            none(Pstate),
            ctx.optionsTerminated
        )
    )
end

function parse(p::ArgCommand{T, CommandState{Pstate}}, ctx::Context{Option{Pstate}})::ParseResult{CommandState{Pstate}, String} where {T, Pstate}
    maybestate = base(ctx.state)
    childstate = isnothing(maybestate) ? p.parser.initialState : @something maybestate
    childctx = @set ctx.state = childstate

    result = parse(p.parser, childctx)::ParseResult{Pstate, String}

    if !is_error(result)
        parse_ok = unwrap(result)

        nextctx = parse_ok.next
        return ParseOk(
            parse_ok.consumed,
            Context{CommandState{Pstate}}(nextctx.buffer, some(nextctx.state), nextctx.optionsTerminated)
        )
    else
        parse_err = unwrap_error(result)
        return ParseErr(parse_err.consumed, parse_err.error)
    end
end


function complete(p::ArgCommand{T, <: CommandState}, ::Nothing)::Result{T, String} where {T}
    return Err("Command $(p.name) was not matched")
end
function complete(p::ArgCommand{T, CommandState{S}}, maybest::Option{S})::Result{T, String} where {T, S}
    st = base(maybest)
    if isnothing(st)
        # command matched but the inner parser never started: pass in the initialState
        return complete(p.parser, p.parser.initialState)
    else
        return complete(p.parser, @something st)
    end
end
