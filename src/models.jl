# src/models.jl

module Models

export Place, Person, Model

mutable struct Place
    id::Int
    location_type::Symbol
    infectedCount::Int
    totalCount::Int

    Place(id::Int, location_type::Symbol) = new(id, location_type, 0, 0)
end

mutable struct Person
    id::Int
    houseID::Int
    officeID::Int
    schoolID::Int
    infection_state::Symbol
    infection_time::Int  # Ticks since infection
    recovery_time::Float64
    location::Tuple{Int, Symbol}
    scheduleIDs::Vector{Int}
end

end
