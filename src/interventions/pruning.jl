module Pruning

export prune_infection!

using Main.TreeUtils
import Main.Models
using Main.Config
using JSON
using DataFrames
using CSV


function generational_prune!(agents::Vector{Models.Person})
    # Collect all infected or recovered agents
    people = [agent for agent in agents if agent.infection_state != :Susceptible]
    leaf_nodes = build_infection_tree(people)
    predecessors = Set{TreeNode{Models.Person}}()

    for leaf_node in leaf_nodes
        predecessor = get_predecessor(leaf_node, config.GENERATION_LOOKBACK)
        if predecessor !== nothing
            push!(predecessors, predecessor)
        end
    end

    # Filter predecessors to remove overlapping subtrees
    filtered_predecessors = Set{TreeNode{Models.Person}}()
    for p in predecessors
        if !any(q -> q in get_all_ancestors(p), predecessors)
            push!(filtered_predecessors, p)
        end
    end

    # For each predecessor, with remove_probability, remove node and descendants
    to_remove = Set{Models.Person}()
    for predecessor in filtered_predecessors
        if rand() < config.REMOVE_PROBABILITY
            push!(to_remove, predecessor.value)
            descendants = get_all_descendants(predecessor)
            for descendant in descendants
                push!(to_remove, descendant.value)
            end
        end
    end

    # Save prune details to file
    total_size = length(people)
    removed_size = length(to_remove)
    removed_percentage = (removed_size / total_size) * 100.0

    prune_details = Dict(
        "day" => config.PRUNEDAY,
        "totalSize" => total_size,
        "removedSize" => removed_size,
        "removedPercentage" => removed_percentage,
        "removedIDs" => [person.id for person in to_remove],
        "parentNodes" => [node.value.id for node in filtered_predecessors],
    )

    return people, to_remove, prune_details
end


function random_prune!(agents::Vector{Models.Person})
    people = [agent for agent in agents if agent.infection_state != :Susceptible]
    to_remove = Set{Models.Person}()

    for person in people
        if rand() < config.REMOVE_PROBABILITY
            push!(to_remove, person)
        end
    end

    prune_details = Dict(
        "day" => config.PRUNEDAY,
        "totalSize" => length(people),
        "removedSize" => length(to_remove),
        "removedPercentage" => (length(to_remove) / length(people)) * 100.0,
        "removedIDs" => [person.id for person in to_remove],
    )

    return people, to_remove, prune_details
end


function random_location_prune!(agents::Vector{Models.Person})
    people = [agent for agent in agents if agent.infection_state != :Susceptible]
    to_remove = Set{Models.Person}()
    houses_to_remove = Set{Int}()

    houses = Set{Int}()
    for person in people
        push!(houses, person.houseID)
    end

    for house in houses
        if rand() < config.REMOVE_PROBABILITY
            push!(houses_to_remove, house)
        end
    end

    for person in people
        if person.houseID in houses_to_remove
            push!(to_remove, person)
        end
    end

    prune_details = Dict(
        "day" => config.PRUNEDAY,
        "totalSize" => length(people),
        "removedSize" => length(to_remove),
        "removedPercentage" => (length(to_remove) / length(people)) * 100.0,
        "removedIDs" => [person.id for person in to_remove],
    )

    return people, to_remove, prune_details
end

function prune_infection!(agents::Vector{Models.Person}, step::Int)
    if !config.PRUNE
        return
    end

    current_day = step ÷ config.TICKS

    if !(current_day == config.PRUNEDAY && step % config.TICKS == 0)
        return
    end

    tracker = DataFrame(
        AgentID=Int[],
        InfectedBy=Int[],
        InfectionTime=Int[],
        CurrentStatus=Symbol[],
    )
    for agent in agents
        if agent.infection_state != :Susceptible
            push!(
                tracker,
                [agent.id, agent.infected_by, agent.infection_time, agent.infection_state],
            )
        end
    end

    isdir(config.OUTPUTDIR) || mkpath(config.OUTPUTDIR)
    csvFile = "$(config.OUTPUTDIR)/Agent$(config.TIMESTAMP).csv"
    CSV.write(csvFile, tracker)

    people, to_remove, prune_details = Vector{Models.Person}(), Set{Models.Person}(), Dict()
    if config.PRUNE_METHOD == "Generational"
        people, to_remove, prune_details = generational_prune!(agents)
    elseif config.PRUNE_METHOD == "Random"
        people, to_remove, prune_details = random_prune!(agents)
    elseif config.PRUNE_METHOD == "RandomLocation"
        people, to_remove, prune_details = random_location_prune!(agents)
    else
        throw(
            ArgumentError(
                "Unsupported prune method: $(config.PRUNE_METHOD). Supported methods are Generational, Random, and RandomLocation.",
            ),
        )
    end

    dir = config.OUTPUTDIR
    isdir(dir) || mkpath(dir)
    json_file = "$dir/Prune$(config.TIMESTAMP).json"

    open(json_file, "w") do io
        JSON.print(io, prune_details)
    end

    # Reset infection state of the removed agents
    for agent in to_remove
        agent.infection_state = :Susceptible
        agent.infection_time = -1
        agent.infected_by = -1
    end

    println(
        "INFECTION PRUNING | DAY: $(config.PRUNEDAY) | TOTAL: $(length(people)) | REMOVED: $(length(to_remove))",
    )
end

end
