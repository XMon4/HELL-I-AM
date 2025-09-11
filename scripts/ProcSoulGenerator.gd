extends Node
# (intentionally no class_name to avoid autoload name collisions)

func generate_soul(index: int) -> Dictionary:
	var human_name = "Human %d" % (index + 1)

	# simple inventory; no trailing commas, no fancy typing
	var inv = {
		"Soul": true,
		"Body": true,
		"Years of life": 10 + (index % 31)
	}

	# deterministic extra perk; Money -> int, others -> bool
	var pool = ["Musical skill", "Beauty", "Card skill", "Charisma", "Money"]
	var pick = pool[index % pool.size()]
	if pick == "Money":
		inv[pick] = 10000 + index * 1337
	else:
		inv[pick] = true

	# tiny trait hook for later debt logic
	var trait_pool = ["honorable", "average", "desperate", "schemer"]
	var persona = trait_pool[index % trait_pool.size()]

	var traits = {
		"morality": "neutral",
		"fear": 0.2,
		"greed": 0.5,
		"persona": persona
	}

	return {
		"id": "s_%d" % (index + 1),
		"name": human_name,
		"inv": inv,
		"traits": traits
	}
