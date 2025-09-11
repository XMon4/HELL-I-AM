extends Node
class_name EconomyService

signal balance_changed(currency: int, value: int)

enum Currency { MONEY, ORE, SOULS }

@export var tuning: EconomyTuning

var _bal := {
	Currency.MONEY: 0,
	Currency.ORE:   0,
	Currency.SOULS: 0,
}

func _ready() -> void:
	if tuning == null:
		tuning = EconomyTuning.new()
	set_balance(Currency.MONEY, tuning.starting_money)
	set_balance(Currency.ORE,   tuning.starting_ore)
	set_balance(Currency.SOULS, tuning.starting_souls)

func get_balance(c: int) -> int: return _bal.get(c, 0)

func set_balance(c: int, v: int) -> void:
	v = max(0, v)
	_bal[c] = v
	balance_changed.emit(c, v)

func add(c: int, d: int) -> void: set_balance(c, get_balance(c) + d)

func can_afford(cost: CostBundle) -> bool:
	return get_balance(Currency.MONEY) >= cost.money \
		and get_balance(Currency.ORE)   >= cost.ore \
		and get_balance(Currency.SOULS) >= cost.souls

func apply_cost(cost: CostBundle) -> bool:
	if not can_afford(cost): return false
	add(Currency.MONEY, -cost.money)
	add(Currency.ORE,   -cost.ore)
	add(Currency.SOULS, -cost.souls)
	return true
