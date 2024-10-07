# src/models.jl

module Models

export Place, Person, Model


mutable struct PlaceGroup
    id::Int
    location_type::Symbol
    infectedFraction::Float32
    totalCount::Int 
    infectors::Vector{Int}
    cumsum_weights::Vector{Float32}

    PlaceGroup(;id::Int, location_type::Symbol) = new(id, location_type, 0.0, 0, [], [])
end


mutable struct Place
    id::Int
    location_type::Symbol
    infectedFraction::Float32
    totalCount::Int
    infectors::Vector{Int}
    cumsum_weights::Vector{Float32}
    group::Union{PlaceGroup, Nothing}

    Place(;id::Int, location_type::Symbol, group::Union{PlaceGroup, Nothing}) = new(id, location_type, 0.0, 0, [], [], group)
end

mutable struct Person
    id::Int
    infectivity::Float32
    houseID::Int
    officeID::Int
    schoolID::Int
    infection_state::Symbol
    infection_time::Int
    infected_by::Int
    location::Tuple{Int, Symbol}
    scheduleIDs::Vector{Int}

    Person(;
    id::Int, 
    infectivity::Float32,
    houseID::Int, 
    officeID::Int, 
    schoolID::Int, 
    infection_state::Symbol, 
    infection_time::Int, 
    infected_by::Int,
    location::Tuple{Int, Symbol}, 
    scheduleIDs::Vector{Int}
    ) = new(id, infectivity, houseID, officeID, schoolID, infection_state, infection_time, infected_by, location, scheduleIDs)
end

end
