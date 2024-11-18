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

    PlaceGroup(;id::Int, location_type::Symbol, city::Symbol) = new(id, location_type, city, 0.0, 0, [], [])
end


mutable struct Place
    id::Int
    location_type::Symbol
    city::Symbol
    infectedFraction::Float32
    totalCount::Int
    infectors::Vector{Int}
    cumsum_weights::Vector{Float32}
    group::Union{PlaceGroup, Nothing}

    Place(;id::Int, location_type::Symbol, city::Symbol, group::Union{PlaceGroup, Nothing}) = new(id, location_type, city, 0.0, 0, [], [], group)
end

mutable struct Person
    id::Int
    infectivity::Float32
    houseID::Int
    officeID::Int
    schoolID::Int
    travelOfficeID::Int
    travelHotelID::Int
    infection_state::Symbol
    infection_time::Int
    infected_by::Int
    location::Tuple{Int, Symbol, Symbol}
    scheduleIDs::Vector{Int}
    travelsFor::Int
    originCity::Symbol
    travelCity::Symbol
    currentCity::Symbol
    travelStartStep::Int
    isTraveller::Bool

    Person(;
    id::Int, 
    infectivity::Float32,
    houseID::Int, 
    officeID::Int, 
    schoolID::Int, 
    infection_state::Symbol, 
    infection_time::Int, 
    infected_by::Int,
    location::Tuple{Int, Symbol, Symbol}, 
    scheduleIDs::Vector{Int},
    travelOfficeID::Int,
    travelHotelID::Int,
    travelsFor::Int,
    originCity::Symbol,
    travelCity::Symbol,
    currentCity::Symbol,
    travelStartStep::Int,
    isTraveller::Bool
    ) = new(id, infectivity, houseID, officeID, schoolID, travelOfficeID, travelHotelID, infection_state, infection_time, infected_by, location, scheduleIDs, travelsFor, originCity, travelCity, currentCity, travelStartStep, isTraveller)
end

end
