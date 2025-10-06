extends Control

# ---- dynamic refs (resolved at runtime; robust to path changes) ----
var split: HSplitContainer
var left_pane: Control
var right_tabs: TabContainer
var workbench: Control
var profile_overlay: CanvasLayer
var souls_panel: Node
var souls_list: ItemList

func _ready() -> void:
	_resolve_nodes()
	_bootstrap_layout()
	_wire_signals()
	_populate_souls_list()   # force-visible + items so you can click

# ---------- resolve ----------
func _resolve_nodes() -> void:
	# find by name anywhere under the scene
	split           = find_child("HSplitContainer", true, false) as HSplitContainer
	left_pane       = find_child("LeftPane",        true, false) as Control
	right_tabs      = find_child("RightTabs",       true, false) as TabContainer
	workbench       = find_child("Workbench",       true, false) as Control
	profile_overlay = find_child("ProfileOverlay",  true, false) as CanvasLayer
	souls_panel     = left_pane                      # SoulsPanel.gd should be on this node
	# ItemList inside the left pane
	if left_pane:
		souls_list = left_pane.find_child("SoulsList", true, false) as ItemList
	if souls_list == null:
		souls_list = find_child("SoulsList", true, false) as ItemList

	# debug once
	print("[Main] found -> split:", split!=null, " left:", left_pane!=null, " right_tabs:", right_tabs!=null,
		  " workbench:", workbench!=null, " overlay:", profile_overlay!=null, " souls_list:", souls_list!=null)

# ---------- layout / visibility ----------
func _bootstrap_layout() -> void:
	if split:
		split.split_offset = max(split.split_offset, 260)
	if left_pane:
		left_pane.visible = true
	if profile_overlay:
		profile_overlay.visible = false
	if souls_list:
		souls_list.visible = true
		souls_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		souls_list.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		souls_list.max_columns = 1
	if workbench:
		workbench.visible = workbench.visible  # keep designer default; we’ll show it on demand

# ---------- signals ----------
func _wire_signals() -> void:
	# Profile overlay -> Offer a deal
	if profile_overlay and not profile_overlay.is_connected("offer_deal_requested", Callable(self, "_on_offer_deal")):
		profile_overlay.offer_deal_requested.connect(_on_offer_deal)

	# Workbench -> contract finished
	if workbench and not workbench.is_connected("contract_ready", Callable(self, "_on_contract_ready")):
		workbench.contract_ready.connect(_on_contract_ready)

	# Souls list clicks (works even if SoulsPanel not attached)
	if souls_list:
		if not souls_list.item_selected.is_connected(_on_soul_pick):
			souls_list.item_selected.connect(_on_soul_pick)
		if not souls_list.item_activated.is_connected(_on_soul_pick):
			souls_list.item_activated.connect(_on_soul_pick)
		if not souls_list.item_clicked.is_connected(_on_soul_clicked):
			souls_list.item_clicked.connect(_on_soul_clicked)

	# Legacy SoulsPanel signal (if your SoulsPanel.gd still emits)
	if souls_panel and souls_panel.has_signal("soul_selected"):
		if not souls_panel.is_connected("soul_selected", Callable(self, "_on_soul_selected")):
			souls_panel.soul_selected.connect(_on_soul_selected)

# ---------- populate the list ----------
func _populate_souls_list() -> void:
	if souls_list == null:
		push_error("[Main] SoulsList not found. Make sure LeftPane contains an ItemList named 'SoulsList'.")
		return
	# ensure data exists
	if GameDB and GameDB.has_method("seed_if_empty"):
		GameDB.seed_if_empty()
	souls_list.clear()
	var n := GameDB.index_count()
	for i in range(n):
		souls_list.add_item(GameDB.name_by_index(i))
	print("[Main] souls in list:", souls_list.item_count)

# ---------- list handlers ----------
func _on_soul_pick(index: int) -> void:
	_open_profile_or_craft(index)

func _on_soul_clicked(index: int, _pos: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_open_profile_or_craft(index)

func _on_soul_selected(index: int) -> void:
	_open_profile_or_craft(index)

func _open_profile_or_craft(index: int) -> void:
	print("[Main] pick -> index:", index)
	if profile_overlay and profile_overlay.has_method("start_for"):
		profile_overlay.call("start_for", index)
	else:
		_on_offer_deal(index)  # fallback straight to workbench if no overlay

# ---------- profile -> workbench ----------
func _on_offer_deal(index: int) -> void:
	if profile_overlay and profile_overlay.has_method("close"):
		profile_overlay.call("close")
	if left_pane:
		left_pane.visible = false
	if workbench:
		workbench.visible = true
	_switch_to_tab_control(workbench)
	if workbench and workbench.has_method("set_current_soul"):
		workbench.call("set_current_soul", index)
	else:
		push_warning("[Main] Workbench.set_current_soul(index) not found.")

# ---------- finish -> ongoing ----------
func _on_contract_ready(_i: int, _o: Array[String], _a: Array[String], _c: Array[String], _p: float) -> void:
	if left_pane:
		left_pane.visible = true
	_switch_to_tab_named("Ongoing")

# ---------- tab helpers ----------
func _switch_to_tab_control(ctrl: Control) -> void:
	if right_tabs == null or ctrl == null: return
	for i in range(right_tabs.get_tab_count()):
		if right_tabs.get_tab_control(i) == ctrl:
			right_tabs.current_tab = i
			return

func _switch_to_tab_named(name: String) -> void:
	if right_tabs == null: return
	for i in range(right_tabs.get_tab_count()):
		var c := right_tabs.get_tab_control(i)
		if c and c.name == name:
			right_tabs.current_tab = i
			return
