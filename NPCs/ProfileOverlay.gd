extends CanvasLayer
signal offer_deal_requested(soul_index: int)

var _idx: int = -1

@onready var backdrop: Control   = get_node_or_null("Backdrop")
@onready var panel: Control      = get_node_or_null("Panel")
@onready var name_lbl: Label     = get_node_or_null("Panel/Name")
@onready var info_lbl: Label     = get_node_or_null("Panel/Info")
@onready var offer_btn: Button   = get_node_or_null("Panel/OfferButton")

func _ready() -> void:
	visible = false

	# Make sure the overlay never blocks the rest of the UI
	if backdrop:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE   # clicks pass through
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP        # clicks work on the card

	if offer_btn and not offer_btn.pressed.is_connected(Callable(self, "_on_offer")):
		offer_btn.pressed.connect(Callable(self, "_on_offer"))

func start_for(index: int) -> void:
	_idx = index
	visible = true
	_refresh()

func close() -> void:
	visible = false
	_idx = -1

func _on_offer() -> void:
	if _idx >= 0:
		offer_deal_requested.emit(_idx)
		close()

# Global click-to-dismiss (outside the card)
func _input(event: InputEvent) -> void:
	if not visible or panel == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var gp: Vector2 = event.position
		if not panel.get_global_rect().has_point(gp):
			close()

func _refresh() -> void:
	if _idx < 0: return

	# Header
	var name: String = GameDB.name_by_index(_idx)
	if name_lbl: name_lbl.text = name

	# Data
	var soul: Dictionary = {}
	if _idx >= 0 and _idx < GameDB.index_count():
		soul = GameDB.souls[_idx]

	var diff: String   = String(soul.get("difficulty", ""))
	var klass: String  = String(soul.get("class", ""))
	var desire: String = GameDB.get_desire_for_index(_idx)

	var lines: Array[String] = []
	if diff  != "": lines.append("Difficulty: " + diff.capitalize())
	if klass != "": lines.append("Class: " + klass.capitalize())
	if desire != "": lines.append("Desire: " + desire.capitalize())

	lines.append("")
	lines.append("Inventory:")
	var inv: Dictionary = soul.get("inv", {})
	if inv.size() > 0:
		for k in inv.keys():
			var v = inv[k]
			if k == "Money" and (v is int):
				lines.append("- %s: $%d" % [k, int(v)])
			elif v is bool:
				lines.append("- " + k if v else "- %s: false" % k)
			else:
				lines.append("- %s: %s" % [k, str(v)])
	else:
		var sid := GameDB.id_by_index(_idx)
		for line in GameDB.list_soul_asks(sid):
			lines.append("- " + line)

	if info_lbl:
		info_lbl.text = "\n".join(lines)
