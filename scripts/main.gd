extends Control

var split: HSplitContainer
var left_pane: Control
var right_tabs: TabContainer
var workbench: Control
var profile_overlay: CanvasLayer
var dialogue_overlay: CanvasLayer
var souls_panel: Node
var souls_list: ItemList

func _ready() -> void:
	_resolve_nodes()
	_bootstrap_layout()
	_wire_signals()
	_populate_souls_list()

func _resolve_nodes() -> void:
	split           = find_child("HSplitContainer", true, false) as HSplitContainer
	left_pane       = find_child("LeftPane",        true, false) as Control
	right_tabs      = find_child("RightTabs",       true, false) as TabContainer
	workbench       = find_child("Workbench",       true, false) as Control
	profile_overlay = find_child("ProfileOverlay",  true, false) as CanvasLayer
	dialogue_overlay= find_child("DialogueOverlay", true, false) as CanvasLayer
	souls_panel     = left_pane
	if left_pane:
		souls_list = left_pane.find_child("SoulsList", true, false) as ItemList
	if souls_list == null:
		souls_list = find_child("SoulsList", true, false) as ItemList

func _bootstrap_layout() -> void:
	if split:
		split.split_offset = max(split.split_offset, 260)
	if left_pane:
		left_pane.visible = true
	if profile_overlay:
		profile_overlay.visible = false
	if dialogue_overlay:
		dialogue_overlay.visible = false
	if souls_list:
		souls_list.visible = true
		souls_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		souls_list.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		souls_list.max_columns = 1

func _wire_signals() -> void:
	# Profile overlay -> Offer a deal
	if profile_overlay and profile_overlay.has_signal("offer_deal_requested"):
		if not profile_overlay.offer_deal_requested.is_connected(Callable(self, "_on_offer_deal")):
			profile_overlay.offer_deal_requested.connect(Callable(self, "_on_offer_deal"))

	# Dialogue overlay -> proceed to workbench
	if dialogue_overlay and dialogue_overlay.has_signal("proceed_to_workbench"):
		if not dialogue_overlay.proceed_to_workbench.is_connected(Callable(self, "_on_dialogue_proceed")):
			dialogue_overlay.proceed_to_workbench.connect(Callable(self, "_on_dialogue_proceed"))

	# Workbench -> contract finished
	if workbench and workbench.has_signal("contract_ready"):
		if not workbench.contract_ready.is_connected(Callable(self, "_on_contract_ready")):
			workbench.contract_ready.connect(Callable(self, "_on_contract_ready"))

	# Souls list clicks
	if souls_list:
		if not souls_list.item_selected.is_connected(Callable(self, "_on_soul_pick")):
			souls_list.item_selected.connect(Callable(self, "_on_soul_pick"))
		if not souls_list.item_clicked.is_connected(Callable(self, "_on_soul_clicked")):
			souls_list.item_clicked.connect(Callable(self, "_on_soul_clicked"))
		if souls_list.item_activated.is_connected(Callable(self, "_on_soul_pick")):
			souls_list.item_activated.disconnect(Callable(self, "_on_soul_pick"))

	# Legacy SoulsPanel
	if souls_panel and souls_panel.has_signal("soul_selected"):
		if not souls_panel.soul_selected.is_connected(Callable(self, "_on_soul_selected")):
			souls_panel.soul_selected.connect(Callable(self, "_on_soul_selected"))


func _populate_souls_list() -> void:
	if souls_list == null:
		return
	if GameDB and GameDB.has_method("seed_if_empty"):
		GameDB.seed_if_empty()
	souls_list.clear()
	for i in range(GameDB.index_count()):
		souls_list.add_item(GameDB.name_by_index(i))

# --- list handlers ---
func _on_soul_pick(index: int) -> void:
	_open_profile_or_craft(index)

func _on_soul_clicked(index: int, _pos: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_open_profile_or_craft(index)

func _on_soul_selected(index: int) -> void:
	_open_profile_or_craft(index)

func _open_profile_or_craft(index: int) -> void:
	if profile_overlay and profile_overlay.has_method("start_for"):
		profile_overlay.call("start_for", index)
	else:
		_on_offer_deal(index)  # no overlay => jump straight into flow

# --- Profile -> Dialogue ---
func _on_offer_deal(index: int) -> void:
	if profile_overlay and profile_overlay.has_method("close"):
		profile_overlay.call("close")
	# lock player now (designer’s request)
	if left_pane:
		left_pane.visible = false
	# show Dialogue first (if present), else go straight to workbench
	if dialogue_overlay and dialogue_overlay.has_method("start_for"):
		dialogue_overlay.call("start_for", index)
	else:
		_open_workbench(index)

# --- Dialogue -> Workbench ---
func _on_dialogue_proceed(index: int) -> void:
	_open_workbench(index)

func _open_workbench(index: int) -> void:
	if workbench:
		workbench.visible = true

	# Try by Control reference first
	var switched := _switch_to_tab_control(workbench)
	# Fallback by tab name if needed
	if not switched:
		_switch_to_tab_named("Workbench")

	if workbench and workbench.has_method("set_current_soul"):
		workbench.call("set_current_soul", index)

# --- Finish -> Ongoing ---
func _on_contract_ready(_i: int, _o: Array[String], _a: Array[String], _c: Array[String], _p: float) -> void:
	if left_pane:
		left_pane.visible = true
	_switch_to_tab_named("Ongoing")

# --- Tab helpers ---
func _switch_to_tab_control(ctrl: Control) -> bool:
	if right_tabs == null or ctrl == null:
		return false
	for i in range(right_tabs.get_tab_count()):
		if right_tabs.get_tab_control(i) == ctrl:
			right_tabs.current_tab = i
			return true
	return false

func _switch_to_tab_named(name: String) -> void:
	if right_tabs == null:
		return
	for i in range(right_tabs.get_tab_count()):
		var c := right_tabs.get_tab_control(i)
		if c and c.name == name:
			right_tabs.current_tab = i
			return
