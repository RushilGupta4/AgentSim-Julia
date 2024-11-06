using CSV
using DataFrames
using Distributions
using Dates
using StatsBase
using Base.Threads

include("models.jl")
include("config.jl")
include("tree_utils.jl")
include("interventions.jl")

using .Models
using .Config
using .TreeUtils
using .Interventions


# Initialize all agents and their respective places
function initialize(file_path::String)
    df = CSV.File(file_path) |> DataFrame
    nagents = nrow(df)
    agents = Vector{Models.Person}(undef, nagents)
    places = Dict{Tuple{Int, Symbol}, Models.Place}()
    groups = Dict{Tuple{Int, Symbol}, Models.PlaceGroup}()

    @inbounds for (index, row) in enumerate(eachrow(df))
        agentID = row.AgentID
        infection_state = row.Infected == 1 ? :Infected : :Susceptible
        houseID = row.HouseID
        officeID = row.OfficeID
        schoolID = row.SchoolID
        isStudent = row.IsStudent
        houseNeighbourhoodID = row.HouseNeighbourhoodID

        infection_time = infection_state == :Infected ? 0 : -1
        scheduleID = isStudent ? 2 : 1 

        @assert houseID != 0
        @assert (isStudent && schoolID > 0) || (!isStudent && officeID > 0)

        # Create and add Person
        @inbounds agents[index] = Models.Person(
            id=agentID,
            infectivity=Float32(1.0),
            houseID=houseID,
            officeID=officeID,
            schoolID=schoolID,
            infection_state=infection_state,
            infection_time=infection_time,
            infected_by=-1,
            location=(houseID, :House), 
            scheduleIDs=[scheduleID]
        )
        
        # Check and add places if they do not exist
        for (place_id, place_type) in [(houseID, :House), (officeID, :Office), (schoolID, :School)]
            place_key = (place_id, place_type)
            group = nothing
            if Config.ALPHA > 0.0f0
                if place_type == :House
                    group_key = (houseNeighbourhoodID, :Neighbourhood)
                    if !haskey(groups, group_key)
                        groups[group_key] = Models.PlaceGroup(id=houseNeighbourhoodID, location_type=:Neighbourhood)
                    end
                    group = groups[group_key]
                end
            end 

            if place_id != 0 && !haskey(places, place_key)
                places[place_key] = Models.Place(id=place_id, location_type=place_type, group=group)
            end
        end
    end

    return nagents, agents, places, groups
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


function update_locations!(agents, places, groups, schedules, time_of_day)
    for place in values(places)
        place.totalCount = 0
        place.infectedFraction = 0.0f0
        empty!(place.infectors)
        empty!(place.cumsum_weights)
    end

    for group in values(groups)
        group.totalCount = 0
        group.infectedFraction = 0.0f0
        empty!(group.infectors)
        empty!(group.cumsum_weights)
    end

    for agent in agents
        current_schedule = schedules[agent.scheduleIDs[end]]
        new_location = get_location_tuple(agent, current_schedule[time_of_day])
        agent.location = new_location

        place = places[new_location]
        place.totalCount += 1
        if place.group !== nothing
            place.group.totalCount += 1
        end

        if agent.infection_state == :Infected
            place.infectedFraction += agent.infectivity
            push!(place.infectors, agent.id)
            push!(place.cumsum_weights, agent.infectivity)

            if place.group !== nothing
                place.group.infectedFraction += agent.infectivity
                push!(place.group.infectors, agent.id)
                push!(place.group.cumsum_weights, agent.infectivity)
            end
        end
    end

    for place in values(places)
        if place.infectedFraction > 0.0f0
            place.infectedFraction /= place.totalCount
            place.cumsum_weights = cumsum(place.cumsum_weights)
        end
    end

   for group in values(groups)
        if group.totalCount > 0.0f0
            group.infectedFraction /= group.totalCount
            group.cumsum_weights = cumsum(group.cumsum_weights)
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

            place_infection_rate = place.infectedFraction
            group_infection_rate = place.group !== nothing ? place.group.infectedFraction : 0.0f0
            infection_rate = place_infection_rate + Config.ALPHA * group_infection_rate
            infection_prob = Config.BETA * infection_rate * Config.DT

            if rand() < infection_prob
                if Config.ALPHA == 0.0f0 || rand() < place_infection_rate / infection_rate
                    idx = searchsortedfirst(place.cumsum_weights, rand() * place.cumsum_weights[end])
                    idx = clamp(idx, 1, length(place.cumsum_weights))
                    agent.infected_by = place.infectors[idx]
                else
                    idx = searchsortedfirst(place.group.cumsum_weights, rand() * place.group.cumsum_weights[end])
                    idx = clamp(idx, 1, length(place.group.cumsum_weights))
                    agent.infected_by = place.group.infectors[idx]
                end

                agent.infection_state = :Infected
                agent.infection_time = step
            end
        
        # Check for recovery
        elseif agent.infection_state == :Infected
            if rand() < Config.GAMMA * Config.DT
                agent.infection_state = :Recovered
            end
        end
    end
end


function count_stats(nagents, agents)
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

    @assert sus + inf + rec == nagents
    return sus, inf, rec
end

# Main simulation loop
function run_simulation()
    schedules = initialize_schedules()
    nagents, agents, places, groups = initialize(Config.INPUTFILE)

    results = DataFrame(Day = Int[], Susceptible = Int[], Infected = Int[], Recovered = Int[])
    for step in 0:(Config.TICKS * Config.DAYS)
        Interventions.prune_infection!(agents, step)
        update_locations!(agents, places, groups, schedules, step % Config.TICKS)

        if step % Config.TICKS == 0  # Daily summary
            sus, inf, rec = count_stats(nagents, agents)
            push!(results, [step ÷ Config.TICKS, sus, inf, rec])
            println("$(Dates.format(Dates.now(), "HH:MM:SS.sss")) | Day $(step ÷ Config.TICKS) | Susceptible: $sus | Infected: $inf | Recovered: $rec")
        end
        
        simulation_step!(agents, places, step)
    end

    dir = Config.OUTPUTDIR
    isdir(dir) || mkpath(dir)
    csvFile = "$dir/SIR$(Config.TIMESTAMP).csv"
    CSV.write(csvFile, results)

end


if abspath(PROGRAM_FILE) == @__FILE__
    Config.parseArgs!(ARGS)
    run_simulation()
end