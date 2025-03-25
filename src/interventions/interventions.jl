module Interventions

include("./policy_based_interventions.jl")

import .PolicyBasedInterventions

export interventions!

"""
    interventions!(agents, step)

Calls the policy-based interventions check at every simulation step.
Note: The policy-based check only updates lockdowns at the beginning of every week.
"""
function interventions!(agents, step)
    PolicyBasedInterventions.policy_interventions!(agents, step)
end

end  # module Interventions