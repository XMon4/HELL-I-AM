extends Control
class_name SoulsPanel

signal soul_selected(index: int)

@export var list_path: NodePath
@export var new_btn_path: NodePath

var list: ItemList
var new_btn: Button

func _ready() -> void:
	if not GameDB.is_connected("souls_changed", Callable(self, "_on_db_souls_changed")):
		GameDB.souls_changed.connect(_on_db_souls_changed)

	_ensure_controls()

	if list and not list.is_connected("item_selected", Callable(self, "_on_item_selected")):
		list.item_selected.connect(_on_item_selected)
	if new_btn and not new_btn.is_connected("pressed", Callable(self, "_on_new_clicked")):
		new_btn.pressed.connect(_on_new_clicked)

	refresh()
	_auto_select_first()

func _on_db_souls_changed() -> void:
	refresh()
	_auto_select_first()

func _auto_select_first() -> void:
	if list and list.item_count > 0 and list.get_selected_items().is_empty():
		list.select(0)
		emit_signal("soul_selected", 0)

func _ensure_controls() -> void:
	# Try exported paths
	if list == null and list_path != NodePath(""):
		list = get_node_or_null(list_path) as ItemList
	if new_btn == null and new_btn_path != NodePath(""):
		new_btn = get_node_or_null(new_btn_path) as Button

	# Fallback: find any ItemList under this panel tree
	if list == null:
		list = _find_itemlist_any(self)

	if list == null:
		push_error("SoulsPanel: ItemList not found. Set 'list_path' to your left list node.")
		return

	# Force visible + sane layout & list mode (no icon grid)
	list.visible = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if list.custom_minimum_size.y < 180.0:
		list.custom_minimum_size = Vector2(list.custom_minimum_size.x, 180)
	list.max_columns = 1
	list.fixed_column_width = 0
	list.same_column_width = false
	list.fixed_icon_size = Vector2i(0, 0)
	list.icon_mode = ItemList.ICON_MODE_LEFT

func _find_itemlist_any(root: Node) -> ItemList:
	if root is ItemList:
		return root as ItemList
	for c in root.get_children():
		var found := _find_itemlist_any(c)
		if found:
			return found
	return null

func refresh() -> void:
	if list == null:
		return
	list.clear()

	var count: int = GameDB.index_count()
	for i in range(count):
		var s: Dictionary = GameDB.souls[i]
		var nm: String = String(s.get("name", ""))
		if nm.strip_edges().is_empty():
			nm = "Soul %d" % (i + 1)
		list.add_item(nm)

	# Debug: show what we actually pushed to the list
	var preview: Array[String] = []
	for j in range(min(list.item_count, 3)):
		preview.append(list.get_item_text(j))

func _on_item_selected(idx: int) -> void:
	emit_signal("soul_selected", idx)

func _on_new_clicked() -> void:
	var idx: int = GameDB.index_count()
	var soul: Dictionary = ProcSoulGenerator.generate_soul(idx)
	if GameDB.has_method("add_soul"):
		GameDB.add_soul(soul)
