# ProfileOverlay.gd
extends CanvasLayer
signal offer_deal_requested(soul_index: int)

var _idx := -1

func _ready() -> void:
	visible = false
	# OPTIONAL: if you have a Button at Panel/OfferButton, wire it:
	var btn := get_node_or_null("Panel/OfferButton")
	if btn and not btn.is_connected("pressed", Callable(self, "_on_offer")):
		btn.pressed.connect(_on_offer)

func start_for(index: int) -> void:
	_idx = index
	visible = true
	# Fill UI if you have labels (safe if not present)
	var name_lbl := get_node_or_null("Panel/Name") as Label
	if name_lbl:
		name_lbl.text = GameDB.name_by_index(index)

func close() -> void:
	visible = false
	_idx = -1

func _on_offer() -> void:
	if _idx >= 0:
		emit_signal("offer_deal_requested", _idx)
