extends Node
class_name MinesService

signal souls_bound_changed(value: int)
signal ore_generated(amount: int, day: int)

var souls_bound: int = 0
var taura_owned := false  # toggled by NPCManager

func _ready() -> void:
	DayCycle.day_advanced.connect(_on_day)

func bind_souls(count: int) -> bool:
	if count <= 0: return false
	if Economy.get_balance(Economy.Currency.SOULS) < count: return false
	Economy.add(Economy.Currency.SOULS, -count)
	souls_bound += count
	souls_bound_changed.emit(souls_bound)
	return true

func _on_day(day: int) -> void:
	var t := Economy.tuning
	var flat_taura := (t.taura_flat_ore_per_day if Mines.taura_owned else 0)
	var gain := t.base_ore_per_day + souls_bound * t.ore_per_soul_per_day + flat_taura
	if gain > 0:
		Economy.add(Economy.Currency.ORE, gain)
		ore_generated.emit(gain, day)
