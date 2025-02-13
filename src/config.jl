module Config

using Logging
using Dates

export INPUT, TICKS, BETA, GAMMA, DAYS, DT, OUTPUTDIR

global TIMESTAMP = Int(floor(datetime2unix(Dates.now()) * 1e3))
global INPUT = "SingleCompartment1000k"
global INPUTFILE = "SingleCompartment1000k.csv"
global TICKS = 4
global BETA = 0.35
global GAMMA = 0.14
global ALPHA = 0.0
global DAYS = 150
global DT = 1 / TICKS
global OUTPUTDIR = "outputs/Julia"
global TRAVEL_PROBABILITY = 0.0

global PRUNEDAY = 0
global SCALE = 10
global REMOVE_PROBABILITY = 1 - (1 / SCALE)
global PRUNE = false
global PRUNE_METHOD = "Random"

global LOCKDOWN = false
global LOCKDOWN_DAY = 0
global LOCKDOWN_DURATION = 0


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
            elseif key == "ALPHA"
                global ALPHA = parse(Float64, value)
                @info("Set ALPHA to $ALPHA")
            elseif key == "DAYS"
                global DAYS = parse(Int, value)
                @info("Set DAYS to $DAYS")
            elseif key == "PRUNE"
                global PRUNE = parse(Int, value) == 1
                @info("Set PRUNE to $PRUNE")
            elseif key == "PRUNEDAY"
                global PRUNEDAY = parse(Int, value)
                @info("Set PRUNEDAY to $PRUNEDAY")
            elseif key == "PRUNEMETHOD"
                global PRUNE_METHOD = String(value)
                @info("Set PRUNE_METHOD to $PRUNE_METHOD")
            elseif key == "TRAVEL"
                global TRAVEL_PROBABILITY = parse(Float64, value)
                @info("Set TRAVEL_PROBABILITY to $TRAVEL_PROBABILITY")
            elseif key == "LOCKDOWN"
                global LOCKDOWN = parse(Int, value) == 1
                @info("Set LOCKDOWN to $LOCKDOWN")
            elseif key == "LOCKDOWNDAY"
                global LOCKDOWN_DAY = parse(Int, value)
                @info("Set LOCKDOWN_DAY to $LOCKDOWN_DAY")
            elseif key == "LOCKDOWNDURATION"
                global LOCKDOWN_DURATION = parse(Int, value)
                @info("Set LOCKDOWN_DURATION to $LOCKDOWN_DURATION")
            else
                throw(ArgumentError("Unsupported flag: \"$key\". Available flags are INPUT, TICKS, BETA, GAMMA, and DAYS."))
            end
        end
    end

    global OUTPUTDIR = "outputs/beta$BETA-gamma$GAMMA-alpha$ALPHA-input$INPUT-days$DAYS-prune$PRUNE-pruneday$PRUNEDAY-prunemethod$PRUNE_METHOD-travel$TRAVEL_PROBABILITY-lockdown$LOCKDOWN-lockdownday$LOCKDOWN_DAY-lockdownduration$LOCKDOWN_DURATION"
end

end