using Random
using CSV
using DataFrames
using Dates
using Distributions
using Base.Threads

# Constants for the simulation (USE COMMAND LINE ARGUMENTS)
const BETA = parse(Float64, ARGS[1])
const GAMMA = parse(Float64, ARGS[2])
const timestamp = Int(floor(datetime2unix(Dates.now()) * 1e3))
const TICKS = 4
const dt = 1 / TICKS
const SEED = 12345678

println("Beta: $BETA | Gamma: $GAMMA | Timestamp: $timestamp")

# Random.seed!(SEED)

# Define the agent structure
mutable struct Person
    age::Int
    houseID::Int
    officeID::Int
    schoolID::Int
    infection_state::Symbol  # :Susceptible, :Infected, :Recovered
    infection_time::Int  # Ticks since infection
    recovery_time::Float64
    pos::Int
end

# Define the model structure to include the cache
mutable struct Model
    agents::Vector{Person}
    infected_fraction_cache::Vector{Float64}
    location_counts::Vector{Int}  # Number of agents at each location
    infected_counts::Vector{Int}  # Number of infected agents at each location
end

# Load and process the CSV, and initialize the model
function initialize_model(file_path::String)
    df = CSV.File(file_path) |> DataFrame

    # Preallocate vectors for the agents' fields
    num_agents = nrow(df)
    ages = Vector{Int}(undef, num_agents)
    houseIDs = Vector{Int}(undef, num_agents)
    officeIDs = Vector{Int}(undef, num_agents)
    schoolIDs = Vector{Int}(undef, num_agents)
    infection_states = Vector{Symbol}(undef, num_agents)
    infection_times = zeros(Int, num_agents)
    recovery_times = Vector{Float64}(undef, num_agents)
    positions = Vector{Int}(undef, num_agents)

    # Initialize the vectors directly from DataFrame columns
    @inbounds for i in 1:num_agents
        ages[i] = df.Age[i]
        houseIDs[i] = df.HouseID[i]
        officeIDs[i] = df.OfficeID[i]
        schoolIDs[i] = df.SchoolID[i]
        infection_states[i] = df.Infected[i] == 1 ? :Infected : :Susceptible
        recovery_times[i] = df.Infected[i] == 1 ? rand(Exponential(1 / GAMMA)) : 0.0
        positions[i] = houseIDs[i]  # Start at home
    end

    agents = Vector{Person}(undef, num_agents)
    @inbounds for i in 1:num_agents
        agents[i] = Person(ages[i], houseIDs[i], officeIDs[i], schoolIDs[i], infection_states[i], infection_times[i], recovery_times[i], positions[i])
    end

    # Unique locations
    num_locations = length(unique(df.HouseID)) + length(unique(df.OfficeID)) + length(unique(df.SchoolID))

    # Initialize the model with agents and an empty cache
    model = Model(
        agents, 
        fill(0.0, num_locations),
        fill(0, num_locations),
        fill(0, num_locations)
    )
    return model
end

function update_position!(agent::Person, time_of_day::Int)
    if time_of_day == 0 || time_of_day == 3
        agent.pos = agent.houseID
    elseif time_of_day == 1 || time_of_day == 2
        agent.pos = agent.officeID != 0 ? agent.officeID : agent.schoolID
    end
end

function update_location_counts!(model::Model)
    # Reset counts
    fill!(model.location_counts, 0)
    fill!(model.infected_counts, 0)

    # Count agents at each location
    for agent in model.agents
        model.location_counts[agent.pos] += 1
        if agent.infection_state == :Infected
            model.infected_counts[agent.pos] += 1
        end
    end

    # Update infected fraction cache
    for i in 1:length(model.location_counts)
        total_agents = model.location_counts[i]
        infected_agents = model.infected_counts[i]
        model.infected_fraction_cache[i] = total_agents > 0 ? infected_agents / total_agents : 0.0
    end
end

function check_infection(agent::Person, model::Model, step::Int)
    if agent.infection_state == :Susceptible
        infected_fraction = model.infected_fraction_cache[agent.pos]
        infection_rate = BETA * infected_fraction * dt
        if rand() < infection_rate
            agent.infection_state = :Infected
            agent.infection_time = step
            agent.recovery_time = rand(Exponential(1 / GAMMA))
        end
    end
end

function check_recovery(agent::Person, step::Int)
    if agent.infection_state == :Infected
        if step >= agent.infection_time + agent.recovery_time * TICKS
            agent.infection_state = :Recovered
        end
    end
end

function agent_step!(agent::Person, model::Model, step::Int)
    check_infection(agent, model, step)
    check_recovery(agent, step)
    update_position!(agent, step % TICKS)
end

# Main simulation loop with optimized threading
function run_simulation(model::Model, days::Int)
    output_dir = "outputs/Beta-$(Int(BETA*100))"

    if !isdir(output_dir)
        mkpath(output_dir)
    end

    results = DataFrame(Day=Int[], Susceptible=Int[], Infected=Int[], Recovered=Int[])

    for step in 0:(TICKS * days)
        if step % TICKS * 2 == 0
            sus = count(a -> a.infection_state == :Susceptible, model.agents)
            inf = count(a -> a.infection_state == :Infected, model.agents)
            rec = count(a -> a.infection_state == :Recovered, model.agents)
            push!(results, [step ÷ TICKS, sus, inf, rec])
            println("$(Dates.format(Dates.now(), "HH:MM:SS.sss")) | $(step ÷ TICKS) | Susceptible: $sus | Infected: $inf | Recovered: $rec")
        end

        # println("$(Dates.format(Dates.now(), "HH:MM:SS.sss")) | $step")
        update_location_counts!(model)
        @threads for agent in model.agents
            check_infection(agent, model, step)
            check_recovery(agent, step)
        end

        @threads for agent in model.agents
            update_position!(agent, step % TICKS)
        end
    end

    CSV.write("$output_dir/SIR$(timestamp).csv", results)
end

# Example usage
file_path = "Dummy10k.csv"
file_path = "Dummy1000k.csv"
file_path = "SingleCompartment1000k.csv"
model = initialize_model(file_path)
run_simulation(model, 150)
