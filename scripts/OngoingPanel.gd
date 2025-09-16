extends Control
class_name OngoingPanel

@onready var cards_box: VBoxContainer = $"VBoxContainer/ScrollContainer/VBoxContainer"
@onready var row_template: Control = $"VBoxContainer/ScrollContainer/VBoxContainer/OngoingRow"

func _enter_tree() -> void:
	# Only needed if something still calls by group; harmless to keep
	add_to_group("ongoing_panel")

func _ready() -> void:
	if row_template:
		row_template.visible = false

	# Rebuild when data changes
	if GameDB and GameDB.has_signal("contracts_changed") and not GameDB.contracts_changed.is_connected(_on_contracts_changed):
		GameDB.contracts_changed.connect(_on_contracts_changed)

	_rebuild_from_db()

func _on_contracts_changed() -> void:
	_rebuild_from_db()

# If you keep calling this from main.gd, it will add a single row immediately.
# You can delete this method if you rely ONLY on contracts_changed.
func add_contract_entry(human_name: String, offers: Array[String], asks: Array[String], clauses: Array[String], acceptance: float = -1.0) -> void:
	if cards_box == null: return
	var row := _dup_row()
	_fill_row(row, human_name, offers, asks, clauses, acceptance)
	cards_box.add_child(row)

func _rebuild_from_db() -> void:
	if cards_box == null: return

	# Keep the template; clear others
	for c in cards_box.get_children():
		if c != row_template:
			c.queue_free()

	var list: Array = GameDB.get("ongoing_contracts") as Array
	if list == null: return

	for any_val in list:
		if typeof(any_val) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = any_val

		var name: String = String(d.get("name",""))
		var acceptance: float = float(d.get("acceptance", 0.0))

		var offers: Array[String] = []
		var asks: Array[String] = []
		var clauses: Array[String] = []
		for s in d.get("offers", []):  if typeof(s)  == TYPE_STRING: offers.append(String(s))
		for s2 in d.get("asks", []):    if typeof(s2) == TYPE_STRING: asks.append(String(s2))
		for s3 in d.get("clauses", []): if typeof(s3)== TYPE_STRING: clauses.append(String(s3))

		var row := _dup_row()
		_fill_row(row, name, offers, asks, clauses, acceptance)
		cards_box.add_child(row)

func _dup_row() -> Control:
	var r: Control = row_template.duplicate() as Control if row_template else PanelContainer.new()
	r.visible = true
	return r

func _fill_row(row: Control, name: String, offers: Array[String], asks: Array[String], clauses: Array[String], acceptance: float) -> void:
	var title: Label = row.get_node_or_null("Pad/Inner/Title") as Label
	var body: Label = row.get_node_or_null("Pad/Inner/Body") as Label
	var bar: ProgressBar = row.get_node_or_null("Pad/Inner/ProgressRow/ProgressBar") as ProgressBar
	var pct: Label = row.get_node_or_null("Pad/Inner/ProgressRow/Pct") as Label

	if title:
		title.text = "%s — signed" % name

	if bar:
		if acceptance >= 0.0:
			var pct_val: int = int(round(acceptance * 100.0))
			bar.value = pct_val
			bar.visible = true
			if pct: pct.text = "%d%%" % pct_val; pct.visible = true
		else:
			bar.visible = false
			if pct: pct.visible = false

	if body:
		body.text = "Offer: %s\nAsk: %s\nClauses: %s" % [_join(offers), _join(asks), _join(clauses)]

func _join(arr: Array[String]) -> String:
	var out := ""
	for i in range(arr.size()):
		out += arr[i]
		if i < arr.size() - 1:
			out += ", "
	return out
