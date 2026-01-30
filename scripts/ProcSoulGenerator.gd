extends Node

# Procedural soul generator used by SoulsPanel's "New" button.
# Body + Lifespan are now separate from inv.

const BODY_TYPES: Array[String] = ["Beautiful", "Healthy", "Sick", "Dying"]
const GENDERS: Array[String] = ["male", "female"]
const CLASSES: Array[String] = ["naive", "desperate", "lawyer"]
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]


func generate_soul(i: int) -> Dictionary:
	# Ensure we don't accidentally reuse an id if the player spam-clicks.
	var salt := int(Time.get_ticks_msec()) % 100000
	var soul_id := "s_proc_%d_%d" % [i, salt]

	var gender: String = GENDERS[randi() % GENDERS.size()]
	var age := randi_range(18, 70)
	var btype: String = BODY_TYPES[randi() % BODY_TYPES.size()]
	var body := {
		"id": "npc_body_%s" % soul_id,
		"gender": gender,
		"age": age,
		"type": btype,
	}

	# Lifespan is now an inventory-like persistent resource for the player,
	# but a soul can still "have" a lifespan value for contract asks.
	# Keep it in 5-year chunks.
	var lifespan := int(round(float(randi_range(5, 60)) / 5.0)) * 5
	lifespan = clampi(lifespan, 5, 60)

	var inv: Dictionary = {"Soul": true}
	if randf() < 0.60:
		inv["Money"] = randi_range(500, 30000)
	if randf() < 0.15:
		inv["Fame"] = true

	var traits: Dictionary = {}
	if randf() < 0.12:
		traits["Trait: manipulation"] = true

	return {
		"id": soul_id,
		"name": "Human %d" % (i + 1),
		"difficulty": DIFFICULTIES[randi() % DIFFICULTIES.size()],
		"class": CLASSES[randi() % CLASSES.size()],
		"desire": "money",
		"inv": inv,
		"traits": traits,
		"body": body,
		"lifespan": lifespan,
	}
