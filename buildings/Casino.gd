extends Node
class_name CasinoService

signal money_generated(amount: int, day: int)

var asmodea_owned := false  # toggled by NPCManager

func _ready() -> void:
	DayCycle.day_advanced.connect(_on_day)

func _on_day(day: int) -> void:
	var base := Economy.tuning.casino_base_money_per_day

	var mult := 1.0
	if Casino.asmodea_owned:
		mult = 1.0 + Economy.tuning.asmodea_money_multiplier

	var gain := int(floor(float(base) * mult))
	if gain > 0:
		Economy.add(Economy.Currency.MONEY, gain)
		money_generated.emit(gain, day)
