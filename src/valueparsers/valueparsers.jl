
# Value Parser interface
# struct _ValueParser{T}
# 	metavar::String
# 	# ... custom vars
# end

# function parse end # String -> Result{T, String}
# function format end # T -> String


@kwdef struct StringVal
	metavar::String = "STRING"
	pattern::Regex = r".*"
end

(s::StringVal)(input::String)::Result{String, String} = let
	m = match(s.pattern, input)
	isnothing(m) && return Err("Expected a string matching pattern $(s.pattern), but got $input.")
	return Ok(input)
end

@kwdef struct Choice
	metavar::String = "CHOICE"
	caseInsensitive::Bool = true
	values::Vector{String}

	Choice(metavar, caseInsensitive, values) = let
		normvals = caseInsensitive ? map(lowercase, values) : values
		new(metavar, caseInsensitive, normvals)
	end
end

(c::Choice)(input::String)::Result{String, String}= let
	norminput = c.caseInsensitive ? lowercase(input) : input
	index = findfirst(==(norminput), c.values)

	isnothing(index) && return Err("Expected of of $(join(c.values, ',')), but got $input")
	return Ok(c.values[index])
end


@wrapped struct ValueParser{T}
	union::Union{
		StringVal,
		Choice,
		Nothing
	}
end

(parse(x::ValueParser{T}, input::String)::Result{T, String}) where {T} = @unionsplit parse(x, input)


stringval(;kw...) = ValueParser{String}(StringVal(;kw...))
choice(;kw...) = ValueParser{String}(Choice(;kw...))