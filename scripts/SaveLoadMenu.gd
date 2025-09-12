extends Control
class_name SaveLoadMenu

const SLOT_COUNT: int = 3
const SLOT_PATHS: Array[String] = [
	"user://save_slot_1.json",
	"user://save_slot_2.json",
	"user://save_slot_3.json"
]

@onready var rows_box: VBoxContainer     = get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/Rows") as VBoxContainer
@onready var row_template: HBoxContainer = get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/Rows/RowTemplate") as HBoxContainer
@onready var status_lbl: Label           = get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/Status") as Label
@onready var close_btn: Button           = get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/CloseBtn") as Button

var _rows: Array[HBoxContainer] = []

func _ready() -> void:
	add_to_group("save_menu")
	_build_rows_from_template()
	_refresh_all()
	visible = false
	if close_btn:
		close_btn.pressed.connect(func() -> void: hide())

func _save_service() -> SaveLoadService:
	return get_node_or_null("/root/SaveLoad") as SaveLoadService

func open_menu() -> void:
	_refresh_all()
	show()
	if close_btn:
		close_btn.grab_focus()

func _build_rows_from_template() -> void:
	_rows.clear()

	if rows_box == null:
		push_error("SaveLoadMenu: Rows VBox not found at CenterContainer/PanelContainer/VBoxContainer/Rows")
		return
	if row_template == null:
		push_error("SaveLoadMenu: RowTemplate not found under Rows")
		return

	row_template.visible = false

	for i in range(SLOT_COUNT):
		var row: HBoxContainer = row_template.duplicate() as HBoxContainer
		row.visible = true
		row.name = "Row_%d" % i

		var name_lbl: Label = row.get_node_or_null("Name") as Label
		var save_btn: Button = row.get_node_or_null("Save") as Button
		var load_btn: Button = row.get_node_or_null("Load") as Button
		var del_btn: Button  = row.get_node_or_null("Delete") as Button

		if name_lbl:
			name_lbl.text = "Slot %d" % (i + 1)

		if save_btn:
			save_btn.pressed.connect(func() -> void: _on_save_slot(i))
		if load_btn:
			load_btn.pressed.connect(func() -> void: _on_load_slot(i))
		if del_btn:
			del_btn.pressed.connect(func() -> void: _on_delete_slot(i))

		rows_box.add_child(row)
		_rows.append(row)

func _on_save_slot(i: int) -> void:
	var svc: SaveLoadService = _save_service()
	if svc == null:
		if status_lbl: status_lbl.text = "Save service not found."
		return
	var path: String = SLOT_PATHS[i]
	var ok: bool = svc.save_game(path)
	if status_lbl:
		status_lbl.text = ("Saved to %s" if ok else "Save failed for %s") % path
	_refresh_row(i)

func _on_load_slot(i: int) -> void:
	var svc: SaveLoadService = _save_service()
	if svc == null:
		if status_lbl: status_lbl.text = "Save service not found."
		return
	var path: String = SLOT_PATHS[i]
	if not FileAccess.file_exists(path):
		if status_lbl: status_lbl.text = "No save in Slot %d" % (i + 1)
		return
	var ok: bool = svc.load_game(path)
	if status_lbl:
		status_lbl.text = ("Loaded from %s" if ok else "Load failed for %s") % path
	if ok:
		_refresh_all()

func _on_delete_slot(i: int) -> void:
	var path: String = SLOT_PATHS[i]
	if not FileAccess.file_exists(path):
		if status_lbl: status_lbl.text = "Slot %d is already empty." % (i + 1)
		_refresh_row(i)
		return
	var err: int = DirAccess.remove_absolute(path)
	if status_lbl:
		status_lbl.text = ("Deleted %s" if err == OK else "Delete failed for %s") % path
	_refresh_row(i)

func _refresh_all() -> void:
	for i in range(_rows.size()):
		_refresh_row(i)

func _refresh_row(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	var row: HBoxContainer = _rows[i]
	if row == null:
		return

	var meta: Label     = row.get_node_or_null("Meta") as Label
	var load_btn: Button = row.get_node_or_null("Load") as Button
	var del_btn: Button  = row.get_node_or_null("Delete") as Button

	var path: String = SLOT_PATHS[i]
	if not FileAccess.file_exists(path):
		if meta: meta.text = "Empty"
		if load_btn: load_btn.disabled = true
		if del_btn:  del_btn.disabled  = true
		return

	var info: Dictionary = _read_summary(path)
	var t_str: String = _format_mtime(path)
	var line: String = "Day %d  •  M:%d  O:%d  S:%d" % [
		int(info.get("day", 1)),
		int(info.get("money", 0)),
		int(info.get("ore", 0)),
		int(info.get("souls", 0))
	]
	if meta:
		meta.text = line + "   —   " + t_str
	if load_btn:
		load_btn.disabled = false
	if del_btn:
		del_btn.disabled = false

func _read_summary(path: String) -> Dictionary:
	var out: Dictionary = {"day": 1, "money": 0, "ore": 0, "souls": 0}

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var txt: String = f.get_as_text()
	f.close()

	var parser: JSON = JSON.new()
	var err: int = parser.parse(txt)
	if err != OK:
		return out

	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = data as Dictionary

	var eco: Dictionary = d.get("economy", {}) as Dictionary
	if eco.has("money"): out["money"] = int(eco["money"])
	if eco.has("ore"):   out["ore"]   = int(eco["ore"])
	if eco.has("souls"): out["souls"] = int(eco["souls"])

	var dc: Dictionary = d.get("day_cycle", {}) as Dictionary
	if dc.has("day"): out["day"] = int(dc["day"])
	return out

func _format_mtime(path: String) -> String:
	var ts: int = FileAccess.get_modified_time(path)
	if ts <= 0:
		return ""
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year",0)), int(dt.get("month",0)), int(dt.get("day",0)),
		int(dt.get("hour",0)), int(dt.get("minute",0)), int(dt.get("second",0))
	]
