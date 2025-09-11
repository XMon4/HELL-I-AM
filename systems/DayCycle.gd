extends Node
class_name DayCycleService

signal day_advanced(day: int)

@export var day: int = 1

func next_day() -> void:
	day += 1
	day_advanced.emit(day)
