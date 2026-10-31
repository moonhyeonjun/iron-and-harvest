"""Executable design check, not the Godot implementation or a fun/playtime test.

Models the food chain only. Quarry/smithy output, taxes beyond static budget,
repair delays, personal actions, trust, trade and projects are not simulated.
"""

from copy import deepcopy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(config):
    require(config["schema_version"] == 1, "Unsupported design schema")
    for key in ("population", "households", "labor_pool", "season_days", "food_per_person", "warehouse_capacity"):
        require(type(config[key]) is int and config[key] > 0, f"Invalid {key}")
    require(sum(config["workers"].values()) <= config["labor_pool"], "Double-booked labor")
    for section in ("workers", "raw_yields", "full_upkeep"):
        require(all(type(n) is int and n >= 0 for n in config[section].values()), f"Invalid {section}")
    ids = [recipe["id"] for recipe in config["recipes"]]
    require(len(set(ids)) == len(ids), "Duplicate recipe")
    for recipe in config["recipes"]:
        require(recipe["worker_key"] in config["workers"], "Unknown workforce")
        require(type(recipe["batches_per_worker"]) is int and recipe["batches_per_worker"] > 0, "Invalid batches")
        for side in ("inputs", "outputs"):
            require(bool(recipe[side]), "Empty recipe")
            require(all(type(n) is int and n > 0 for n in recipe[side].values()), "Invalid recipe quantity")


def simulate_day(config, stock, winter=False):
    """Fixed input→flour→bread→consumption order; all storage units weigh one."""
    stock = deepcopy(stock)
    capacity = config["warehouse_capacity"]
    require(all(type(n) is int and n >= 0 for n in stock.values()), "Invalid initial inventory")
    require(sum(stock.values()) <= capacity, "Initial warehouse overflow")
    workers = config["workers"]
    yields = config["raw_yields"]
    wheat_key = "wheat_winter" if winter else "wheat_normal"
    production = {"wheat": workers["farm"] * yields[wheat_key], "wood": workers["logging"] * yields["wood"]}
    for item, amount in production.items():
        if sum(stock.values()) + amount <= capacity:
            stock[item] = stock.get(item, 0) + amount
    batches = {}
    for recipe in config["recipes"]:
        completed = 0
        for _ in range(workers[recipe["worker_key"]] * recipe["batches_per_worker"]):
            if any(stock.get(item, 0) < count for item, count in recipe["inputs"].items()):
                break
            new_size = sum(stock.values()) - sum(recipe["inputs"].values()) + sum(recipe["outputs"].values())
            if new_size > capacity:
                break
            for item, count in recipe["inputs"].items():
                stock[item] -= count
            for item, count in recipe["outputs"].items():
                stock[item] = stock.get(item, 0) + count
            completed += 1
        batches[recipe["id"]] = completed
    demand = config["population"] * config["food_per_person"]
    eaten = min(stock.get("bread", 0), demand)
    stock["bread"] = stock.get("bread", 0) - eaten
    require(all(n >= 0 for n in stock.values()), "Negative inventory")
    require(sum(stock.values()) <= capacity, "Warehouse overflow")
    return stock, {"batches": batches, "unfed": demand - eaten}


def main():
    config = json.loads((ROOT / "data/design/economy-baseline.json").read_text())
    validate(config)
    checks = []

    stock, report = simulate_day(config, {})
    require(stock["bread"] == 16 and report["unfed"] == 0, "Normal food balance differs from GDD")
    require(report["batches"] == {"flour": 4, "bread": 4}, "Incorrect normal chain")
    checks.append("Normal: 32 wheat -> 40 bread; net +16 food/day")

    one_farm = deepcopy(config)
    one_farm["workers"]["farm"] = 2
    stock, report = simulate_day(one_farm, {"bread": 100})
    require(stock["bread"] == 96 and report["unfed"] == 0, "One-farm deficit differs")
    checks.append("One farm: net -4 food/day")

    stock = {"bread": config["winter_start_bread"]}
    for _ in range(config["season_days"]):
        stock, report = simulate_day(config, stock, winter=True)
        require(report["unfed"] == 0, "Winter reserve ran out")
    require(stock["bread"] == 44, "Winter balance differs from GDD")
    checks.append("Winter: 240 reserve -> 44 after 14 days; deficit 196")

    no_fuel = deepcopy(config)
    no_fuel["workers"]["logging"] = 0
    stock, report = simulate_day(no_fuel, {})
    require(report["batches"]["bread"] == 0 and report["unfed"] == 24, "Fuel shortage ignored")
    checks.append("No fuel: bread production blocked, 24 unmet meals reported")

    full_stock = {"stone": config["warehouse_capacity"]}
    stock, report = simulate_day(config, full_stock)
    require(stock["stone"] == full_stock["stone"] and report["unfed"] == 24, "Storage limit ignored")
    checks.append("Full warehouse: no overflow or silent deletion")

    tax = config["households"] * config["normal_tax_per_household"]
    upkeep = sum(config["full_upkeep"].values())
    require(tax == upkeep == 12, "Full estate budget differs from GDD")
    checks.append("Normal tax 12 = full estate upkeep 12 gold/day")

    invalid = deepcopy(config)
    invalid["workers"]["farm"] = 99
    try:
        validate(invalid)
    except ValueError:
        checks.append("Over-allocation of labor rejected")
    else:
        raise ValueError("Invalid labor allocation accepted")

    for check in checks:
        print(f"PASS: {check}")
    print(f"{len(checks)} design checks passed; no Godot/gameplay validation performed.")


if __name__ == "__main__":
    main()
