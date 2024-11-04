# interventions.jl
module Interventions

export prune_infection!

using Dates
using Main.TreeUtils
import Main.Models
import Main.Config
using JSON
using DataFrames
using CSV

function prune_infection!(agents::Vector{Models.Person}, step::Int)
    if !Config.PRUNE
        return
    end

    current_day = step ÷ Config.TICKS

    if !(current_day == Config.PRUNEDAY && step % Config.TICKS == 0)
        return
    end

    tracker = DataFrame(AgentID = Int[], InfectedBy = Int[], InfectionTime = Int[], CurrentStatus = Symbol[])
    for agent in agents
        if agent.infection_state != :Susceptible
            push!(tracker, [agent.id, agent.infected_by, agent.infection_time, agent.infection_state])
        end
    end
    
    isdir(Config.OUTPUTDIR) || mkpath(Config.OUTPUTDIR)
    csvFile = "$(Config.OUTPUTDIR)/Agent$(Config.TIMESTAMP).csv"
    CSV.write(csvFile, tracker)

    # Collect all infected or recovered agents
    people = [agent for agent in agents if agent.infection_state != :Susceptible]
    leaf_nodes = build_infection_tree(people)
    predecessors = Set{TreeNode{Models.Person}}()

    for leaf_node in leaf_nodes
        predecessor = get_predecessor(leaf_node, Config.GENERATION_LOOKBACK)
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
        if rand() < Config.REMOVE_PROBABILITY
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
        "day" => Config.PRUNEDAY,
        "totalSize" => total_size,
        "removedSize" => removed_size,
        "removedPercentage" => removed_percentage,
        "removedIDs" => [person.id for person in to_remove],
        "parentNodes" => [node.value.id for node in filtered_predecessors]
    )

    dir = Config.OUTPUTDIR
    isdir(dir) || mkpath(dir)
    json_file = "$dir/Prune$(Config.TIMESTAMP).json"

    open(json_file, "w") do io
        write(io, JSON.json(prune_details))
    end

    # Reset infection state of the removed agents
    for agent in to_remove
        agent.infection_state = :Susceptible
        agent.infection_time = -1
        agent.infected_by = -1
    end

    println("INFECTION PRUNING | DAY: $(Config.PRUNEDAY) | TOTAL: $(length(people)) | REMOVED: $(length(to_remove))")
end

end