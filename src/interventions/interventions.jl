module Interventions

include("./pruning.jl")
include("./school_closed.jl")
include("./office_closed.jl")

import .Pruning
import .SchoolClosed
import .OfficeClosed

export interventions!, SchoolClosed, OfficeClosed

function interventions!(agents, step)
    # Pruning.prune_infection!(agents, step)
    SchoolClosed.handle_school_closed!(agents, step)
    OfficeClosed.handle_office_closed!(agents, step)
end

end
