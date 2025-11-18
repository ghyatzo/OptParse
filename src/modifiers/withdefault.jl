struct ModWithDefault{T, S, p, P}
    initialState::S
    parser::P
    #
    default::T

    ModWithDefault(parser::P, default::T) where {T, P} = let
        new{tval(P), Option{tstate(P)}, priority(P), P}(none(tstate(P)), parser, default)
    end
end

function parse(p::ModWithDefault{T, S}, ctx::Context)::ParseResult{S, String} where {T, S}
    result = parse(p.parser, ctx)::ParseResult{tstate(p.parser), String}

    if !is_error(result)
        parse_ok = unwrap(result)
        newctx = set(parse_ok.next, PropertyLens(:state), some(parse_ok.next.state))
        return ParseOk(parse_ok.consumed, newctx)
    else
        parse_err = unwrap_error(result)
        return ParseErr(parse_err.consumed, parse_err.error)
    end
end

function complete(p::ModWithDefault{T, S}, maybestate::S)::Result{T, String} where {T, S}
    state = base(maybestate)
    isnothing(state) && return Ok(none(T))

    result = complete(p.parser, something(state))::Result{T, String}

    if !is_error(result)
        return Ok(unwrap(result))
    else
        return Err(unwrap_error(result))
    end
end
