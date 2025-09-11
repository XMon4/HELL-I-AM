extends Control
class_name CursesPanel

var cost_lbl:  Label
var craft_btn: Button
var count_lbl: Label

func _ready() -> void:
	# Flexible lookups (works even if paths changed)
	cost_lbl  = get_node_or_null("VBox/CostLabel")  as Label
	if cost_lbl == null:  cost_lbl  = find_child("CostLabel",  true, false) as Label

	craft_btn = get_node_or_null("VBox/CraftBtn")   as Button
	if craft_btn == null: craft_btn = find_child("CraftBtn",   true, false) as Button

	count_lbl = get_node_or_null("VBox/CountLabel") as Label
	if count_lbl == null: count_lbl = find_child("CountLabel", true, false) as Label

	# Hook button
	if craft_btn and not craft_btn.pressed.is_connected(_on_craft):
		craft_btn.pressed.connect(_on_craft)

	# React to changes
	if not Curses.count_changed.is_connected(_refresh):
		Curses.count_changed.connect(_refresh)
	if not Economy.balance_changed.is_connected(_on_bal):
		Economy.balance_changed.connect(_on_bal)

	_refresh()  # initial state

func _on_craft() -> void:
	# Try to craft; if not enough ore, show tooltip and keep disabled state consistent
	if not Curses.craft_one():
		if craft_btn:
			craft_btn.tooltip_text = "Need %d ore." % Curses.ORE_COST
	_refresh()

func _on_bal(_c: int, _v: int) -> void:
	_refresh()

func _refresh() -> void:
	var have := Economy.get_balance(Economy.Currency.ORE)
	if cost_lbl:
		cost_lbl.text = "Cost: %d ore (have %d)" % [Curses.ORE_COST, have]

	if count_lbl:
		count_lbl.text = "Curses: %d" % Curses.count

	if craft_btn:
		var enough := have >= Curses.ORE_COST
		craft_btn.disabled = not enough
		craft_btn.tooltip_text = "" if enough else "Need %d ore." % Curses.ORE_COST
