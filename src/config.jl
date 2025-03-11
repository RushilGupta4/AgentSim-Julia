module Config

using Dates
using TOML

export SimulationConfig, load_config, config

"""
    SimulationConfig

A struct that holds all configuration parameters for the simulation run.
"""
struct SimulationConfig
    TIMESTAMP::Int
    INPUT::String
    INPUTFILE::String
    TICKS::Int
    BETA::Float64
    GAMMA::Float64
    ALPHA::Float64
    DAYS::Int
    DT::Float64
    OUTPUTDIR::String
    PRUNEDAY::Int
    SCALE::Int
    REMOVE_PROBABILITY::Float64
    PRUNE::Bool
    PRUNE_METHOD::String
    GENERATION_LOOKBACK::Int
    SCHOOL_CLOSED::Bool
    SCHOOL_CLOSED_DAYS::Vector{Int}
    SCHOOL_CLOSED_DURATIONS::Vector{Int}
    SCHOOL_CLOSED_STRENGTHS::Vector{Float64}
    OFFICE_CLOSED::Bool
    OFFICE_CLOSED_DAYS::Vector{Int}
    OFFICE_CLOSED_DURATIONS::Vector{Int}
    OFFICE_CLOSED_STRENGTHS::Vector{Float64}
    SCHOOL_CLOSED_SCHEDULE_ID::Int
    OFFICE_CLOSED_SCHEDULE_ID::Int

    function SimulationConfig(;
        TIMESTAMP,
        INPUT,
        INPUTFILE,
        TICKS,
        BETA,
        GAMMA,
        ALPHA,
        DAYS,
        DT,
        OUTPUTDIR,
        PRUNEDAY,
        SCALE,
        REMOVE_PROBABILITY,
        PRUNE,
        PRUNE_METHOD,
        GENERATION_LOOKBACK,
        SCHOOL_CLOSED,
        SCHOOL_CLOSED_DAYS,
        SCHOOL_CLOSED_DURATIONS,
        SCHOOL_CLOSED_STRENGTHS,
        OFFICE_CLOSED,
        OFFICE_CLOSED_DAYS,
        OFFICE_CLOSED_DURATIONS,
        OFFICE_CLOSED_STRENGTHS,
        SCHOOL_CLOSED_SCHEDULE_ID,
        OFFICE_CLOSED_SCHEDULE_ID,
    )
        new(
            TIMESTAMP,
            INPUT,
            INPUTFILE,
            TICKS,
            BETA,
            GAMMA,
            ALPHA,
            DAYS,
            DT,
            OUTPUTDIR,
            PRUNEDAY,
            SCALE,
            REMOVE_PROBABILITY,
            PRUNE,
            PRUNE_METHOD,
            GENERATION_LOOKBACK,
            SCHOOL_CLOSED,
            SCHOOL_CLOSED_DAYS,
            SCHOOL_CLOSED_DURATIONS,
            SCHOOL_CLOSED_STRENGTHS,
            OFFICE_CLOSED,
            OFFICE_CLOSED_DAYS,
            OFFICE_CLOSED_DURATIONS,
            OFFICE_CLOSED_STRENGTHS,
            SCHOOL_CLOSED_SCHEDULE_ID,
            OFFICE_CLOSED_SCHEDULE_ID,
        )
    end
end

"""
    load_config(file_path::String) -> SimulationConfig

Loads the simulation configuration from a TOML file.
"""
function load_config(file_path::String)
    config_data = TOML.parsefile(file_path)

    return SimulationConfig(
        # Use current timestamp
        TIMESTAMP=Int(floor(Dates.datetime2unix(Dates.now()) * 1e3)),
        INPUT=get(config_data, "INPUT", "SingleCompartment1000k"),
        INPUTFILE=get(config_data, "INPUT", "SingleCompartment1000k") * ".csv",
        TICKS=get(config_data, "TICKS", 4),
        BETA=get(config_data, "BETA", 0.35),
        GAMMA=get(config_data, "GAMMA", 0.14),
        ALPHA=get(config_data, "ALPHA", 0.0),
        DAYS=get(config_data, "DAYS", 150),
        DT=(1 / get(config_data, "TICKS", 4)),
        PRUNEDAY=get(config_data, "PRUNEDAY", 0),
        SCALE=get(config_data, "SCALE", 10),
        REMOVE_PROBABILITY=get(config_data, "REMOVE_PROBABILITY", 0.9),
        PRUNE=get(config_data, "PRUNE", false),
        PRUNE_METHOD=get(config_data, "PRUNE_METHOD", "Random"),
        GENERATION_LOOKBACK=get(config_data, "GENERATION_LOOKBACK", 0),
        SCHOOL_CLOSED=get(config_data, "SCHOOL_CLOSED", false),
        SCHOOL_CLOSED_DAYS=get(config_data, "SCHOOL_CLOSED_DAYS", Int[]),
        SCHOOL_CLOSED_DURATIONS=get(config_data, "SCHOOL_CLOSED_DURATIONS", Int[]),
        SCHOOL_CLOSED_STRENGTHS=get(config_data, "SCHOOL_CLOSED_STRENGTHS", Float64[]),
        OFFICE_CLOSED=get(config_data, "OFFICE_CLOSED", false),
        OFFICE_CLOSED_DAYS=get(config_data, "OFFICE_CLOSED_DAYS", Int[]),
        OFFICE_CLOSED_DURATIONS=get(config_data, "OFFICE_CLOSED_DURATIONS", Int[]),
        OFFICE_CLOSED_STRENGTHS=get(config_data, "OFFICE_CLOSED_STRENGTHS", Float64[]),
        SCHOOL_CLOSED_SCHEDULE_ID=get(config_data, "SCHOOL_CLOSED_SCHEDULE_ID", 4),
        OFFICE_CLOSED_SCHEDULE_ID=get(config_data, "OFFICE_CLOSED_SCHEDULE_ID", 5),
        OUTPUTDIR="outputs/$file_path",
    )
end


config_file = length(ARGS) > 0 ? ARGS[1] : "config.toml"
config = load_config(config_file)

end  # module Config
