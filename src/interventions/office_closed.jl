module OfficeClosed

export handle_office_closed!, get_office_closed_details

import Main.Models
using Main.Config

function handle_office_closed!(agents::Vector{Models.Person}, step::Int)
    if !config.OFFICE_CLOSED
        return
    end

    current_day = step ÷ config.TICKS
    active, day, duration, strength = get_office_closed_details(step)

    # Only check at the start of each day
    if step % config.TICKS != 0
        return
    end

    if current_day == day
        println("Starting office closure intervention on day $day")
        for agent in agents
            if !agent.isStudent &&
               (agent.scheduleIDs[end] != config.OFFICE_CLOSED_SCHEDULE_ID)
                # With probability "strength", the agent complies with the intervention.
                if rand() < strength
                    push!(agent.scheduleIDs, config.OFFICE_CLOSED_SCHEDULE_ID)
                end
            end
        end
    elseif current_day == day + duration
        println("Ending office closure intervention on day $(day + duration)")
        for agent in agents
            if !agent.isStudent &&
               (agent.scheduleIDs[end] == config.OFFICE_CLOSED_SCHEDULE_ID)
                pop!(agent.scheduleIDs)
            end
        end
    end
end

function get_office_closed_details(step)
    current_day = step ÷ config.TICKS
    for (closed_day, duration, strength) in zip(
        config.OFFICE_CLOSED_DAYS,
        config.OFFICE_CLOSED_DURATIONS,
        config.OFFICE_CLOSED_STRENGTHS,
    )
        if current_day >= closed_day && current_day <= closed_day + duration
            return (true, closed_day, duration, strength)
        end
    end
    return (false, -1, -1, 0.0)
end

end
