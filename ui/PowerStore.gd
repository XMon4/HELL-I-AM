extends Control

const COST_SOULS: int = 2

@onready var souls_lbl: Label  = $"RootMargin/Root/HeaderRow/SoulsLabel"
@onready var price_lbl: Label  = $"RootMargin/Root/Card/CardMargin/CardBox/PriceRow/Price"
@onready var buy_btn: Button   = $"RootMargin/Root/Card/CardMargin/CardBox/PriceRow/BuyBtn"
@onready var status_lbl: Label = $"RootMargin/Root/Status"

func _ready() -> void:
	if GameDB and not GameDB.inventory_changed.is_connected(_refresh):
		GameDB.inventory_changed.connect(_refresh)
	buy_btn.pressed.connect(_on_buy_pressed)
	_refresh()

func _refresh() -> void:
	var unlocked: bool = GameDB.max_trait_slots >= 2
	var souls: int = int(GameDB.souls_currency)

	souls_lbl.text = "Souls: " + str(souls)
	price_lbl.text = "Cost: " + str(COST_SOULS) + " Souls"

	buy_btn.disabled = unlocked or (souls < COST_SOULS)
	status_lbl.text = "Unlocked" if unlocked else "Locked"

func _on_buy_pressed() -> void:
	if GameDB.max_trait_slots >= 2:
		return
	if GameDB.spend_souls(COST_SOULS):
		GameDB.max_trait_slots = 2
		GameDB.inventory_changed.emit()  # refresh Inventory overlay, etc.
