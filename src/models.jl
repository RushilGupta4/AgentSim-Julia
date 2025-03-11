# src/models.jl

module Models

export Place, Person, Model


mutable struct PlaceGroup
    id::Int
    location_type::Symbol
    city::Symbol
    infectedFraction::Float32
    totalCount::Int
    infectors::Vector{Int}
    cumsum_weights::Vector{Float32}

    PlaceGroup(; id::Int, location_type::Symbol, city::Symbol) =
        new(id, location_type, city, 0.0, 0, [], [])
end


mutable struct Place
    id::Int
    location_type::Symbol
    city::Symbol
    infectedFraction::Float32
    totalCount::Int
    infectors::Vector{Int}
    cumsum_weights::Vector{Float32}
    group::Union{PlaceGroup,Nothing}

    Place(;
        id::Int,
        location_type::Symbol,
        city::Symbol,
        group::Union{PlaceGroup,Nothing},
    ) = new(id, location_type, city, 0.0, 0, [], [], group)
end

mutable struct Person
    id::Int
    infectivity::Float32
    location::Tuple{Int,Symbol,Symbol}
    scheduleIDs::Vector{Int}
    isStudent::Bool

    infection_state::Symbol
    infection_time::Int
    infected_by::Int

    houseID::Int
    schoolID::Int

    officeIDMap::Dict{Symbol,Int}
    hotelIDMap::Dict{Symbol,Int}
    travelsFor::Dict{Symbol,Int}
    travelProbabilityMap::Dict{Symbol,Float32}

    originCity::Symbol
    travelCity::Symbol
    currentCity::Symbol
    travelStartStep::Int
    isTraveller::Bool

    Person(;
        id::Int,
        infectivity::Float32,
        location::Tuple{Int,Symbol,Symbol},
        scheduleIDs::Vector{Int},
        isStudent::Bool,
        infection_state::Symbol,
        infection_time::Int,
        infected_by::Int,
        houseID::Int,
        schoolID::Int,
        officeIDMap::Dict{Symbol,Int},
        hotelIDMap::Dict{Symbol,Int},
        travelsFor::Dict{Symbol,Int},
        travelProbabilityMap::Dict{Symbol,Float32},
        originCity::Symbol,
        travelCity::Symbol,
        currentCity::Symbol,
        travelStartStep::Int,
        isTraveller::Bool,
    ) = new(
        id,
        infectivity,
        location,
        scheduleIDs,
        isStudent,
        infection_state,
        infection_time,
        infected_by,
        houseID,
        schoolID,
        officeIDMap,
        hotelIDMap,
        travelsFor,
        travelProbabilityMap,
        originCity,
        travelCity,
        currentCity,
        travelStartStep,
        isTraveller,
    )
end

end
