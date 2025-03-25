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
    SCHOOL_CLOSED_SCHEDULE_ID::Int
    OFFICE_CLOSED_SCHEDULE_ID::Int
    # New parameters for policy-based interventions
    S_DISCRETIZATION::Float64
    I_DISCRETIZATION::Float64
    POLICY_FILE::String

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
        SCHOOL_CLOSED_SCHEDULE_ID,
        OFFICE_CLOSED_SCHEDULE_ID,
        S_DISCRETIZATION,
        I_DISCRETIZATION,
        POLICY_FILE,
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
            SCHOOL_CLOSED_SCHEDULE_ID,
            OFFICE_CLOSED_SCHEDULE_ID,
            S_DISCRETIZATION,
            I_DISCRETIZATION,
            POLICY_FILE,
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
        TIMESTAMP=Int(floor(Dates.datetime2unix(Dates.now()) * 1e3)),
        INPUT=get(config_data, "INPUT", "SingleCompartment1000k"),
        INPUTFILE=get(config_data, "INPUT", "SingleCompartment1000k") * ".csv",
        TICKS=get(config_data, "TICKS", 4),
        BETA=get(config_data, "BETA", 0.35),
        GAMMA=get(config_data, "GAMMA", 0.14),
        ALPHA=get(config_data, "ALPHA", 0.0),
        DAYS=get(config_data, "DAYS", 150),
        DT=(1 / get(config_data, "TICKS", 4)),
        SCHOOL_CLOSED_SCHEDULE_ID=get(config_data, "SCHOOL_CLOSED_SCHEDULE_ID", 4),
        OFFICE_CLOSED_SCHEDULE_ID=get(config_data, "OFFICE_CLOSED_SCHEDULE_ID", 5),
        # New parameters with default discretizations and policy file name:
        S_DISCRETIZATION=get(config_data, "S_DISCRETIZATION", 0.01),
        I_DISCRETIZATION=get(config_data, "I_DISCRETIZATION", 0.01),
        POLICY_FILE=get(config_data, "POLICY_FILE", "policy.json"),
        OUTPUTDIR=(get(config_data, "OUTPUTDIR", "outputs")),
    )
end

config_file = length(ARGS) > 0 ? ARGS[1] : "config.toml"
config = load_config(config_file)

end  # module Config