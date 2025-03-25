module PolicyBasedInterventions

using JSON
using Dates
import Main.Config
import Main.Models

# Load the policy mapping from the JSON file specified in the config.
const POLICY = JSON.parse(read(Config.config.POLICY_FILE, String))

# Global mutable state for the currently active lockdown strengths.
# These hold the current office and school lockdown strengths, respectively.
const current_office_lockdown_strength = Ref(0.0)
const current_school_lockdown_strength = Ref(0.0)

"""
    policy_interventions!(agents, step)

At the beginning of every week (i.e. when step % (7 * config.TICKS) == 0), compute the overall
susceptible and infected fractions, discretize them, and look up the new intervention strengths.
If the strengths differ from those currently applied, remove any active lockdowns and apply the new ones.
"""
function policy_interventions!(agents::Vector{Models.Person}, step::Int)
    # Check only at the beginning of each week.
    if step % (7 * Config.config.TICKS) != 0
        return
    end

    total_agents = length(agents)
    susceptible_count = count(a -> a.infection_state == :Susceptible, agents)
    infected_count = count(a -> a.infection_state == :Infected, agents)
    S_frac = susceptible_count / total_agents
    I_frac = infected_count / total_agents

    # Discretize S and I using floor rounding.
    disc_S = floor(S_frac / Config.config.S_DISCRETIZATION) * Config.config.S_DISCRETIZATION
    disc_I = floor(I_frac / Config.config.I_DISCRETIZATION) * Config.config.I_DISCRETIZATION

    # Compute number of decimal places for discretization.
    S_places = length(digits(Int(1/Config.config.S_DISCRETIZATION)))
    I_places = length(digits(Int(1/Config.config.I_DISCRETIZATION)))

    disc_S = round(disc_S, digits=S_places)
    disc_I = round(disc_I, digits=I_places)


    # Construct a key string; for example "0.99,0.02"
    key = "$(disc_S),$(disc_I)"
    if !haskey(POLICY, key)
        error("Policy key not found for discretized values: $key")
    end

    new_policy = POLICY[key]
    new_office_strength = new_policy[1]
    new_school_strength = new_policy[2]

    # If the new lockdown strengths differ from what is currently active, update them.
    if new_office_strength != current_office_lockdown_strength[] ||
       new_school_strength != current_school_lockdown_strength[]
       
        println("Policy change at step $step: updating lockdown strengths from (" *
                "$(current_office_lockdown_strength[]), $(current_school_lockdown_strength[])) to " *
                "($new_office_strength, $new_school_strength)")
        
        # Remove any active lockdowns.
        for agent in agents
            if agent.isStudent &&
               !isempty(agent.scheduleIDs) &&
               agent.scheduleIDs[end] == Config.config.SCHOOL_CLOSED_SCHEDULE_ID
                pop!(agent.scheduleIDs)
            end
            if !agent.isStudent &&
               !isempty(agent.scheduleIDs) &&
               agent.scheduleIDs[end] == Config.config.OFFICE_CLOSED_SCHEDULE_ID
                pop!(agent.scheduleIDs)
            end
        end

        # Apply new lockdown interventions before any simulation on the current day.
        for agent in agents
            if agent.isStudent
                # With probability new_school_strength, the student complies.
                if rand() < new_school_strength
                    push!(agent.scheduleIDs, Config.config.SCHOOL_CLOSED_SCHEDULE_ID)
                end
            else
                if rand() < new_office_strength
                    push!(agent.scheduleIDs, Config.config.OFFICE_CLOSED_SCHEDULE_ID)
                end
            end
        end

        # Update the current lockdown strengths.
        current_office_lockdown_strength[] = new_office_strength
        current_school_lockdown_strength[] = new_school_strength
    end
end

end  # module PolicyBasedInterventions