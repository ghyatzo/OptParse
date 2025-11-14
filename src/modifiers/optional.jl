struct ModOptional{T, S, p, P}
	initialState::S
	parser::P

	ModOptional(parser::P) where {P} =
		new{Option{tval(P)}, tstate(P), priority(P), P}(parser.initialState, parser)
end


function parse(p::ModOptional{T, S}, ctx::Context)::ParseResult{S, String} where {T, S}
	result = (@unionsplit parse(p.parser, ctx))::ParseResult{S, String}

	if !is_error(result)
		parse_ok = unwrap(result)
		return Ok(ParseSuccess(parse_ok.consumed, parse_ok.next))
	else
		return result
	end
end

function complete(p::ModOptional{T, S, _p, P}, st::S)::Result{T, String} where {T, S, _p, P}
	is_error(st) && return Ok(none(tval(P)))

	result = (@unionsplit complete(p.parser, st))::Result{tval(P), String}

	if !is_error(result)
		return Ok(some(unwrap(result)))
	else
		return Err(unwrap_error(result))
	end

end


struct ModWithDefault{T, S, p, P}
	initialState::S
	parser::P
	#
	default::T

	ModWithDefault(parser::P, default::T) where {P, T} = let
		if tval(P) != T
			error("Expected default of type $(tval(P)), got $T")
		end
		new{T, tstate(P), priority(P), P}(parser.initialState, parser, default)
	end
end

function parse(p::ModWithDefault{T, S}, ctx::Context)::ParseResult{S, String} where {T, S}
	result = (@unionsplit parse(p.parser, ctx))::ParseResult{S, String}

	if !is_error(result)
		parse_ok = unwrap(result)
		return Ok(ParseSuccess(parse_ok.consumed, parse_ok.next))
	else
		return result
	end
end

function complete(p::ModWithDefault{T, S}, st::S)::Result{T, String} where {T, S}
	is_error(st) ? Ok(p.default) : @unionsplit complete(p.parser, st)
end

