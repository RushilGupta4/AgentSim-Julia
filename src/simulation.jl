using CSV
using JSON
using DataFrames
using Distributions
using Dates
using StatsBase
using Base.Threads

include("models.jl")
include("config.jl")
include("tree_utils.jl")
include("interventions/interventions.jl")

using .Models
using .Config
using .TreeUtils
using .Interventions


# Initialize all agents and their respective places
function initialize(file_path::String)
    df = CSV.File(file_path) |> DataFrame
    nagents = size(df, 1)
    agents = Vector{Models.Person}(undef, nagents)

    # Places indexed by (place_id, place_type, city)
    places = Dict{Tuple{Int,Symbol,Symbol},Models.Place}()
    # Groups indexed by (group_id, :Neighbourhood, city)
    groups = Dict{Tuple{Int,Symbol,Symbol},Models.PlaceGroup}()

    @inbounds for (index, row) in enumerate(eachrow(df))
        # Basic agent info
        agentID = row.AgentID
        isStudent = row.IsStudent
        infection_state = row.Infected == 1 ? :Infected : :Susceptible
        infection_time = infection_state == :Infected ? 0 : -1

        houseID = row.HouseID
        schoolID = row.SchoolID
        city = Symbol(row.City)
        travelCity = Symbol(row.TravelCity)
        scheduleID = isStudent ? 2 : 1

        # ---- Parse JSON columns into Dict{Symbol,Int} ----
        officeIDMap =
            Dict{Symbol,Int}(Symbol(k) => v for (k, v) in pairs(JSON.parse(row.OfficeIDs)))
        hotelIDMap =
            Dict{Symbol,Int}(Symbol(k) => v for (k, v) in pairs(JSON.parse(row.HotelIDs)))
        travelProbabilityMap = Dict{Symbol,Float32}(
            Symbol(k) => v for (k, v) in pairs(JSON.parse(row.TravelProbabilities))
        )
        travelsForMap =
            Dict{Symbol,Int}(Symbol(k) => v for (k, v) in pairs(JSON.parse(row.TravelsFor)))
        hotelNbhdMap = Dict{Symbol,Int}(
            Symbol(k) => v for (k, v) in pairs(JSON.parse(row.HotelNeighbourhoodIDs))
        )

        # Construct the Person
        agents[index] = Models.Person(
            id=agentID,
            infectivity=1.0f0,
            location=(houseID, :House, city),
            scheduleIDs=[scheduleID],
            isStudent=isStudent,
            infection_state=infection_state,
            infection_time=infection_time,
            infected_by=-1,
            houseID=houseID,
            schoolID=schoolID,
            officeIDMap=officeIDMap,
            hotelIDMap=hotelIDMap,
            travelsFor=travelsForMap,
            travelProbabilityMap=travelProbabilityMap,
            originCity=city,
            travelCity=travelCity,
            currentCity=city,
            travelStartStep=-1,
            # isTraveller       = !isStudent
            isTraveller=false,
        )

        # 1) Collect basic places: House, School
        places_to_create = [(houseID, :House, city), (schoolID, :School, city)]

        # 2) Offices from the officeIDMap
        for (offCity, offID) in officeIDMap
            if offID != 0
                push!(places_to_create, (offID, :Office, offCity))
            end
        end

        # 3) Hotels from the hotelIDMap
        for (hotCity, hotID) in hotelIDMap
            if hotID != 0
                push!(places_to_create, (hotID, :Hotel, hotCity))
            end
        end

        # Now create these places if needed
        for (p_id, p_type, p_city) in places_to_create
            if p_id == 0
                println(p_id, row)
                continue
            end

            place_key = (p_id, p_type, p_city)
            if !haskey(places, place_key)
                # Possibly assign group for House or Hotel
                local_group = nothing
                if config.ALPHA > 0.0f0
                    if p_type == :House
                        # House neighborhood (if you store it in the CSV or if row has HouseNeighbourhoodID)
                        house_nbhd_id = get(row, :HouseNeighbourhoodID, 0)
                        if house_nbhd_id != 0
                            group_key = (house_nbhd_id, :Neighbourhood, p_city)
                            if !haskey(groups, group_key)
                                groups[group_key] = Models.PlaceGroup(
                                    id=house_nbhd_id,
                                    location_type=:Neighbourhood,
                                    city=p_city,
                                )
                            end
                            local_group = groups[group_key]
                        end

                    elseif p_type == :Hotel
                        # Use the `hotelNbhdMap` to look up the correct neighborhood ID
                        hotel_nbhd_id = get(hotelNbhdMap, p_city, 0)
                        if hotel_nbhd_id != 0
                            group_key = (hotel_nbhd_id, :Neighbourhood, p_city)
                            if !haskey(groups, group_key)
                                groups[group_key] = Models.PlaceGroup(
                                    id=hotel_nbhd_id,
                                    location_type=:Neighbourhood,
                                    city=p_city,
                                )
                            end
                            local_group = groups[group_key]
                        end
                    end
                end

                # Finally, create the Place
                places[place_key] = Models.Place(
                    id=p_id,
                    location_type=p_type,
                    city=p_city,
                    group=local_group,
                )
            end
        end
    end

    return nagents, agents, places, groups
end


function initialize_schedules()
    schedules = Dict(
        1 => Dict(0 => :House, 1 => :Office, 2 => :Office, 3 => :House), # Employee
        2 => Dict(0 => :House, 1 => :School, 2 => :School, 3 => :House), # Student
        3 => Dict(0 => :Hotel, 1 => :Office, 2 => :Office, 3 => :Hotel), # Traveller
        config.SCHOOL_CLOSED_SCHEDULE_ID =>
            Dict(0 => :House, 1 => :House, 2 => :House, 3 => :House),  # School closed (for students)
        config.OFFICE_CLOSED_SCHEDULE_ID =>
            Dict(0 => :House, 1 => :House, 2 => :House, 3 => :House),   # Office closed (for non-students)
    )
    return schedules
end


@inline function get_location_tuple(agent::Models.Person, location::Symbol)
    if location == :House
        return (agent.houseID, :House, agent.currentCity)
    elseif location == :Office
        return (agent.officeIDMap[agent.currentCity], :Office, agent.currentCity)
    elseif location == :School
        return (agent.schoolID, :School, agent.currentCity)
    elseif location == :Hotel
        return (agent.hotelIDMap[agent.currentCity], :Hotel, agent.currentCity)
    else
        @error "Invalid location specified for agent $(agent.id) with position $(agent.pos)"
        throw(ArgumentError("Invalid location specified: $(agent.pos)"))
    end
end


function update_locations!(agents, places, groups, schedules, time_of_day, step)
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

    @inbounds for i in eachindex(agents)
        agent = agents[i]
        # Check for travel
        if agent.isTraveller && time_of_day == 0
            travelProbability = agent.travelProbabilityMap[agent.travelCity]
            if travelProbability > 0.0f0
                if agent.originCity == agent.currentCity
                    # Agent is not travelling right now, and it is the start of the day
                    if rand() < travelProbability
                        agent.currentCity = agent.travelCity
                        agent.travelStartStep = step
                        push!(agent.scheduleIDs, 3)
                    end

                else
                    # Agent is travelling right now
                    if step >=
                       agent.travelStartStep +
                       agent.travelsFor[agent.travelCity] * config.TICKS
                        agent.currentCity = agent.originCity
                        pop!(agent.scheduleIDs)
                    end
                end
            end
        end

        agent_schedule_ID = agent.scheduleIDs[end]
        current_schedule = schedules[agent_schedule_ID]
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
function simulation_step!(
    agents::Vector{Models.Person},
    places::Dict{Tuple{Int,Symbol,Symbol},Models.Place},
    step::Int,
)
    Threads.@threads for i in 1:length(agents)
        agent = agents[i]
        # Check for infection
        if agent.infection_state == :Susceptible
            current_location = agent.location
            place = places[current_location]

            local p_infection = place.infectedFraction
            local g_infection = (place.group !== nothing ? place.group.infectedFraction : 0.0f0)
            local infection_rate = (1 - config.ALPHA) * p_infection + config.ALPHA * g_infection
            local infection_prob = config.BETA * infection_rate * config.DT

            if infection_rate > 0 && rand() < infection_prob
                if config.ALPHA == 0.0f0 || rand() < p_infection / infection_rate
                    local cw = place.cumsum_weights
                    local idx = searchsortedfirst(cw, rand() * cw[end])
                    idx = clamp(idx, 1, length(cw))
                    agent.infected_by = place.infectors[idx]
                else
                    local cw = place.group.cumsum_weights
                    local idx = searchsortedfirst(cw, rand() * cw[end])
                    idx = clamp(idx, 1, length(place.group.cumsum_weights))
                    agent.infected_by = place.group.infectors[idx]
                end

                agent.infection_state = :Infected
                agent.infection_time = step
            end

            # Check for recovery
        elseif agent.infection_state == :Infected
            if rand() < config.GAMMA * config.DT
                agent.infection_state = :Recovered
            end
        end
    end
end


function count_stats(nagents, agents, cities::Set{Symbol}, step::Int)
    counts = Dict{String,Int}()
    counts["Day"] = step ÷ config.TICKS
    for city in cities
        counts["Students - Susceptible - $city"] = 0
        counts["Students - Infected - $city"] = 0
        counts["Students - Recovered - $city"] = 0
        counts["Adults - Susceptible - $city"] = 0
        counts["Adults - Infected - $city"] = 0
        counts["Adults - Recovered - $city"] = 0
    end
    local total = 0
    local state_map = Dict(
        :Susceptible => "Susceptible",
        :Infected => "Infected",
        :Recovered => "Recovered"
    )

    @inbounds for agent in agents
        city = agent.originCity
        for (state, state_str) in state_map
            if agent.infection_state == state
                if agent.isStudent
                    counts["Students - $state_str - $city"] += 1
                else
                    counts["Adults - $state_str - $city"] += 1
                end
            end
        end
        total += 1
    end
    @assert total == nagents
    return counts
end

# Main simulation loop
function run_simulation()
    schedules = initialize_schedules()
    nagents, agents, places, groups = initialize(config.INPUTFILE)

    cities = Set{Symbol}()
    for agent in agents
        push!(cities, agent.currentCity)
    end
    columns = ["Day"]
    for city in cities
        push!(columns, "Students - Susceptible - $city")
        push!(columns, "Students - Infected - $city")
        push!(columns, "Students - Recovered - $city")
        push!(columns, "Adults - Susceptible - $city")
        push!(columns, "Adults - Infected - $city")
        push!(columns, "Adults - Recovered - $city")
    end
    # results = DataFrame(columns)
    results = DataFrame()
    for col in columns
        results[!, col] = []
    end

    for step = 0:(config.TICKS*config.DAYS)
        Interventions.interventions!(agents, step)
        update_locations!(agents, places, groups, schedules, step % config.TICKS, step)

        if step % config.TICKS == 0  # Daily summary
            row = count_stats(nagents, agents, cities, step)
            push!(results, row)

            total_sus = 0
            total_inf = 0
            total_rec = 0

            for city in cities
                total_sus += row["Students - Susceptible - $city"] + row["Adults - Susceptible - $city"]
                total_inf += row["Students - Infected - $city"] + row["Adults - Infected - $city"]
                total_rec += row["Students - Recovered - $city"] + row["Adults - Recovered - $city"]
            end
            println("$(Dates.format(Dates.now(), "HH:MM:SS.sss")) | Day $(step ÷ config.TICKS) | Susceptible: $total_sus | Infected: $total_inf | Recovered: $total_rec",)
        end

        simulation_step!(agents, places, step)
    end

    dir = config.OUTPUTDIR
    isdir(dir) || mkpath(dir)
    csvFile = "$dir/SIR$(config.TIMESTAMP).csv"
    CSV.write(csvFile, results)

    # Dump Config
    config_dict = Dict(key => getfield(config, key) for key ∈ propertynames(config))
    configFile = "$dir/config_$(config.TIMESTAMP).json"
    open(configFile, "w") do f
        JSON.print(f, config_dict, 2)  # 4-space indentation for readability
    end
end


if abspath(PROGRAM_FILE) == @__FILE__
    run_simulation()
end
