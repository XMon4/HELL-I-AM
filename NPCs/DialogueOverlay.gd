extends CanvasLayer
class_name DialogueOverlay

signal proceed_to_workbench(soul_index: int)
signal choice_made(soul_index: int, agreed: bool)

@onready var _choice_box  : VBoxContainer = $Control/ChoiceBox
@onready var _btn_suggest : Button        = $Control/ChoiceBox/BtnSuggest
@onready var _btn_agree   : Button        = $Control/ChoiceBox/BtnAgree
@onready var _human_line  : Label         = $Control/Ribbon/VBox/HumanLine
@onready var _reply_line  : Label         = $Control/Ribbon/VBox/ReplyLine
@onready var _start_btn   : Button        = $Control/Ribbon/VBox/StartBtn

var _avatar : TextureRect = null  # resolved at runtime; ok if missing

var _idx := -1
var _agreed := true
var _stage := 0  # 0 = choices, 1 = confirm

func _ready() -> void:
	# Resolve Avatar safely (won't crash if node isn't there)
	_avatar = get_node_or_null("Control/Avatar") as TextureRect

	_btn_suggest.pressed.connect(func(): _on_pick(false))
	_btn_agree.pressed.connect(func(): _on_pick(true))
	_start_btn.pressed.connect(_on_start)

	visible = false  # design/layout is handled in the scene

func start_for(index: int) -> void:
	_idx = index
	_agreed = true
	_stage = 0
	visible = true
	_set_avatar(index)
	_refresh()

func close() -> void:
	visible = false
	_idx = -1
	_stage = 0

func _refresh() -> void:
	var want := _desire_text()
	_human_line.text = "I want %s" % want
	if _stage == 0:
		_choice_box.visible = true
		_reply_line.visible = false
		_start_btn.visible = false
	else:
		_choice_box.visible = false
		_reply_line.visible = true
		_start_btn.visible = true
		_reply_line.text = "Great!" if _agreed else "No, I only want %s." % want

func _on_pick(agreed: bool) -> void:
	_agreed = agreed
	_stage = 1
	emit_signal("choice_made", _idx, _agreed)
	_refresh()

func _on_start() -> void:
	if _idx >= 0:
		emit_signal("proceed_to_workbench", _idx)
	close()

# --- desire text (placeholder) ---
func _desire_text() -> String:
	if _idx < 0:
		return "something"
	if GameDB and GameDB.has_method("get_desire_for_index"):
		return String(GameDB.get_desire_for_index(_idx))
	var nm := GameDB.name_by_index(_idx).to_lower()
	if nm.find("andrew") >= 0: return "fame"
	if nm.find("vixy")   >= 0: return "revenge"
	if nm.find("cecylia")>= 0: return "happiness"
	return "something"

# --- avatar ---
func _set_avatar(index: int) -> void:
	if _avatar == null:
		return
	var tex: Texture2D = null
	if GameDB and GameDB.has_method("get_portrait_tex_by_index"):
		tex = GameDB.get_portrait_tex_by_index(index)
	if tex == null and GameDB and GameDB.has_method("get_portrait_path_by_index"):
		var p := String(GameDB.get_portrait_path_by_index(index))
		if p != "":
			var res := ResourceLoader.load(p)
			if res is Texture2D:
				tex = res
	_avatar.texture = tex
	_avatar.visible = tex != null
