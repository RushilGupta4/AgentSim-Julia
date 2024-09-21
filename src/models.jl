# src/models.jl

module Models

export Place, Person, Model

mutable struct Place
    id::Int
    location_type::Symbol
    totalCount::Int
    infectedCount::Int
    infectors::Vector{Tuple{Int, Float32}}

    Place(id::Int, location_type::Symbol) = new(id, location_type, 0, 0, 0, 0, [])
end

mutable struct Person
    id::Int
    houseID::Int
    officeID::Int
    schoolID::Int
    infection_state::Symbol
    infection_time::Int
    infected_by::Int
    recovery_time::Float64
    location::Tuple{Int, Symbol}
    scheduleIDs::Vector{Int}

    Person(;
    id::Int, 
    houseID::Int, 
    officeID::Int, 
    schoolID::Int, 
    infection_state::Symbol, 
    infection_time::Int, 
    infected_by::Int,
    recovery_time::Float64, 
    location::Tuple{Int, Symbol}, 
    scheduleIDs::Vector{Int}
    ) = new(id, houseID, officeID, schoolID, infection_state, infection_time, infected_by, recovery_time, location, scheduleIDs)
end

end
