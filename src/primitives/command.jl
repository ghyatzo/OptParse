# @wrapped struct CommandState{S}
#     union::Union{
#         Missing, # Command did not match anything yet
#         Nothing, # Command did match something
#         S, # Command is parsing with its child parser
#     }
# end

# CommandState(::Nothing) = CommandState{Nothing}(nothing)
# CommandState(::Missing) = CommandState{Missing}(missing)
# CommandState(s::S) where {S} = CommandState{Result{S,String}}(Ok(s))

const CommandState{X} = Union{Nothing,Option{X}}


struct ArgCommand{T,S,_p,P}
    initialState::S
    parser::P
    #
    name::String
    brief::String
    description::String
    footer::String

    ArgCommand(name, parser::P; brief="", description="", footer="") where {P} =
        new{tval(P),CommandState{tstate(P)},15,P}(nothing, parser, name, brief, description, footer)
end

# parse(p::ArgCommand, ctx)::ParseResult{String,String} = ParseErr(0, "Invalid command state. (YOU REACHED AN UNREACHABLE).")


function parse(p::ArgCommand{T,CommandState{Pstate}}, ctx::Context{Nothing})::ParseResult{CommandState{Pstate},String} where {T,Pstate}
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
        ctx.buffer[1:1], Context{CommandState{Pstate}}(
            ctx.buffer[2:end],
            none(Pstate),
            ctx.optionsTerminated
        )
    )
end

function parse(p::ArgCommand{T,S}, ctx::Context)::ParseResult{S,String} where {T,S}
    maybestate = base(ctx.state)

    childstate = isnothing(maybestate) ? p.parser.initialState : @something maybestate
    childctx = @set ctx.state = childstate

    result = parse(p.parser, childctx)::ParseResult{tstate(p.parser),String}

    if !is_error(result)
        parse_ok = unwrap(result)

        nextctx = parse_ok.next
        return ParseOk(
            parse_ok.consumed,
            Context{S}(nextctx.buffer, some(nextctx.state), nextctx.optionsTerminated)
        )
    else
        return result
    end
end


function complete(p::ArgCommand{T,CommandState{S}}, ::Nothing)::Result{T,String} where {T,S}
    return Err("Command $(p.name) was not matched")
end
function complete(p::ArgCommand{T,CommandState{S}}, maybest::Option{S})::Result{T,String} where {T,S}
    st = base(maybest)
    if isnothing(st)
        # command matched but the inner parser never started: pass in the initialState
        return complete(p.parser, p.parser.initialState)
    else
        return complete(p.parser, @something st)
    end
end





