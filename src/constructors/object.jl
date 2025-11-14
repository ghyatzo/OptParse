struct Object{T, S, p, P}
	initialState::S # NamedTuple of the states of its parsers
	#
	parsers::P
	label::String
end

Object{T}(priority, initialState::S, parsers, label) where {T, S} =
	Object{T, S, priority, typeof(parsers)}(initialState, parsers, label)

#=
	This is does the same thing but in a different way.
	The difference is that the generated function approach
	stresses the compiler more. And deals with an AST instead of an actual value
=#
# @generated function gen_sorted_obj(nt::NamedTuple{labels, parsers_t_tup}) where {labels, parsers_t_tup}
# 	parsers_t = collect(parsers_t_tup.parameters)
# 	perm = sortperm(parsers_t; by=priority, rev=true)
# 	slabels = labels[perm]
# 	:(nt[$slabels])
# end

#=
	we're using @assume_effects :foldable in order to tell julia that
	this function is actually allowed to be constant-folded!
	(from Mason Protter, black magic)
=#
Base.@assume_effects :foldable function _sort_obj_labels(labels, ::Type{parsers_t_tup}
	) where {parsers_t_tup <: Tuple}
	perm = sortperm(collect(parsers_t_tup.parameters); by=priority, rev=true)
	labels[perm]
end

function _sort_obj(obj::NamedTuple{labels, parsers_t_tup}
	) where {labels, parsers_t_tup <: Tuple}
	slabels = _sort_obj_labels(labels, parsers_t_tup)
	obj[slabels]
end

_object(obj::NamedTuple; label="") = let

	sobj = _sort_obj(obj)
	labels = keys(sobj)
	parsers_t = fieldtypes(typeof(sobj))
	parsers = values(sobj)
	parsers_tvals = map(tval, parsers_t)
	parsers_tstates = map(tstate, parsers_t)
	priorities = map(priority, parsers_t)

	obj_t = NamedTuple{labels, Tuple{parsers_tvals...}}
	init_state = NamedTuple{labels}(map(p->getproperty(p, :initialState), parsers))

	Object{obj_t}(maximum(priorities), init_state, sobj, label)
end

#= this works! we can attempt some kind of recursion... although, yikes =#
# function test(t::NamedTuple{labels, Tup}, cx::NamedTuple) where {labels, Tup}
# 	_test(labels, cx, values(t))
# end

# @inline function _test(labels, cx, v)
# 	cx = _test(Base.tail(labels), cx, Base.tail(v))
# 	set(cx, PropertyLens(first(labels)), first(v))
# end
# _test(::Tuple{}, cx, v) = cx
# _test(a, cx, ::Tuple{}) = cx

_recursive_parse_parsers(::@NamedTuple{}, ctx, error, all_consumed, anysuccess) =
	return ctx, error, all_consumed, false, anysuccess

_recursive_parse_parsers(p::NamedTuple{labels}, ctx, error, all_consumed, anysuccess) where {labels} = let

	field = first(labels)
	child_state = ctx.state[field]
	child_parser = p[field]

	child_ctx = @set ctx.state = child_state

	result = (@unionsplit parse(child_parser, child_ctx))::ParseResult{typeof(child_state), String}

	# @info result ctx
	# @info

	if is_error(result)
		parse_err = unwrap_error(result)
		if error.consumed <= parse_err.consumed
			error = parse_err
		end
	else
		parse_ok = unwrap(result)
		if length(parse_ok.consumed) > 0
			newstate = set(ctx.state, PropertyLens(field), parse_ok.next.state)

			newctx = Context(
				parse_ok.next.buffer,
				newstate,
				ctx.optionsTerminated
			)

			all_consumed = (all_consumed..., parse_ok.consumed...)

			return newctx, error, all_consumed, true, true
		end
	end

	return _recursive_parse_parsers(Base.tail(p), ctx, error, all_consumed, anysuccess)
end

function parse(p::Object{NamedTuple{fields, Tup}, S}, ctx::Context)::ParseResult{S, String} where {fields, Tup, S}
	error = ParseFailure(0, "Expected argument, option or command, but got end of input.")

	#= greedy parsing trying to consume as many field as possible =#
	anysuccess = false
	allconsumed::Tuple{Vararg{String}} = ()

	#= keep trying to parse fields until no more can be matched =#
	current_ctx = ctx
	made_progress = true
	while (made_progress && length(ctx.buffer) > 0)
		# @infiltrate
		current_ctx, error, allconsumed, made_progress, anysuccess = _recursive_parse_parsers(p.parsers, current_ctx, error, allconsumed, anysuccess)
	end


	if anysuccess
		return Ok(ParseSuccess{S}(
			allconsumed,
			current_ctx
		))
	end

	#= if buffer is empty check if all parsers can complete anyway =#
	if length(ctx.buffer) == 0
		all_can_complete, _ = _recursive_complete_parsers(p.parsers, ctx.state, (;))

		if all_can_complete
			return Ok(ParseSuccess((), ctx))
		end
	end

	return Err(error)
end

# function parse(p::Object{NamedTuple{fields, Tup}, S}, ctx::Context)::ParseResult{S, String} where {fields, Tup, S}

# 	error = ParseFailure(0, "Expected argument, option or command, but got end of input.")

# 	#= greedy parsing trying to consume as many field as possible =#
# 	current_ctx = ctx
# 	any_success = false

# 	all_consumed = String[]

# 	#= keep trying to parse fields until no more can be matched =#
# 	made_progress = true
# 	while (made_progress && length(ctx.buffer) > 0)
# 		made_progress = false

# 		for field in fields

# 			child_parser_state = isnothing(current_ctx.state) || field ∉ keys(current_ctx.state) ?
# 				p.initialState[field] : current_ctx.state[field]

# 			child_parser_ctx = Context(
# 				current_ctx.buffer,
# 				child_parser_state,
# 				current_ctx.optionsTerminated
# 			)

# 			result = (@unionsplit parse(p.parsers[field], child_parser_ctx))::ParseResult{typeof(child_parser_state), String}

# 			if !is_error(result)
# 				parse_ok = unwrap(result)

# 				if length(parse_ok.consumed) > 0
# 					newstate = @inline set(current_ctx.state, PropertyLens(field), parse_ok.next.state)::S

# 					current_ctx = Context(
# 						parse_ok.next.buffer,
# 						newstate,
# 						parse_ok.next.optionsTerminated
# 					)
# 					append!(all_consumed, parse_ok.consumed)
# 					any_success = true
# 					made_progress = true
# 					break #= restart the field loop with an updated state =#
# 				end

# 			elseif is_error(result)
# 				parse_err = unwrap_error(result)
# 				if error.consumed < parse_err.consumed
# 					error = parse_err
# 				end
# 			end
# 		end
# 	end

# 	if any_success
# 		return Ok(ParseSuccess{S}(
# 			all_consumed,
# 			current_ctx
# 		))
# 	end

# 	#= if buffer is empty and no parser consumed input, check if all parsers can complete =#
# 	if length(ctx.buffer) == 0
# 		all_can_complete = true

# 		for field in labels
# 			field_state = isnothing(ctx.state) || field ∉ keys(ctx.state) ? p.initialState[field] : ctx.state[field]

# 			complete_result = complete(p.parsers[field], field_state)

# 			if is_error(complete_result)
# 				all_can_complete = false
# 				break
# 			end
# 		end

# 		if all_can_complete
# 			return Ok(ParseSuccess([], ctx))
# 		end
# 	end

# 	return Err(error)
# end

_recursive_complete_parsers(::@NamedTuple{}, _, output::NamedTuple) =
	true, output
_recursive_complete_parsers(p::NamedTuple{labels}, state, output::NamedTuple) where {labels} = let
	field = first(labels)
	child_state = state[field]
	child_parser = p[field]

	result = (@unionsplit complete(child_parser, child_state))::Result{tval(typeof(child_parser)), String}
	is_error(result) && return false, result

	output = insert(output, PropertyLens(field), unwrap(result))

	return _recursive_complete_parsers(Base.tail(p), state, output)
end

function complete(p::Object{T}, st::NamedTuple)::Result{T, String} where {T}
	cancomplete, _result = _recursive_complete_parsers(p.parsers, st, (;))

	if !cancomplete
		return Err(unwrap_error(_result))
	end

	return Ok(_result)
end


# function complete(p::Object{T}, st::NamedTuple)::Result{T, String} where {T}
# 	@info st
# 	_result = _build_result(T, p.parsers, st)
# 	for mayberes in values(_result)
# 		if mayberes isa Result && !(mayberes isa Option) && is_error(mayberes)
# 			return Err(unwrap_error(mayberes))
# 		end
# 	end

# 	return Ok(_result)
# end


# @generated function _build_result(
# 		::Type{NamedTuple{objlabels, tvals}},
# 		parsers::NamedTuple{objlabels, parsers_t},
# 		st::NamedTuple{st_labels, tstates}
# 	) where {objlabels, tvals, st_labels, tstates, parsers_t}

# 	_filter_id = findall(∈(st_labels), objlabels)

# 	labels = objlabels[_filter_id]
# 	matching_tvals = tvals.parameters[_filter_id]

# 	ex = Expr(:tuple)
# 	for (label, val) in zip(labels, matching_tvals)
# 		push!(ex.args, :($label = @? (@unionsplit complete(parsers[$(QuoteNode(label))], st[$(QuoteNode(label))]))::Result{$val, String}))
# 	end

# 	return ex
# end

