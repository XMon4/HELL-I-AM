extends CanvasLayer
signal proceed_to_workbench(soul_index: int)
signal choice_made(soul_index: int, agreed: bool)

var _idx: int = -1
var _agreed: bool = true
var _stage: int = 0  # 0 = choices, 1 = confirm/start

# UI
var _panel: Panel
var _vbox: VBoxContainer
var _human_line: Label
var _reply_line: Label
var _start_btn: Button

var _choice_box: VBoxContainer
var _btn_suggest: Button   # "Wouldn't you prefer something else?"
var _btn_agree: Button     # "Of course."

# --- theme helpers (colors) ---
const COL_RED      := Color(1.0, 0.25, 0.25, 1.0)
const COL_RED_HOV  := Color(1.0, 0.35, 0.35, 1.0)
const COL_RED_PR   := Color(1.0, 0.5,  0.5,  1.0)
const COL_TEXT_PUR := Color(0.52, 0.25, 0.62, 1.0)     # purplish text for ribbon
const COL_RIB_BG   := Color(1, 1, 1, 0.86)             # white translucent
const COL_BAR_N    := Color(0, 0, 0, 0.35)             # dark translucent bars
const COL_BAR_H    := Color(0, 0, 0, 0.50)
const COL_BAR_P    := Color(0, 0, 0, 0.65)

func _ready() -> void:
	visible = false
	_build_ui()

func start_for(index: int) -> void:
	_idx = index
	_agreed = true
	_stage = 0
	visible = true
	_refresh()

func close() -> void:
	visible = false
	_idx = -1
	_stage = 0

# ---------------- UI ----------------
func _build_ui() -> void:
	# Bottom ribbon (white box)
	_panel = Panel.new()
	_panel.name = "Ribbon"
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 140
	_panel.offset_right = -140
	_panel.offset_top = -220
	_panel.offset_bottom = -60
	_panel.custom_minimum_size = Vector2(0, 140)

	var sb_panel := StyleBoxFlat.new()
	sb_panel.bg_color = COL_RIB_BG
	sb_panel.corner_radius_top_left = 14
	sb_panel.corner_radius_top_right = 14
	sb_panel.corner_radius_bottom_left = 14
	sb_panel.corner_radius_bottom_right = 14
	sb_panel.content_margin_left = 28
	sb_panel.content_margin_right = 28
	sb_panel.content_margin_top = 18
	sb_panel.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb_panel)

	_vbox = VBoxContainer.new()
	_panel.add_child(_vbox)
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left   = 10
	_vbox.offset_right  = -10
	_vbox.offset_top    = 10
	_vbox.offset_bottom = -10
	_vbox.add_theme_constant_override("separation", 8)

	_human_line = Label.new()
	_vbox.add_child(_human_line)
	_human_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_human_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_human_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_human_line.add_theme_font_size_override("font_size", 42)   # big line like mock
	_human_line.add_theme_color_override("font_color", COL_TEXT_PUR)

	_reply_line = Label.new()
	_vbox.add_child(_reply_line)
	_reply_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reply_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reply_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reply_line.add_theme_font_size_override("font_size", 32)
	_reply_line.visible = false

	_start_btn = Button.new()
	_vbox.add_child(_start_btn)
	_start_btn.text = "Start Contract"
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.visible = false
	_start_btn.custom_minimum_size = Vector2(0, 44)
	_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_btn.add_theme_font_size_override("font_size", 24)
	_start_btn.pressed.connect(_on_start_pressed)

	# Choice buttons (stacked, centered, **above** ribbon)
	_choice_box = VBoxContainer.new()
	add_child(_choice_box)
	_choice_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_choice_box.offset_left = 260
	_choice_box.offset_right = -260
	_choice_box.offset_top = -410
	_choice_box.offset_bottom = -300
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", 12)

	_btn_suggest = _make_choice_button("Wouldn't you prefer something else?")
	_btn_agree   = _make_choice_button("Of course.")
	_choice_box.add_child(_btn_suggest)
	_choice_box.add_child(_btn_agree)

	_btn_suggest.pressed.connect(func() -> void: _on_pick(false))
	_btn_agree.pressed.connect(func() -> void:   _on_pick(true))

func _make_choice_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", COL_RED)

	# dark translucent bar backgrounds (normal/hover/pressed)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = COL_BAR_N
	sb_n.corner_radius_top_left = 12
	sb_n.corner_radius_top_right = 12
	sb_n.corner_radius_bottom_left = 12
	sb_n.corner_radius_bottom_right = 12

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = COL_BAR_H

	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = COL_BAR_P

	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover",  sb_h)
	b.add_theme_stylebox_override("pressed", sb_p)

	# change text color slightly on hover/pressed for feedback
	b.add_theme_color_override("font_hover_color", COL_RED_HOV)
	b.add_theme_color_override("font_pressed_color", COL_RED_PR)
	return b

# ---------------- State / text ----------------
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
		if _agreed:
			_reply_line.text = "Great!"
			_reply_line.add_theme_color_override("font_color", COL_TEXT_PUR)
		else:
			_reply_line.text = "No, I only want %s." % want
			_reply_line.add_theme_color_override("font_color", COL_RED)

func _on_pick(agreed: bool) -> void:
	_agreed = agreed
	_stage = 1
	emit_signal("choice_made", _idx, _agreed)  # (optional) hook for personality later
	_refresh()

func _on_start_pressed() -> void:
	if _idx >= 0:
		emit_signal("proceed_to_workbench", _idx)
	close()

# placeholder desire mapping until stored in GameDB
func _desire_text() -> String:
	if _idx < 0: return "something"
	var nm := GameDB.name_by_index(_idx).to_lower()
	if nm.find("andrew") >= 0: return "fame"
	if nm.find("vixy")   >= 0: return "revenge"
	if nm.find("cecylia")>= 0: return "happiness"
	return "something"
