using CSV
using DataFrames
using Distributions
using Dates
using Base.Threads

include("models.jl")
include("config.jl")
import .Models
import .Config


# Initialize all agents and their respective places
function initialize(file_path::String)
    df = CSV.File(file_path) |> DataFrame
    nagents = nrow(df)
    agents = Vector{Models.Person}(undef, nagents)
    places = Dict{Tuple{Int, Symbol}, Models.Place}()

    @inbounds for (index, row) in enumerate(eachrow(df))
        agentID = row.AgentID
        infection_state = row.Infected == 1 ? :Infected : :Susceptible
        houseID = row.HouseID
        officeID = row.OfficeID
        schoolID = row.SchoolID
        isStudent = row.IsStudent

        infection_time = infection_state == :Infected ? 0 : -1
        recovery_time = infection_state == :Infected ? rand(Exponential(1 / Config.GAMMA)) : 0
        scheduleID = isStudent ? 2 : 1 

        @assert houseID != 0
        @assert (isStudent && schoolID > 0) || (!isStudent && officeID > 0)

        # Create and add Person
        @inbounds agents[index] = Models.Person(
            agentID,
            houseID,
            officeID,
            schoolID,
            infection_state,
            infection_time,
            recovery_time,
            (houseID, :House), 
            [scheduleID]
        )
        
        # Check and add places if they do not exist
        for (place_id, place_type) in [(houseID, :House), (officeID, :Office), (schoolID, :School)]
            place_key = (place_id, place_type)
            if place_id != 0 && !haskey(places, place_key)
                places[place_key] = Models.Place(place_id, place_type)
            end
        end
    end

    return nagents, agents, places
end

function initialize_schedules()
    schedules = Dict(
        1 => Dict(0 => :House, 1 => :Office, 2 => :Office, 3 => :House),
        2 => Dict(0 => :House, 1 => :School, 2 => :School, 3 => :House)
    )
    return schedules
end


function get_location_tuple(agent::Models.Person, location::Symbol)
    if location == :House
        return (agent.houseID, :House)
    elseif location == :Office
        return (agent.officeID, :Office)
    elseif location == :School
        return (agent.schoolID, :School)
    else
        @error "Invalid location specified for agent $(agent.id) with position $(agent.pos)"
        throw(ArgumentError("Invalid location specified: $(agent.pos)"))
    end
end


function update_locations!(agents, places, schedules, time_of_day)
    for place in values(places)
        place.totalCount = 0
        place.infectedCount = 0
    end

    for agent in agents
        current_schedule = schedules[agent.scheduleIDs[end]]
        new_location = get_location_tuple(agent, current_schedule[time_of_day])
        agent.location = new_location

        places[new_location].totalCount += 1
        if agent.infection_state == :Infected
            places[new_location].infectedCount += 1
        end
    end

end

# Simulation step logic
function simulation_step!(agents::Vector{Models.Person}, places::Dict{Tuple{Int, Symbol}, Models.Place}, step::Int)
    for agent in agents
        # Check for infection
        if agent.infection_state == :Susceptible
            current_location = agent.location
            place = places[current_location]
            infected_fraction = place.infectedCount / place.totalCount
            infection_prob = Config.BETA * infected_fraction * Config.DT
            
            if rand() < infection_prob
                agent.infection_state = :Infected
                agent.infection_time = step
                agent.recovery_time = rand(Exponential(1 / Config.GAMMA))
            end
        
        # Check for recovery
        elseif agent.infection_state == :Infected
            if rand() < Config.GAMMA * Config.DT
            # if step >= agent.infection_time + agent.recovery_time * Config.TICKS
                agent.infection_state = :Recovered
            end
        end
    end
end

# Main simulation loop
function run_simulation()
    timestamp = Int(floor(datetime2unix(Dates.now()) * 1e3))
    schedules = initialize_schedules()
    nagents, agents, places = initialize(Config.INPUTFILE)
    results = DataFrame(Day = Int[], Susceptible = Int[], Infected = Int[], Recovered = Int[])

    for step in 0:(Config.TICKS * Config.DAYS)
        if step % Config.TICKS == 0  # Daily summary
            sus = 0; inf = 0; rec = 0
            for agent in agents
                if agent.infection_state == :Susceptible
                    sus += 1
                elseif agent.infection_state == :Infected
                    inf += 1
                elseif agent.infection_state == :Recovered
                    rec += 1
                else
                    @error "Invalid infection state for agent $(agent.id)"
                    throw(ArgumentError("Invalid infection state for agent $(agent.id)"))
                end
            end
            push!(results, [step ÷ Config.TICKS, sus, inf, rec])
            println("$(Dates.format(Dates.now(), "HH:MM:SS.sss")) | Day $(step ÷ Config.TICKS) | Susceptible: $sus | Infected: $inf | Recovered: $rec")

            @assert sus + inf + rec == nagents
        end

        time_of_day = step % Config.TICKS
        update_locations!(agents, places, schedules, time_of_day)
        simulation_step!(agents, places, step)
    end

    dir = Config.OUTPUTDIR
    isdir(dir) || mkpath(dir)
    csvFile = "$dir/SIR$timestamp.csv"
    CSV.write(csvFile, results)
end


run_simulation()

