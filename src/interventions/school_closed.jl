module SchoolClosed

export handle_school_closed!, get_school_closed_details

import Main.Models
using Main.Config

function handle_school_closed!(agents::Vector{Models.Person}, step::Int)
    if !config.SCHOOL_CLOSED
        return
    end

    # Only check at the start of each day
    if step % config.TICKS != 0
        return
    end

    current_day = step ÷ config.TICKS
    active, day, duration, strength = get_school_closed_details(step)

    if current_day == day
        println("Starting school closure intervention on day $day")
        for agent in agents
            if agent.isStudent &&
               (agent.scheduleIDs[end] != config.SCHOOL_CLOSED_SCHEDULE_ID)
                # With probability "strength", the student complies with the intervention.
                if rand() < strength
                    push!(agent.scheduleIDs, config.SCHOOL_CLOSED_SCHEDULE_ID)
                end
            end
        end
    elseif current_day == day + duration
        println("Ending school closure intervention on day $(day + duration)")
        for agent in agents
            if agent.isStudent &&
               (agent.scheduleIDs[end] == config.SCHOOL_CLOSED_SCHEDULE_ID)
                pop!(agent.scheduleIDs)
            end
        end
    end
end

function get_school_closed_details(step)
    current_day = step ÷ config.TICKS
    for (closed_day, duration, strength) in zip(
        config.SCHOOL_CLOSED_DAYS,
        config.SCHOOL_CLOSED_DURATIONS,
        config.SCHOOL_CLOSED_STRENGTHS,
    )
        if current_day >= closed_day && current_day <= closed_day + duration
            return (true, closed_day, duration, strength)
        end
    end
    return (false, -1, -1, 0.0)
end

end
