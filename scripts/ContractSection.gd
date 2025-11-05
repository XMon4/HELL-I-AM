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
	if header_btn == null and header_path != NodePath(""):
		header_btn = get_node_or_null(header_path) as Button
	if list == null and list_path != NodePath(""):
		list = get_node_or_null(list_path) as ItemList

	# Fallbacks
	if header_btn == null:
		var btns := find_children("*", "Button", true, false)
		for b in btns:
			if (b as Button).name.to_lower().contains("header"):
				header_btn = b as Button
				break
		if header_btn == null and btns.size() > 0:
			header_btn = btns[0] as Button

	if list == null:
		var lists := find_children("*", "ItemList", true, false)
		if lists.size() > 0:
			list = lists[0] as ItemList

	# Create if missing
	if header_btn == null:
		header_btn = Button.new(); header_btn.name = "Header"
		header_btn.text = (section_key.capitalize() if not section_key.is_empty() else "Section")
		add_child(header_btn, 0)
	if list == null:
		list = ItemList.new(); list.name = "Items"
		add_child(list)

	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical   = Control.SIZE_EXPAND_FILL

func _on_header() -> void:
	emit_signal("header_clicked", section_key)

func add_item(label: String, data: Dictionary = {}) -> void:
	if list == null:
		return
	for i in range(list.get_item_count()):
		if list.get_item_text(i) == label:
			return
	list.add_item(label)
	list.set_item_metadata(list.get_item_count() - 1, data)
	emit_signal("items_changed", section_key, get_labels(), get_items_meta())

func set_items(items: Array[Dictionary]) -> void:
	_ensure_controls()
	list.clear()
	for d in items:
		var lbl := String(d.get("label", ""))
		list.add_item(lbl)
		list.set_item_metadata(list.get_item_count() - 1, d.get("meta", {}))
	emit_signal("items_changed", section_key, get_labels(), get_items_meta())

func clear() -> void:
	_ensure_controls()
	list.clear()
	emit_signal("items_changed", section_key, [], [])

func get_labels() -> Array[String]:
	var out: Array[String] = []
	if list == null:
		return out
	for i in range(list.get_item_count()):
		out.append(list.get_item_text(i))
	return out

func get_items_meta() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if list == null:
		return out
	for i in range(list.get_item_count()):
		out.append(list.get_item_metadata(i))
	return out

func remove_by_prefix(prefix:String) -> void:
	_ensure_controls()
	if list == null: return
	for i in range(list.get_item_count() - 1, -1, -1):
		if String(list.get_item_text(i)).begins_with(prefix):
			list.remove_item(i)
	emit_signal("items_changed", section_key, get_labels(), get_items_meta())
