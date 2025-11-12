
struct ArgState{S}
	buffer::Vector{String}
	state::S # accumulator for partial states (eg named tuple)
	optionsTerminated::Bool
end

ArgState(args::Vector{String}, acc) = ArgState{typeof(acc)}(args, acc, false)

struct ParseSuccess{S}
	consumed::Vector{String}
	next::ArgState{S}
end


struct ParseFailure{E}
	consumed::Int
	error::E
end

const ParseResult{S, E} = Result{ParseSuccess{S}, ParseFailure{E}}

struct Parser{T, S}
	priority::Int
	initialState::S
	parse::Function # (S) -> ParseResult{S, String}
	complete::Function # (S) -> Result{T, String}
end

Parser{T}(priority, init, parse, complete) where {T} = Parser{T, typeof(init)}(priority, init, parse, complete)


# struct ParserContext{T}
# 	buffer::Vector{String}
# 	state::T
# 	optionsTerminated::Bool
# end


# struct ParserSuccess{T}
# 	consumed::Vector{String}
# 	next::ParserContext{T}
# end

# struct ParserFailure
# 	consumed::Integer
# 	error::String
# end

# const ParserResult{T} = Result{ParserSuccess{T}, ParserFailure}
# # parser interface,
# # all objects and funciton will always return a parser!
# # struct _Parser{TValue, TState}
# # 	priority::Integer
# # 	initialState::TState

# # 	# ... extra stuff
# # end

# # function parse end # ParserContext -> ::Result{ParseSuccess, ParseFailure}

# # function complete end # TState -> ::Result{TValue, ValueFailure}

# # function gethelp end
