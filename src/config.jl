module Config

export INPUT, TICKS, BETA, GAMMA, DAYS, DT, OUTPUTDIR

global INPUT = "SingleCompartment1000k"
global INPUTFILE = "SingleCompartment1000k.csv"
global TICKS = 4
global BETA = 0.35
global GAMMA = 0.14
global DAYS = 150
global DT = 1 / TICKS
global OUTPUTDIR = "outputs/Julia"

using Logging

function parseArgs!(args::Vector{String})
    for arg in args
        println(arg)
        parts = split(arg, "=")
        
        if length(parts) != 2
            throw(ArgumentError("Unsupported syntax for argument: \"$arg\". Flag syntax is `name=value`, without spaces."))
        else
            key = uppercase(parts[1])
            value = parts[2]

            # Update global variables based on the argument key
            if key == "INPUT"
                global INPUT = String(value)
                global INPUTFILE = INPUT * ".csv"
                @info("Set INPUT file to $INPUT")
            elseif key == "BETA"
                global BETA = parse(Float64, value)
                @info("Set BETA to $BETA")
            elseif key == "GAMMA"
                global GAMMA = parse(Float64, value)
                @info("Set GAMMA to $GAMMA")
            elseif key == "DAYS"
                global DAYS = parse(Int, value)
                @info("Set DAYS to $DAYS")
            else
                throw(ArgumentError("Unsupported flag: \"$key\". Available flags are INPUT, TICKS, BETA, GAMMA, and DAYS."))
            end
        end
    end

    # global OUTPUTDIR = "outputs/beta-$BETA-gamma-$GAMMA-input-$INPUT"
end

parseArgs!(ARGS)

end