import json
import pandas as pd
import numpy as np
import random

TOTAL_POPULATION = 5000 * 1000
INITIAL_INFECTED = [100, 0]  # Total initial infected [CityA, CityB]
HOUSEHOLD_SIZE = 4
OFFICE_SIZE = 100
SCHOOL_SIZE = 150
HOTEL_SIZE = 100
NEIGHBOURHOOD_SIZE = 1000  # 100 houses per neighborhood
ESSENTIAL_WORKSPACE_PORTION = 0.1
SINGLE_COMPARTMENT = False
TWO_CITIES = False
INFECTIVITIES = ["Normal", "High"]
INFECTIVITIES = ["Normal"]

SAVE_ENTITIES = False

# Square area for latitude and longitude
MIN_LATLONG = 0
MAX_LATLONG = 90


def generate_population(city, city_id):
    # Generate initial population with agent_id and age
    agent_ids = city_id * TOTAL_POPULATION + np.arange(1, TOTAL_POPULATION + 1)

    if SINGLE_COMPARTMENT:
        ages = np.random.randint(20, 60, size=TOTAL_POPULATION)
    else:
        ages = np.random.randint(5, 60, size=TOTAL_POPULATION)

    infectivies = np.random.choice(INFECTIVITIES, size=TOTAL_POPULATION)

    # Classify workers and students based on age
    workers = ages >= 18
    students = ages < 18

    compliance = np.random.uniform(0, 1, size=TOTAL_POPULATION)

    population = pd.DataFrame(
        {
            "City": city,
            "AgentID": agent_ids,
            "Age": ages,
            "IsWorker": workers,
            "IsStudent": students,
            "Compliance": compliance,
            "Infectivity": infectivies,
        }
    )

    return population


def assign_neighbourhood(place, neighbourhoods):
    neighbourhood = random.choices(
        [neighbourhood["NeighbourhoodID"] for neighbourhood in neighbourhoods],
        weights=[
            1
            / (
                (place["Latitude"] - neighbourhood["Latitude"]) ** 2
                + (place["Longitude"] - neighbourhood["Longitude"]) ** 2
            )
            for neighbourhood in neighbourhoods
        ],
    )[0]
    return neighbourhood


def generate_entities(population, current_entity_count):
    # Determine the number of students and workers
    total_population = len(population)
    total_students = population["IsStudent"].sum()
    total_workers = population["IsWorker"].sum()

    # Simulate houses and workplaces
    total_houses = total_population // HOUSEHOLD_SIZE
    total_hotels = total_population // HOTEL_SIZE
    total_offices = total_workers // OFFICE_SIZE
    total_schools = total_students // SCHOOL_SIZE
    total_neighbourhoods = total_houses // NEIGHBOURHOOD_SIZE
    # total_neighbourhoods = 1

    if SINGLE_COMPARTMENT:
        total_houses = 1
        total_offices = 1
        total_schools = 1
        total_hotels = 1

    # Generate entity IDs
    houses = np.arange(1, total_houses + 1) + current_entity_count["houses"]
    houses = [
        {
            "HouseID": int(house),
            "Latitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
            "Longitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
        }
        for house in houses
    ]

    hotels = np.arange(1, total_hotels + 1) + current_entity_count["hotels"]
    hotels = [
        {
            "HotelID": int(hotel),
            "Latitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
            "Longitude": float(np.random.uniform(MIN_LATLONG, MAX_LATLONG)),
        }
        for hotel in hotels
    ]

    offices = np.arange(1, total_offices + 1) + current_entity_count["offices"]
    offices = [
        {
            "OfficeID": int(office),
            "isEssential": (
                1 if np.random.uniform() < ESSENTIAL_WORKSPACE_PORTION else 0
            ),
        }
        for office in offices
    ]

    schools = np.arange(1, total_schools + 1) + current_entity_count["schools"]
    schools = [int(i) for i in schools]

    # Simulate neighbourhoods
    neighbourhoods = (
        np.arange(1, total_neighbourhoods + 1) + current_entity_count["neighbourhoods"]
    )

    n_per_side = int(total_neighbourhoods**0.5) + 1
    latlong_range = MAX_LATLONG - MIN_LATLONG
    neighbourhoods = [
        {
            "NeighbourhoodID": int(neighbourhood),
            "Latitude": (latlong_range / (n_per_side - 1)) * (i % n_per_side),
            "Longitude": (latlong_range / (n_per_side - 1)) * (i // n_per_side),
        }
        for i, neighbourhood in enumerate(neighbourhoods)
    ]

    for i, house in enumerate(houses):
        if i % 10000 == 0:
            print(f"Processing house {i}/{total_houses}")

        house["NeighbourhoodID"] = random.choices(
            [neighbourhood["NeighbourhoodID"] for neighbourhood in neighbourhoods],
            weights=[
                1
                / (
                    (house["Latitude"] - neighbourhood["Latitude"]) ** 2
                    + (house["Longitude"] - neighbourhood["Longitude"]) ** 2
                )
                for neighbourhood in neighbourhoods
            ],
        )[0]

    for i, hotel in enumerate(hotels):
        if i % 10000 == 0:
            print(f"Processing hotel {i}/{total_hotels}")

        hotel["NeighbourhoodID"] = random.choices(
            [neighbourhood["NeighbourhoodID"] for neighbourhood in neighbourhoods],
            weights=[
                1
                / (
                    (hotel["Latitude"] - neighbourhood["Latitude"]) ** 2
                    + (hotel["Longitude"] - neighbourhood["Longitude"]) ** 2
                )
                for neighbourhood in neighbourhoods
            ],
        )[0]

    return houses, hotels, offices, schools, neighbourhoods


def assign_entities(city_id, city, population, entities):
    city_entities = entities[city]
    ocity = "CityB" if city == "CityA" else "CityA"

    # Assign houses and workplaces using random.choice
    houses = [random.choice(city_entities["houses"]) for _ in range(len(population))]

    if TWO_CITIES:
        hotels = [
            random.choice(entities[ocity]["hotels"]) for _ in range(len(population))
        ]

    else:
        hotels = [
            random.choice(city_entities["hotels"]) for _ in range(len(population))
        ]

    offices = [
        (
            random.choice(city_entities["offices"])
            if is_worker
            else {"OfficeID": 0, "isEssential": 0}
        )
        for is_worker in population["IsWorker"]
    ]

    population["HouseID"] = [i["HouseID"] for i in houses]
    population["OfficeID"] = [i["OfficeID"] for i in offices]
    population["SchoolID"] = [
        random.choice(city_entities["schools"]) if is_student else 0
        for is_student in population["IsStudent"]
    ]
    population["HotelID"] = [i["HotelID"] for i in hotels]

    if TWO_CITIES:
        population["TravelOfficeID"] = [
            random.choice(entities[ocity]["offices"])["OfficeID"] if is_worker else 0
            for is_worker in population["IsWorker"]
        ]

    else:
        population["TravelOfficeID"] = [
            random.choice(city_entities["offices"])["OfficeID"] if is_worker else 0
            for is_worker in population["IsWorker"]
        ]

    population["TravelsFor"] = [7 for _ in range(len(population))]
    population["TravelProbability"] = [1 for is_worker in population["IsWorker"]]
    population["HouseNeighbourhoodID"] = [i["NeighbourhoodID"] for i in houses]
    population["HotelNeighbourhoodID"] = [i["NeighbourhoodID"] for i in hotels]

    population["Infected"] = [
        1 if i < INITIAL_INFECTED[city_id] else 0 for i in range(len(population))
    ]
    population["IsEssentialWorker"] = [i["isEssential"] for i in offices]


def main():
    cities = ["CityA"]
    if TWO_CITIES:
        cities = ["CityA", "CityB"]

    populations = {}
    entities = {}
    all_data = []

    current_entity_count = {
        "houses": 0,
        "hotels": 0,
        "offices": 0,
        "schools": 0,
        "neighbourhoods": 0,
    }

    for city_id, city in enumerate(cities):
        # Generate population
        population = generate_population(city, city_id)
        populations[city] = population

        houses, hotels, offices, schools, neighbourhoods = generate_entities(
            population, current_entity_count
        )
        entities[city] = {
            "houses": houses,
            "hotels": hotels,
            "offices": offices,
            "schools": schools,
            "neighbourhoods": neighbourhoods,
        }

        current_entity_count["houses"] += len(houses)
        current_entity_count["hotels"] += len(hotels)
        current_entity_count["offices"] += len(offices)
        current_entity_count["schools"] += len(schools)
        current_entity_count["neighbourhoods"] += len(neighbourhoods)

    for city_id, city in enumerate(cities):
        population = populations[city]
        assign_entities(city_id, city, population, entities)
        all_data.append(population)

    # Combine data from both cities and save to CSV
    df = pd.concat(all_data)

    file_path = ""

    if TWO_CITIES:
        file_path += "TwoCities"

    if SINGLE_COMPARTMENT:
        file_path += "SingleCompartment"

    if len(INFECTIVITIES) > 1:
        file_path += "MultipleInfectivities"

    if not file_path:
        file_path = "Dummy"

    file_path = f"{file_path}{int(TOTAL_POPULATION/1000)}k"

    df.to_csv(f"{file_path}.csv", index=False)
    print(file_path)

    if SAVE_ENTITIES:
        with open(f"{file_path}.json", "w") as f:
            json.dump(entities, f, indent=4)


if __name__ == "__main__":
    main()
