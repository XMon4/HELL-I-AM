extends HBoxContainer

var next_btn: Button
var money_label: Label
var ore_label: Label
var souls_label: Label
var day_label: Label   # optional: remove if you don’t have a DayLabel node
var menu_btn: Button

func _ready() -> void:
	# Flexible lookups
	next_btn     = $NextDayBtn if has_node("NextDayBtn") else (find_child("NextDayBtn", true, false) as Button)
	money_label  = $MoneyLabel if has_node("MoneyLabel") else (find_child("MoneyLabel", true, false) as Label)
	ore_label    = $OreLabel   if has_node("OreLabel")   else (find_child("OreLabel",   true, false) as Label)
	souls_label  = $SoulsLabel if has_node("SoulsLabel") else (find_child("SoulsLabel", true, false) as Label)
	day_label    = $DayLabel   if has_node("DayLabel")   else (find_child("DayLabel",   true, false) as Label)
	menu_btn = $MenuBtn if has_node("MenuBtn") else (find_child("MenuBtn", true, false) as Button)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu)
	if next_btn:
		next_btn.pressed.connect(_on_next_day)

	_refresh_labels()
	if not Economy.balance_changed.is_connected(_on_bal):
		Economy.balance_changed.connect(_on_bal)

	# (Optional) show Day if you have DayLabel
	if day_label:
		if not DayCycle.day_advanced.is_connected(_on_day):
			DayCycle.day_advanced.connect(_on_day)
		_on_day(DayCycle.day)

func _on_next_day() -> void:
	DayCycle.next_day()

func _on_bal(_currency: int, _value: int) -> void:
	_refresh_labels()

func _refresh_labels() -> void:
	if money_label: money_label.text = "M: %d" % Economy.get_balance(Economy.Currency.MONEY)
	if ore_label:   ore_label.text   = "O: %d" % Economy.get_balance(Economy.Currency.ORE)
	if souls_label: souls_label.text = "S: %d" % Economy.get_balance(Economy.Currency.SOULS)

func _on_day(day: int) -> void:
	if day_label:
		day_label.text = "Day %d" % day
		
func _on_menu() -> void:
	# find the menu by group and open it
	var menus := get_tree().get_nodes_in_group("save_menu")
	if menus.size() > 0:
		var m := menus[0] as SaveLoadMenu
		if m != null:
			m.open_menu()
