extends Node
class_name ContractLimitsService

signal contracts_count_changed(remaining: int)

@export var limit_per_day := 2
var remaining_today := 2

func _ready() -> void:
	DayCycle.day_advanced.connect(_on_new_day)

func _on_new_day(_d: int) -> void:
	remaining_today = limit_per_day
	contracts_count_changed.emit(remaining_today)

func can_start() -> bool: return remaining_today > 0

func consume_one() -> bool:
	if remaining_today <= 0: return false
	remaining_today -= 1
	contracts_count_changed.emit(remaining_today)
	return true
	
