extends Node
class_name NPCManagerService

signal npc_hired(id: String)

var hired := {
	"mephisto": false,
	"taura": false,
	"asmodea": false,
	"jackie": false,
}

func is_hired(id: String) -> bool:
	return hired.get(id, false)

func hire(id: String, cost: CostBundle) -> bool:
	if is_hired(id): return true
	if not Economy.apply_cost(cost): return false
	hired[id] = true
	_apply_passive(id)
	npc_hired.emit(id)
	return true

func _apply_passive(id: String) -> void:
	match id:
		"taura":
			Mines.taura_owned = true
		"asmodea":
			Casino.asmodea_owned = true
		"jackie":
			ProducerSystem.unlock_national()
		"mephisto":
			DebtSystem.enable_mephisto(true)
		_:
			pass
