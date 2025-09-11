extends Control
class_name ProducerPanel

@onready var tier_lbl: Label = $"VBoxContainer/Tier"
@onready var effects_lbl: Label = $"VBoxContainer/Effects"

func _ready() -> void:
	if not NPCManager.npc_hired.is_connected(_on_hired): NPCManager.npc_hired.connect(_on_hired)
	_refresh()

func _refresh() -> void:
	tier_lbl.text = "Current tier: %s" % ProducerSystem.current_tier
	var msg := "• Higher Producer tier lets you promise bigger fame in contracts.\n• Jackie unlocks National tier."
	effects_lbl.text = msg

func _on_hired(id: String) -> void:
	if id == "jackie":
		_refresh()
