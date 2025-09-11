class_name EconomyTuning
extends Resource

@export_group("Start Balances")
@export var starting_money: int = 100
@export var starting_ore:   int = 0
@export var starting_souls: int = 0

@export_group("Daily Generation")
@export var casino_base_money_per_day: int = 100
@export var base_ore_per_day: int = 0
@export var ore_per_soul_per_day: int = 5

@export_group("NPC Effects")
@export var taura_flat_ore_per_day: int = 20
@export var asmodea_money_multiplier: float = 0.5
