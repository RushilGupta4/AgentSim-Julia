module Lockdown

export handle_lockdown!

import Main.Models
import Main.Config

function handle_lockdown!(agents::Vector{Models.Person}, step::Int)
    if !Config.LOCKDOWN
        return
    end

    current_day = step ÷ Config.TICKS

    if (current_day == Config.LOCKDOWN_DAY && step % Config.TICKS == 0)
        # Start lockdown
        println("Starting lockdown")
        for agent in agents
            push!(agent.scheduleIDs, 4)
        end
        return
    end

    if (current_day == Config.LOCKDOWN_DAY + Config.LOCKDOWN_DURATION && step % Config.TICKS == 0)
        # End lockdown
        println("Ending lockdown")
        for agent in agents
            pop!(agent.scheduleIDs)
        end
        return
    end
end

end