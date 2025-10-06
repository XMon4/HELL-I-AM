extends Control
class_name SoulsPanel

signal soul_selected(index: int)

@export var list_path: NodePath
@export var profile_overlay_path: NodePath
@export var new_btn_path: NodePath

var _list_node: Node
var _profile: Node
var _new_btn: Button

func _ready() -> void:
	# find nodes
	_list_node = get_node_or_null(list_path)
	if _list_node == null:
		_list_node = _find_itemlist_any(self)
	_profile = get_node_or_null(profile_overlay_path)
	_new_btn = get_node_or_null(new_btn_path) as Button

	if _list_node == null:
		push_error("SoulsPanel: ItemList not found under LeftPane. Set 'list_path'.")
		return
	if _profile == null:
		push_warning("SoulsPanel: profile_overlay_path not set; will emit soul_selected instead of opening a profile card.")

	# DB refresh
	if GameDB and not GameDB.souls_changed.is_connected(_on_db_souls_changed):
		GameDB.souls_changed.connect(_on_db_souls_changed)

	_wire_list_signals()
	_refresh()

	if _new_btn and not _new_btn.is_connected("pressed", Callable(self, "_on_new_clicked")):
		_new_btn.pressed.connect(_on_new_clicked)

func _on_db_souls_changed() -> void:
	_refresh()

func _find_itemlist_any(root: Node) -> ItemList:
	if root is ItemList:
		return root as ItemList
	for c in root.get_children():
		var found := _find_itemlist_any(c)
		if found: return found
	return null

func _wire_list_signals() -> void:
	if _list_node is ItemList:
		var il := _list_node as ItemList
		if not il.item_selected.is_connected(_on_item_pick):
			il.item_selected.connect(_on_item_pick)
		if not il.item_activated.is_connected(_on_item_pick):
			il.item_activated.connect(_on_item_pick)
		# also fire when clicking the already-selected row
		if not il.item_clicked.is_connected(_on_item_clicked):
			il.item_clicked.connect(_on_item_clicked)
			
	elif _list_node is BoxContainer:
		var box := _list_node as BoxContainer
		for i in range(box.get_child_count()):
			var b := box.get_child(i)
			if b is Button and not (b as Button).pressed.is_connected(_make_btn_cb(i)):
				(b as Button).pressed.connect(_make_btn_cb(i))
	else:
		push_warning("SoulsPanel: list node is neither ItemList nor BoxContainer.")

func _refresh() -> void:
	if _list_node is ItemList:
		var il := _list_node as ItemList
		il.clear()
		for i in range(GameDB.index_count()):
			il.add_item(GameDB.name_by_index(i))

func _on_item_pick(index: int) -> void:
	_open_profile_or_emit(index)

func _on_item_clicked(index: int, _pos: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_open_profile_or_emit(index)

func _make_btn_cb(index: int) -> Callable:
	return func() -> void:
		_open_profile_or_emit(index)

func _open_profile_or_emit(index: int) -> void:
	print("[SoulsPanel] picked index:", index)
	if _profile and _profile.has_method("start_for"):
		_profile.call("start_for", index)
	else:
		print("[SoulsPanel] no overlay; emitting soul_selected")
		emit_signal("soul_selected", index)


func _on_new_clicked() -> void:
	var idx := GameDB.index_count()
	var soul := ProcSoulGenerator.generate_soul(idx)
	if GameDB and GameDB.has_method("add_soul"):
		GameDB.add_soul(soul)
