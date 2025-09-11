class_name CostBundle
extends Resource

@export var money: int = 0
@export var ore:   int = 0
@export var souls: int = 0

func is_zero() -> bool:
	return money == 0 and ore == 0 and souls == 0
