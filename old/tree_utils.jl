module TreeUtils

export TreeNode, build_infection_tree, get_predecessor, get_all_descendants, get_all_ancestors

import Main.Models


mutable struct TreeNode{T}
    value::T
    parent::Union{Nothing, TreeNode{T}}
    children::Vector{TreeNode{T}}
    TreeNode(value::T) where {T} = new{T}(value, nothing, Vector{TreeNode{T}}())
end

function add_child!(parent::TreeNode{T}, child::TreeNode{T}) where {T}
    if child.parent !== nothing
        throw(ArgumentError("Node $(child.value.id) already has a parent $(child.parent.value.id)"))
    else
        push!(parent.children, child)
        child.parent = parent
    end
end

function get_all_descendants(node::TreeNode{T}) where {T}
    descendants = Vector{TreeNode{T}}()
    for child in node.children
        push!(descendants, child)
        append!(descendants, get_all_descendants(child))
    end
    return descendants
end

function get_all_ancestors(node::TreeNode{T}) where {T}
    ancestors = Vector{TreeNode{T}}()
    current = node
    while current.parent !== nothing
        current = current.parent
        push!(ancestors, current)
    end
    return ancestors
end

function get_predecessor(node::TreeNode{T}, n::Int) where {T}
    current = node
    current_step = 0
    while current_step < n && current.parent !== nothing
        current = current.parent
        current_step += 1
    end
    return current
end

function build_infection_tree(agents::Vector{Models.Person})
    node_map = Dict{Int, TreeNode{Models.Person}}()

    for agent in agents
        node_map[agent.id] = TreeNode(agent)
    end

    for agent in agents
        if agent.infected_by != -1
            parent_node = node_map[agent.infected_by]
            child_node = node_map[agent.id]
            add_child!(parent_node, child_node)
        end
    end
    leaf_nodes = [node for node in values(node_map) if isempty(node.children)]
    return leaf_nodes
end

end