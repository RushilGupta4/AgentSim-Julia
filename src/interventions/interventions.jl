# interventions.jl
module Interventions

include("./pruning.jl")
using .Pruning
export prune_infection!


include("./lockdown.jl")
using .Lockdown
export handle_lockdown!

end