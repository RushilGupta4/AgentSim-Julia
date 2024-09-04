using Agents
using Random
using Graphs
using CSV
using DataFrames
using Dates
using Distributions

# Constants for the simulation
const BETA = 0.5
const GAMMA = 0.14
const TICKS = 4
const dt = 1 / TICKS
const SEED = 12345678

Random.seed!(SEED)


# Define the agent structure
@agent struct Person(GraphAgent)
    age::Int
    houseID::Int
    officeID::Int
    schoolID::Int
    infection_state::Symbol  # :Susceptible, :Infected, :Recovered
    infection_time::Int  # Ticks since infection
    recovery_time::Float64
end

# Load and process the CSV, and initialize the model
function initialize_model(file_path::String)
    df = CSV.read(file_path, DataFrame)
    houses = Set("H" .* string.(df.HouseID))
    offices = Set("O" .* string.(df[df.OfficeID .!= 0, :OfficeID]))
    schools = Set("S" .* string.(df[df.SchoolID .!= 0, :SchoolID]))
    all_locations = union(houses, offices, schools)
    
    graph_size = length(all_locations)
    graph = SimpleGraph(graph_size)
    space = GraphSpace(graph)
    properties = Dict(:step => 0, :infected_fraction_cache => Dict(), :rng => MersenneTwister(SEED), :recovery_distribution => Exponential(1 / GAMMA))

    model = ABM(Person, space; agent_step!, properties)

    for row in eachrow(df)
        state = row.Infected == 1 ? :Infected : :Susceptible
        recovery_time = state == :Infected ? rand(model.recovery_distribution) : 0.0
        
        house = row.HouseID
        office = row.OfficeID + length(houses)
        school = row.SchoolID + length(houses) + length(offices)

        add_agent!(house, model, row.Age, house, office, school, state, 0, recovery_time)
    end


    return model
end


function update_position!(agent, model)
    time_of_day = model.step % TICKS

    if 0 <= time_of_day < 1 || 3 <= time_of_day < 4
        # Home time (0-6AM and 6PM-12AM)
        move_agent!(agent, agent.houseID, model)
    elseif 1 <= time_of_day < 3
        # Work/School time (6AM-6PM)
        if agent.officeID != 0
            move_agent!(agent, agent.officeID, model)
        elseif agent.schoolID != 0
            move_agent!(agent, agent.schoolID, model)
        end
    end
end

function get_infected_fraction(location, model)
    if haskey(model.infected_fraction_cache, location)
        return model.infected_fraction_cache[location]
    end

    agents_here = ids_in_position(location, model)
    total_agents = length(agents_here)
    infected_agents = count(a_id -> model[a_id].infection_state == :Infected, agents_here)
    
    fraction = total_agents > 0 ? infected_agents / total_agents : 0.0
    model.infected_fraction_cache[location] = fraction
    return fraction
end


function check_infection(agent, model)
    if agent.infection_state != :Susceptible
        return
    end

    infected_fraction = get_infected_fraction(agent.pos, model)
    infection_rate = BETA * infected_fraction * dt
    if rand(model.rng) < infection_rate
        agent.infection_state = :Infected
        agent.infection_time = 0
        agent.recovery_time = rand(model.recovery_distribution)
    end
end

function check_recovery(agent)
    if agent.infection_state == :Infected
        agent.infection_time += 1
        if agent.infection_time >= agent.recovery_time * TICKS
            agent.infection_state = :Recovered
        end
    end
end

# Agent step function: infection spread and recovery
function agent_step!(agent, model)
    check_infection(agent, model)
    check_recovery(agent)
    update_position!(agent, model)
end


function run_simulation(model, days)
    timestamp = Int(floor(datetime2unix(Dates.now())))
    results = DataFrame(Day=Int[], Susceptible=Int[], Infected=Int[], Recovered=Int[])
    for i in 0:(TICKS * days)
        if i % TICKS == 0
            sus = count(a -> a.infection_state == :Susceptible, allagents(model))
            inf = count(a -> a.infection_state == :Infected, allagents(model))
            rec = count(a -> a.infection_state == :Recovered, allagents(model))
            push!(results, [i ÷ TICKS, sus, inf, rec])
            println("$(Dates.format(Dates.now(), "HH:MM:SS")) | $(i ÷ TICKS) | Susceptible: $sus | Infected: $inf | Recovered: $rec")

        end
        step!(model, agent_step!, 1, true)
        model.step += 1
    end
    CSV.write("SIR$(timestamp).csv", results)
end

# Example usage
file_path = "Dummy100k.csv"
model = initialize_model(file_path)
run_simulation(model, 200)