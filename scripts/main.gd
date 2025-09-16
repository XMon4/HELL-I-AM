extends Control

@onready var workbench: Node = find_child("Workbench", true, false)
@onready var souls_panel: SoulsPanel = _find_souls_panel()
@onready var ongoing_panel: OngoingPanel = find_child("Ongoing", true, false) as OngoingPanel

func _ready() -> void:
	# Souls → Workbench
	if souls_panel and not souls_panel.is_connected("soul_selected", Callable(self, "_on_soul_selected")):
		souls_panel.soul_selected.connect(_on_soul_selected)
	if souls_panel and souls_panel.has_method("refresh"):
		souls_panel.refresh()

	# Workbench → Ongoing

func _find_souls_panel() -> SoulsPanel:
	var by_name: Node = find_child("SoulsPanel", true, false)
	if by_name is SoulsPanel:
		return by_name as SoulsPanel
	# Fallback: search by type
	var stack: Array[Node] = []
	stack.append(self)
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is SoulsPanel:
			return n as SoulsPanel
		for c in n.get_children():
			stack.append(c)
	return null

func _on_soul_selected(idx: int) -> void:
	if workbench and workbench.has_method("set_current_soul"):
		workbench.set_current_soul(idx)
