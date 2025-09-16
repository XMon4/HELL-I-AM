extends Control
class_name OngoingPanel

@onready var cards_box: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var row_template: Control    = $VBoxContainer/ScrollContainer/VBoxContainer/OngoingRow

func _ready() -> void:
	add_to_group("ongoing_panel")
	if row_template != null:
		row_template.visible = false
	# layout safety
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	if cards_box != null:
		cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL

# Preferred call: full details + acceptance
func add_contract_entry(human_name: String, offers: Array[String], asks: Array[String], clauses: Array[String], acceptance: float = -1.0) -> void:
	if cards_box == null:
		return

	var row: Control = _new_row()
	row.visible = true

	var title: Label        = row.get_node_or_null("Pad/Inner/Title") as Label
	var body_node: Node     = row.get_node_or_null("Pad/Inner/Body")
	var bar: ProgressBar    = row.get_node_or_null("Pad/Inner/ProgressRow/ProgressBar") as ProgressBar
	var pct_lbl: Label      = row.get_node_or_null("Pad/Inner/ProgressRow/Pct") as Label

	if title != null:
		title.text = human_name + " — signed"

	# progress
	if bar != null:
		bar.show_percentage = false
	if acceptance >= 0.0:
		var pct_val: int = int(round(acceptance * 100.0))
		if bar != null:
			bar.value = pct_val
			bar.visible = true
		if pct_lbl != null:
			pct_lbl.text = str(pct_val) + "%"
			pct_lbl.visible = true
	else:
		if bar != null: bar.visible = false
		if pct_lbl != null: pct_lbl.visible = false

	# body
	_set_body_text(body_node, offers, asks, clauses)

	cards_box.add_child(row)

# Legacy call: ignore (prevents duplicates)
func add_contract(_title: String, _acceptance: float) -> void:
	return

func clear_all() -> void:
	if cards_box == null:
		return
	for c in cards_box.get_children():
		c.queue_free()

# -------- helpers --------
func _new_row() -> Control:
	if row_template != null and is_instance_valid(row_template):
		return row_template.duplicate() as Control
	return PanelContainer.new()  # fallback

func _set_body_text(body_node: Node, offers: Array[String], asks: Array[String], clauses: Array[String]) -> void:
	var offers_s := _fmt_parts(offers)
	var asks_s   := _fmt_parts(asks)
	var clauses_s:= _fmt_parts(clauses)

	if body_node is RichTextLabel:
		var rt := body_node as RichTextLabel
		rt.bbcode_enabled = true
		rt.text = "[b]Offer:[/b] " + offers_s + "\n" + \
				  "[b]Ask:[/b] "   + asks_s   + "\n" + \
				  "[b]Clauses:[/b] " + clauses_s
	elif body_node is Label:
		var lb := body_node as Label
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		lb.text = "Offer: " + offers_s + "\n" + \
				  "Ask: "   + asks_s   + "\n" + \
				  "Clauses: " + clauses_s

func _fmt_parts(arr: Array[String]) -> String:
	if arr == null: return "—"
	if arr.size() == 0: return "—"
	return _join(arr)

func _join(arr: Array[String]) -> String:
	var out := ""
	for i in range(arr.size()):
		out += arr[i]
		if i < arr.size() - 1:
			out += ", "
	return out
