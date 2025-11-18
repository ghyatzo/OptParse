# single boolean flags: -q --long
struct ArgFlag{T, S, p, P}
    initialState::S
    _dummy::P
    #
    names::Vector{String}
    description::String


    ArgFlag(names::Tuple{Vararg{String}}; description = "") =
        new{Bool, Result{Bool, String}, 9, Nothing}(Err("Missing Flag(s) $(names)."), nothing, [names...], description)
end


function parse(p::ArgFlag{Bool, Result{Bool, String}}, ctx::Context)::ParseResult{Result{Bool, String}, String}

    if ctx.optionsTerminated
        return ParseErr(0, "No more options to be parsed.")
    elseif length(ctx.buffer) < 1
        return ParseErr(0, "Expected a flag, got end of input.")
    end

    #= When the input contains `--` is a signal to stop parsing options =#
    if (ctx.buffer[1] === "--")
        next = Context(ctx.buffer[2:end], ctx.state, true)
        return ParseOk(ctx.buffer[1:1], next)
    end

    if ctx.buffer[1] in p.names

        if !is_error(ctx.state) && unwrap(ctx.state)
            return ParseErr(1, "$(ctx.buffer[1]) cannot be used multiple times")
        end

        return ParseOk(
            ctx.buffer[1:1],

            Context(
                ctx.buffer[2:end],
                Result{Bool, String}(Ok(true)),
                ctx.optionsTerminated
            )
        )
    end

    #= When the input contains bundled options: -abc =#
    short_options = filter(p.names) do name
        match(r"^-[^-]$", name) !== nothing
    end

    for short_opt in short_options
        startswith(ctx.buffer[1], short_opt) || continue

        if !is_error(ctx.state) && unwrap(ctx.state)
            return ParseErr(1, "Flag $(short_opt) cannot be used multiple times")
        end

        return ParseOk(
            ctx.buffer[1][1:2],

            Context(
                ["-$(ctx.buffer[1][3:end])", ctx.buffer[2:end]...],
                Result{Bool, String}(Ok(true)),
                ctx.optionsTerminated
            )
        )
    end

    return ParseErr(
        0, "No Matched Flag for $(ctx.buffer[1])"
    )
end

function complete(p::ArgFlag, st::Result{Bool, String})::Result{Bool, String}
    !is_error(st) && return st
    error = unwrap_error(st)
    return Err("$(p.names): $error")
end
