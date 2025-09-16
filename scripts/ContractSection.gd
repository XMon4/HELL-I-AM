extends VBoxContainer
class_name ContractSection

signal header_clicked(key: String)
signal items_changed(key: String, labels: Array[String], meta: Array[Dictionary])

@export var section_key: String = ""          # "offer" | "ask" | "clause"
@export var header_path: NodePath
@export var list_path: NodePath

var header_btn: Button
var list: ItemList

func _ready() -> void:
	# Fallback: infer section_key from node name if not set in Inspector
	if section_key.is_empty():
		var ln := name.to_lower()
		if "offer" in ln:
			section_key = "offer"
		elif "ask" in ln:
			section_key = "ask"
		elif "clause" in ln or "clauses" in ln:
			section_key = "clause"

	_ensure_controls()
	if header_btn and not header_btn.is_connected("pressed", Callable(self, "_on_header")):
		header_btn.pressed.connect(_on_header)

func _ensure_controls() -> void:
	# From exported paths
	if header_btn == null and header_path != NodePath(""):
		header_btn = get_node_or_null(header_path) as Button
	if list == null and list_path != NodePath(""):
		list = get_node_or_null(list_path) as ItemList

	# Fallback by name
	if header_btn == null:
		header_btn = find_child("Header", true, false) as Button
	if list == null:
		list = find_child("Items", true, false) as ItemList

	# Create if missing (keeps Section_Clause safe even if scene lacks nodes)
	if header_btn == null:
		header_btn = Button.new()
		header_btn.name = "Header"
		header_btn.text = (section_key.capitalize() if not section_key.is_empty() else "Section")
		add_child(header_btn, 0)
	if list == null:
		list = ItemList.new()
		list.name = "Items"
		add_child(list)

	# Sane layout defaults
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _on_header() -> void:
	emit_signal("header_clicked", section_key)

func add_item(label: String, data: Dictionary = {}) -> void:
	if list == null:
		return
	for i in range(list.item_count):  # FIX
		if list.get_item_text(i) == label:
			return
	list.add_item(label)
	list.set_item_metadata(list.item_count - 1, data)
	emit_signal("items_changed", section_key, get_labels(), get_items_meta())

func set_items(items: Array[Dictionary]) -> void:
	_ensure_controls()
	list.clear()
	for d in items:
		var lbl := String(d.get("label", ""))
		list.add_item(lbl)
		list.set_item_metadata(list.item_count - 1, d.get("meta", {}))
	emit_signal("items_changed", section_key, get_labels(), get_items_meta())

func clear() -> void:
	_ensure_controls()
	list.clear()
	emit_signal("items_changed", section_key, [], [])

func get_labels() -> Array[String]:
	var out: Array[String] = []
	if list == null:
		return out
	for i in range(list.item_count):  # FIX
		out.append(list.get_item_text(i))
	return out

func get_items_meta() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if list == null:
		return out
	for i in range(list.item_count):  # FIX
		out.append(list.get_item_metadata(i))
	return out
