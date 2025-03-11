import json
import pandas as pd
import numpy as np
import random

# -------------- PARAMETERS --------------
# Example configuration for N cities
# CITIES = ["CityA", "CityB", "CityC"]  # Extend or reduce as needed
CITIES = ["Mumbai", "Nashik", "Pune"]  # Extend or reduce as needed
CITIES = ["Mumbai"]  # Extend or reduce as needed

# For each city in CITIES, specify total population and initial infected count
# (Ensure lengths match the number of cities)
TOTAL_POPULATION = np.array([2100, 220, 700]) * 100
TOTAL_POPULATION = np.array([200]) * 1000
INITIAL_INFECTED = [100, 0, 0]
INITIAL_INFECTED = [200]

HOUSEHOLD_SIZE = 4
OFFICE_SIZE = 100
SCHOOL_SIZE = 150
HOTEL_SIZE = 100
NEIGHBOURHOOD_SIZE = 1000  # 100 houses per neighborhood
ESSENTIAL_WORKSPACE_PORTION = 0.1
SINGLE_COMPARTMENT = False

INFECTIVITIES = ["Normal"]  # You can keep multiple if desired, e.g. ["Normal", "High"]

SAVE_ENTITIES = False

# Geographic bounding box for random lat/long
MIN_LATLONG = 0
MAX_LATLONG = 90

TRAVEL_MAP = {
    "Mumbai": {"Nashik": 0.433556574, "Pune": 0.56644342615},
    "Nashik": {"Mumbai": 0.5, "Pune": 0.5},
    "Pune": {"Mumbai": 0.7525, "Nashik": 0.2475},
}
TRAVEL_MAP = {
    "Mumbai": {"Nashik": 0.95, "Pune": 0.05},
    "Nashik": {"Mumbai": 0.1, "Pune": 0.1},
    "Pune": {"Mumbai": 0.05, "Nashik": 0.95},
}
TRAVEL_PROB_MAP = {
    "Mumbai": 0.0067547619,
    "Nashik": 0.00909090909,
    "Pune": 0.0114285714,
}

# -------------- FUNCTIONS --------------


def generate_population(city_name, city_id, total_population):
    """
    Generates a population DataFrame for the given city:
      - AgentID (unique per city)
      - Age
      - IsWorker
      - IsStudent
      - Compliance
      - Infectivity
    """
    agent_ids = city_id * total_population + np.arange(1, total_population + 1)

    # Ages
    if SINGLE_COMPARTMENT:
        ages = np.random.randint(20, 60, size=total_population)
    else:
        ages = np.random.randint(5, 60, size=total_population)

    # Infectivity types
    infectivies = np.random.choice(INFECTIVITIES, size=total_population)

    # Classify by age
    workers = ages >= 18
    students = ages < 18

    # Random compliance
    compliance = np.random.uniform(0, 1, size=total_population)

    df = pd.DataFrame(
        {
            "City": city_name,
            "AgentID": agent_ids,
            "Age": ages,
            "IsWorker": workers,
            "IsStudent": students,
            "Compliance": compliance,
            "Infectivity": infectivies,
        }
    )
    return df


def generate_entities(population, current_entity_count):
    """
    Generates houses, hotels, offices, schools, and neighborhoods
    for the given city's population. Returns lists/dicts describing
    these entities, along with updated counts so IDs don't overlap across cities.
    """
    total_population = len(population)
    total_students = population["IsStudent"].sum()
    total_workers = population["IsWorker"].sum()

    # Calculate how many of each place are needed
    total_houses = total_population // HOUSEHOLD_SIZE
    total_hotels = total_population // HOTEL_SIZE
    total_offices = total_workers // OFFICE_SIZE
    total_schools = total_students // SCHOOL_SIZE
    # Simplify to at least 1 neighborhood
    total_neighbourhoods = max(1, total_houses // NEIGHBOURHOOD_SIZE)

    if SINGLE_COMPARTMENT:
        # If single compartment, all "households" are basically one big container
        total_houses = 1
        total_hotels = 1
        total_offices = 1
        total_schools = 1
        total_neighbourhoods = 1

    # ----- Generate Houses -----
    houses_ids = np.arange(1, total_houses + 1) + current_entity_count["houses"]
    houses = [
        {
            "HouseID": int(h_id),
            "Latitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
            "Longitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
        }
        for h_id in houses_ids
    ]

    # ----- Generate Hotels -----
    hotels_ids = np.arange(1, total_hotels + 1) + current_entity_count["hotels"]
    hotels = [
        {
            "HotelID": int(h_id),
            "Latitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
            "Longitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
        }
        for h_id in hotels_ids
    ]

    # ----- Generate Offices -----
    offices_ids = np.arange(1, total_offices + 1) + current_entity_count["offices"]
    offices = [
        {
            "OfficeID": int(o_id),
            "isEssential": (
                1 if np.random.uniform() < ESSENTIAL_WORKSPACE_PORTION else 0
            ),
        }
        for o_id in offices_ids
    ]

    # ----- Generate Schools -----
    schools_ids = np.arange(1, total_schools + 1) + current_entity_count["schools"]
    schools = [int(s_id) for s_id in schools_ids]

    # ----- Generate Neighborhoods -----
    # At least one neighborhood
    neighbourhoods_ids = (
        np.arange(1, total_neighbourhoods + 1) + current_entity_count["neighbourhoods"]
    )

    n_per_side = int(total_neighbourhoods**0.5) or 1
    n_per_side = max(1, n_per_side)  # Avoid zero division

    latlong_range = MAX_LATLONG - MIN_LATLONG
    neighbourhoods = []
    for i, n_id in enumerate(neighbourhoods_ids):
        # Some arrangement on a grid for lat/long
        # If n_per_side == 1, everything is at (0,0).
        if n_per_side > 1:
            lat_step = (latlong_range / (n_per_side - 1)) * (i % n_per_side)
            lon_step = (latlong_range / (n_per_side - 1)) * (i // n_per_side)
        else:
            lat_step, lon_step = (latlong_range / 2.0, latlong_range / 2.0)
        neighbourhoods.append(
            {
                "NeighbourhoodID": int(n_id),
                "Latitude": lat_step,
                "Longitude": lon_step,
            }
        )

    # Assign each house to its nearest neighborhood
    for i, house in enumerate(houses):
        # (Optional) print progress if many houses
        # if i % 10_000 == 0:
        #     print(f"Processing house {i}/{total_houses}")

        house["NeighbourhoodID"] = random.choices(
            [n["NeighbourhoodID"] for n in neighbourhoods],
            weights=[
                1.0
                / (
                    (house["Latitude"] - n["Latitude"]) ** 2
                    + (house["Longitude"] - n["Longitude"]) ** 2
                    + 1e-6  # Add small term to avoid divide-by-zero
                )
                for n in neighbourhoods
            ],
        )[0]

    # Assign each hotel to its nearest neighborhood
    for i, hotel in enumerate(hotels):
        # if i % 10_000 == 0:
        #     print(f"Processing hotel {i}/{total_hotels}")

        hotel["NeighbourhoodID"] = random.choices(
            [n["NeighbourhoodID"] for n in neighbourhoods],
            weights=[
                1.0
                / (
                    (hotel["Latitude"] - n["Latitude"]) ** 2
                    + (hotel["Longitude"] - n["Longitude"]) ** 2
                    + 1e-6
                )
                for n in neighbourhoods
            ],
        )[0]

    return houses, hotels, offices, schools, neighbourhoods


def assign_entities_to_city(population, city_name, cities, entities):
    """
    For each agent in 'population' (which belongs to city_name),
    assign a House (and HouseNeighbourhood) from its own city.
    Then, for *every* city in the entire cities list, assign:
       - OfficeID (if IsWorker)
       - HotelID, HotelNeighbourhoodID
       - TravelProbability, TravelsFor
       - IsEssentialWorker
    as dictionaries keyed by city.
    """
    city_entities = entities[city_name]

    # Assign each agent a local house from city_name
    chosen_houses = [
        random.choice(city_entities["houses"]) for _ in range(len(population))
    ]
    population["HouseID"] = [h["HouseID"] for h in chosen_houses]
    population["HouseNeighbourhoodID"] = [h["NeighbourhoodID"] for h in chosen_houses]

    chosen_schools = [
        random.choice(city_entities["schools"]) for _ in range(len(population))
    ]
    population["SchoolID"] = [s for s in chosen_schools]

    # Create dictionaries for cross-city assignment
    office_dicts = []
    hotel_dicts = []
    hotel_nbhd_dicts = []
    travel_prob_dicts = []
    travels_for_dicts = []
    essential_dicts = []

    for i, row in population.iterrows():
        is_worker = row["IsWorker"]

        # For each city in the entire list:
        #   Assign an office if worker, a random hotel, etc.
        off_map = {}
        hot_map = {}
        hot_nbhd_map = {}
        travel_prob_map = {}
        travels_for_map = {}
        essential_map = {}

        for c in cities:
            # Choose a random office if this agent is a worker; else 0
            if is_worker:
                chosen_office = (
                    random.choice(entities[c]["offices"])
                    if entities[c]["offices"]
                    else {"OfficeID": 0, "isEssential": 0}
                )
                off_map[c] = chosen_office["OfficeID"]
                essential_map[c] = chosen_office["isEssential"]
            else:
                off_map[c] = 0
                essential_map[c] = 0

            # Always choose a random hotel for each city
            chosen_hotel = (
                random.choice(entities[c]["hotels"])
                if entities[c]["hotels"]
                else {"HotelID": 0, "NeighbourhoodID": 0}
            )
            hot_map[c] = chosen_hotel["HotelID"]
            hot_nbhd_map[c] = chosen_hotel["NeighbourhoodID"]

            # Travel probability and travel duration (arbitrary example)
            travel_prob_map[c] = TRAVEL_PROB_MAP[c] if is_worker else 0
            travels_for_map[c] = 7  # e.g., 7 days

        office_dicts.append(json.dumps(off_map))
        hotel_dicts.append(json.dumps(hot_map))
        hotel_nbhd_dicts.append(json.dumps(hot_nbhd_map))
        travel_prob_dicts.append(json.dumps(travel_prob_map))
        travels_for_dicts.append(json.dumps(travels_for_map))
        essential_dicts.append(json.dumps(essential_map))

    # Store these dictionaries as columns in the population DataFrame
    population["OfficeIDs"] = office_dicts
    population["HotelIDs"] = hotel_dicts
    population["HotelNeighbourhoodIDs"] = hotel_nbhd_dicts
    population["TravelProbabilities"] = travel_prob_dicts
    population["TravelsFor"] = travels_for_dicts
    population["IsEssentialWorkerMap"] = essential_dicts


def main():
    # -- Prepare to store data
    populations = {}
    entities = {}
    all_data = []

    # Keep track of cumulative entity IDs across cities so they don't overlap
    current_entity_count = {
        "houses": 0,
        "hotels": 0,
        "offices": 0,
        "schools": 0,
        "neighbourhoods": 0,
    }

    # -- Generate population and entities for each city
    for city_id, city_name in enumerate(CITIES):
        pop_size = TOTAL_POPULATION[city_id]
        population_df = generate_population(city_name, city_id, pop_size)
        populations[city_name] = population_df

        # Generate the entities (houses, offices, etc.)
        houses, hotels, offices, schools, neighbourhoods = generate_entities(
            population_df, current_entity_count
        )
        entities[city_name] = {
            "houses": houses,
            "hotels": hotels,
            "offices": offices,
            "schools": schools,
            "neighbourhoods": neighbourhoods,
        }

        # Update entity counts
        current_entity_count["houses"] += len(houses)
        current_entity_count["hotels"] += len(hotels)
        current_entity_count["offices"] += len(offices)
        current_entity_count["schools"] += len(schools)
        current_entity_count["neighbourhoods"] += len(neighbourhoods)

    # -- Assign entities across cities (including cross-city travel)
    for city_id, city_name in enumerate(CITIES):
        population = populations[city_name]
        assign_entities_to_city(population, city_name, CITIES, entities)

        travel_options = TRAVEL_MAP.get(city_name, {})
        assert travel_options

        travel_cities = list(travel_options.keys())
        travel_probs = list(travel_options.values())
        total_prob = sum(travel_probs)

        travel_probs = [p / total_prob for p in travel_probs]
        population["TravelCity"] = np.random.choice(
            travel_cities, size=len(population), p=travel_probs
        )

        # Mark infected individuals for this city
        infected_count = INITIAL_INFECTED[city_id]
        population["Infected"] = [
            1 if i < infected_count else 0 for i in range(len(population))
        ]
        all_data.append(population)

    # -- Combine all city data
    df = pd.concat(all_data, ignore_index=True)

    # -- Construct file path name
    #    For example: Ncities_3_300k_200k_100k.csv
    pop_strs = [f"{int(p/1000)}k" for p in TOTAL_POPULATION]
    file_path = f"Ncities_{len(CITIES)}_" + "_".join(pop_strs)

    df.to_csv(f"{file_path}.csv", index=False)
    print(f"Data saved to {file_path}.csv")

    # Optionally save entities if desired
    if SAVE_ENTITIES:
        with open(f"{file_path}.json", "w") as f:
            json.dump(entities, f, indent=4)
        print(f"Entities saved to {file_path}.json")


if __name__ == "__main__":
    main()
