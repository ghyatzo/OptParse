@wrapped struct CommandState{S}
    union::Union{
        Missing, # Command did not match anything yet
        Nothing, # Command did match something
        Result{S,String} # Command is parsing with its child parser
    }
end

CommandState(::Nothing) = CommandState{Nothing}(nothing)
CommandState(::Missing) = CommandState{Missing}(missing)
CommandState(s::S) where {S} = CommandState{Result{S,String}}(Ok(s))


struct ArgCommand{T,S,_p,P}
    initialState::S
    parser::P
    #
    name::String
    brief::String
    description::String
    footer::String

    ArgCommand(name, parser::P; brief="", description="", footer="") where {P<:Parser} =
        new{tval(P),CommandState{tstate(P)},15,P}(CommandState(nothing), parser, name, brief, description, footer)
end

parse(p::ArgCommand, ctx)::ParseResult{String,String} = ParseErr(0, "Invalid command state. (YOU REACHED AN UNREACHABLE).")


function parse(p::ArgCommand, ctx::Context{CommandState{Missing}})::ParseResult{CommandState{Nothing},String} where {T,S}
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
        ctx.buffer[1:1], Context(
            ctx.buffer[2:end],
            CommandState(nothing),
            ctx.optionsTerminated
        )
    )
end

function parse(p::ArgCommand{T,S}, ctx::Context{CommandState{Nothing}})::ParseResult{S,String} where {T,S}
    # command did match, start the inner parser
    result = parse(p.parser, p.parser.initialState)

    if !is_error(result)
        parse_ok = unwrap(result)

        newctx = @set ctx.state = parse_ok
        return ParseOk(parse_ok.consumed, newctx)

    else
        return result
    end
end

function parse(p::ArgCommand, ctx::Context)::ParseResult
    # parse is ongoing, delegate to the inner parser

    # we pass through the state of the parser P
    childctx = @set ctx.state = ctx.state # some unwrapping happens here...
    result = parse(p.parser, ctx.state)

    if !is_error(result)
        parse_ok = unwrap(result)
        oldctx = parse_ok.next
        newctx = @set oldctx.state = parse_ok.next # some wrapping into a CommandState or something
        return ParseOk(
            parse_ok.consumed, newctx
        )
    else
        return result
    end
end

