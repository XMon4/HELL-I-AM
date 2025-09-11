extends Control

signal contract_ready(
	soul_index: int,
	offers: Array[String],
	asks: Array[String],
	clauses: Array[String],
	acceptance: float
)

# LEFT: sections under parchment (paths per your scene)
@onready var sec_offer: ContractSection  = $WB_VBox/WB_Rows/ScrollHolder/Parchment/ContractScroll/Scroll/ContractBox/Section_Offer
@onready var sec_ask: ContractSection    = $WB_VBox/WB_Rows/ScrollHolder/Parchment/ContractScroll/Scroll/ContractBox/Section_Ask
@onready var sec_clause: ContractSection = $WB_VBox/WB_Rows/ScrollHolder/Parchment/ContractScroll/Scroll/ContractBox/Section_Clause

# RIGHT: options panel
@onready var options_title: Label            = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/OptionsTitle
@onready var options_scroll: ScrollContainer = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll
@onready var options_box: VBoxContainer      = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll/OptionsBox
@onready var hint_label: Label               = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Hint

# FOOTER
@onready var bar: ProgressBar = $WB_VBox/WB_Footer/AcceptanceBar
@onready var finish_btn: Button = $WB_VBox/WB_Footer/Button

var current_index: int = -1
var offers: Array[String] = []
var asks: Array[String] = []
var clauses: Array[String] = []
var clause_meta: Array[Dictionary] = []   # keeps id/params/label for clauses

var _current_panel_key: String = ""       # "offer" | "ask" | "clause"

# visual lists on parchment (under each section header)
var _offer_list: VBoxContainer
var _ask_list: VBoxContainer
var _clause_list: VBoxContainer

func _ready() -> void:
	if sec_offer:  sec_offer.section_key  = "offer"
	if sec_ask:    sec_ask.section_key    = "ask"
	if sec_clause: sec_clause.section_key = "clause"
	_ensure_options_layout()

	# build selected-lists under each section so the player can see & remove picks
	_make_selected_lists()
	_refresh_selected_lists()

	for s in [sec_offer, sec_ask, sec_clause]:
		if s == null:
			push_error("Workbench: a ContractSection node is missing.")
			continue
		if not s.is_connected("header_clicked", Callable(self, "_on_section_header_clicked")):
			s.header_clicked.connect(_on_section_header_clicked)
		if not s.is_connected("items_changed", Callable(self, "_on_section_items_changed")):
			s.items_changed.connect(_on_section_items_changed)

	if not finish_btn.is_connected("pressed", Callable(self, "_on_finish")):
		finish_btn.pressed.connect(_on_finish)

	_show_hint("Tap Offer / Ask / Clauses to see options.")
	_refresh_accept()
	_validate()

	# --- connect daily limit to button label ---
	if ContractLimits and not ContractLimits.contracts_count_changed.is_connected(_on_contracts_remaining_changed):
		ContractLimits.contracts_count_changed.connect(_on_contracts_remaining_changed)
		_on_contracts_remaining_changed(ContractLimits.remaining_today)  # show current count

	# open an options panel by default
	call_deferred("_show_options_for", "offer")

# Ensures scroll + box actually occupy space (prevents zero-size collapse)
func _ensure_options_layout() -> void:
	if options_scroll:
		options_scroll.visible = true
		options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	if options_box:
		options_box.visible = true
		options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		if options_box.custom_minimum_size.x < 520.0:
			options_box.custom_minimum_size = Vector2(520, 0)

# ---------- Selected lists under each section ----------
func _make_selected_lists() -> void:
	_offer_list  = _ensure_list_under(sec_offer)
	_ask_list    = _ensure_list_under(sec_ask)
	_clause_list = _ensure_list_under(sec_clause)

func _ensure_list_under(section: Control) -> VBoxContainer:
	if section == null: return null
	var list := section.get_node_or_null("SelectedList") as VBoxContainer
	if list == null:
		list = VBoxContainer.new()
		list.name = "SelectedList"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 4)
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.07, 0.07, 0.75)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 6; sb.content_margin_right = 6
		sb.content_margin_top  = 4; sb.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", sb)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(list)
		section.add_child(panel)
	return list

func _refresh_selected_lists() -> void:
	# Offer
	_clear_children(_offer_list)
	for t in offers:
		_offer_list.add_child(_make_selected_row("offer", t))
	# Ask
	_clear_children(_ask_list)
	for t in asks:
		_ask_list.add_child(_make_selected_row("ask", t))
	# Clauses
	_clear_children(_clause_list)
	for t in clauses:
		_clause_list.add_child(_make_selected_row("clause", t))

func _make_selected_row(key: String, label_text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var dot := Label.new(); dot.text = "• "
	var lbl := Label.new(); lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var remove := Button.new()
	remove.text = "✕ Remove"
	remove.focus_mode = Control.FOCUS_NONE
	remove.pressed.connect(func() -> void:
		_remove_item_from_section(key, label_text)
	)

	hb.add_child(dot)
	hb.add_child(lbl)
	hb.add_child(remove)
	return hb

# Called by outer controller
func set_current_soul(index: int) -> void:
	current_index = index
	offers.clear(); asks.clear(); clauses.clear(); clause_meta.clear()
	_reset_sections()
	_refresh_selected_lists()
	_refresh_accept(); _validate()
	_show_hint("Choose a section to view options for this person.")
	# UX: jump to Ask for the selected human
	_show_options_for("ask")

func reset() -> void:
	current_index = -1
	offers.clear(); asks.clear(); clauses.clear(); clause_meta.clear()
	_reset_sections()
	_refresh_selected_lists()
	_refresh_accept(); _validate()
	_show_hint("Tap Offer / Ask / Clauses to see options.")
	_show_options_for("offer")

# --- sections & options ---
func _on_section_header_clicked(key: String) -> void:
	_show_options_for(key)

func _on_section_items_changed(key: String, items: Array[String], meta: Array[Dictionary]) -> void:
	match key:
		"offer":  offers  = items.duplicate()
		"ask":    asks    = items.duplicate()
		"clause":
			clauses = items.duplicate()
			clause_meta = meta.duplicate()
	_refresh_selected_lists()
	_refresh_accept()
	_validate()
	if _current_panel_key != "":
		_show_options_for(_current_panel_key) # refresh Add/Remove states

func _show_hint(text: String) -> void:
	options_title.text = "Options"
	hint_label.visible = true
	hint_label.text = text
	options_scroll.visible = false
	_clear_children(options_box)

func _show_options_for(key: String) -> void:
	var k := key.strip_edges().to_lower()
	if k != "offer" and k != "ask" and k != "clause":
		push_warning("Workbench: unknown section key '%s' (ignoring)" % key)
		return
	_current_panel_key = k

	_clear_children(options_box)

	match k:
		"offer":
			options_title.text = "What You Can Offer"
			for text in GameDB.list_player_offers():
				options_box.add_child(_make_simple_option_button(text, "offer"))
		"ask":
			options_title.text = "What You Can Ask For"
			if current_index < 0:
				_show_hint("Select a human first.")
				return
			for text in GameDB.list_soul_asks(GameDB.id_by_index(current_index)):
				options_box.add_child(_make_simple_option_button(text, "ask"))
		"clause":
			options_title.text = "Clauses & Conditions"
			var catalog: Array[Dictionary] = GameDB.get_clause_catalog()
			if catalog.is_empty():
				_show_hint("No options available in the clause catalog.")
				return
			for cdef in catalog:
				var id := String(cdef.get("id",""))
				if _clause_id_taken(id):
					options_box.add_child(_wrap_panel(_clause_taken_row(cdef)))
				else:
					options_box.add_child(_wrap_panel(_build_clause_widget(cdef)))

	hint_label.visible = false
	options_scroll.visible = true
	_ensure_options_layout()
	options_box.queue_sort()
	options_scroll.queue_redraw()

func _make_simple_option_button(text: String, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Disable if already selected; enabled again after you remove from parchment
	if _is_selected(key, text):
		b.disabled = true
	b.pressed.connect(func() -> void:
		match key:
			"offer":  sec_offer.add_item(text)
			"ask":    sec_ask.add_item(text)
		b.disabled = true   # immediate feedback; items_changed will also refresh UI
	)
	return b

func _is_selected(key: String, label: String) -> bool:
	match key:
		"offer":  return offers.has(label)
		"ask":    return asks.has(label)
		"clause": return clauses.has(label)
		_:        return false

# --- Clause widgets ---
func _build_clause_widget(cdef: Dictionary) -> Control:
	var ui_type := String(cdef.get("ui","button"))
	match ui_type:
		"percent": return _clause_percent_widget(cdef)
		"choice":  return _clause_choice_widget(cdef)
		_:         return _clause_button_widget(cdef)

func _clause_button_widget(cdef: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	var lbl := Label.new(); lbl.text = String(cdef.get("label","Clause"))
	var add := Button.new(); add.text = "Add"
	add.pressed.connect(func() -> void:
		var label := _format_clause_label(cdef, {})
		sec_clause.add_item(label, {"id": String(cdef.get("id","")), "params": {}, "label": label})
	)
	vb.add_child(lbl); vb.add_child(add)
	return vb

func _clause_percent_widget(cdef: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	var title := Label.new(); title.text = "Satan will charge a percentage of earnings"
	var hb := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = int(cdef.get("min",10))
	slider.max_value = int(cdef.get("max",100))
	slider.step = int(cdef.get("step",10))
	slider.value = slider.min_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new(); val.text = "%d%%" % int(slider.value)
	slider.value_changed.connect(func(v: float) -> void: val.text = "%d%%" % int(v))
	var add := Button.new(); add.text = "Add"
	add.pressed.connect(func() -> void:
		var params := {"percent": int(slider.value)}
		var label := _format_clause_label(cdef, params)
		sec_clause.add_item(label, {"id": String(cdef.get("id","")), "params": params, "label": label})
	)
	hb.add_child(slider); hb.add_child(val); hb.add_child(add)
	vb.add_child(title); vb.add_child(hb)
	return vb

func _clause_choice_widget(cdef: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	var title := Label.new(); title.text = String(cdef.get("label","Choose"))
	var hb := HBoxContainer.new()
	var ob := OptionButton.new()
	for i in cdef.get("choices", []):
		ob.add_item(String(i))
	var add := Button.new(); add.text = "Add"
	add.pressed.connect(func() -> void:
		var idx: int = ob.selected
		if idx < 0: idx = 0
		var choice: String = ob.get_item_text(idx)
		var params := {"choice": choice}
		var label := _format_clause_label(cdef, params)
		sec_clause.add_item(label, {"id": String(cdef.get("id","")), "params": params, "label": label})
	)
	hb.add_child(ob); hb.add_child(add)
	vb.add_child(title); vb.add_child(hb)
	return vb

# if already added, show a compact "Added / Remove" row
func _clause_taken_row(cdef: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	var title := Label.new(); title.text = String(cdef.get("label","Clause"))
	var hb := HBoxContainer.new()
	var tag := Label.new(); tag.text = "Added"
	var remove := Button.new(); remove.text = "Remove"
	remove.pressed.connect(func() -> void:
		_remove_clause_by_id(String(cdef.get("id","")))
	)
	hb.add_child(tag); hb.add_child(remove)
	vb.add_child(title); vb.add_child(hb)
	return vb

func _remove_clause_by_id(id: String) -> void:
	# rebuild the clause section without the given id
	var new_meta: Array[Dictionary] = []
	for m in clause_meta:
		if String(m.get("id","")) != id:
			new_meta.append(m)
	# clear then re-add
	if sec_clause and sec_clause.has_method("set_items"):
		var empty: Array[Dictionary] = []
		sec_clause.set_items(empty)
	for m in new_meta:
		sec_clause.add_item(String(m.get("label","Clause")), m)
	# items_changed will sync arrays & refresh UI

func _clause_id_taken(id: String) -> bool:
	for m in clause_meta:
		if String(m.get("id","")) == id:
			return true
	return false

func _format_clause_label(cdef: Dictionary, params: Dictionary) -> String:
	var id := String(cdef.get("id",""))
	match id:
		"tithe_percent":
			return "Tithe: Satan charges %d%% of earnings" % int(params.get("percent", 10))
		"no_returns":
			return "No Returns: If signer returns the item, Satan keeps his"
		"maintenance_evil_act":
			return "Maintenance: evil act every %s" % String(params.get("choice","Week"))
		"death_void":
			return "Death Clause: Contract is void (+40 trust)"
		"death_soul":
			return "Death Clause: Satan takes soul (+40 suspicion)"
		_:
			return "%s%s" % [
				String(cdef.get("label","Condition")),
				(" — %s" % String(params.get("choice",""))) if params.has("choice") else ""
			]

# --- acceptance / finish ---
func _refresh_accept() -> void:
	if current_index < 0:
		bar.value = 0
		bar.tooltip_text = "Select a human to begin."
		return
	var traits: Dictionary = GameDB.traits_by_index(current_index)
	var p: float = ContractManager.evaluate(offers.duplicate(), asks.duplicate(), clauses.duplicate(), traits)
	bar.value = int(round(p * 100.0))
	bar.tooltip_text = "%d%%" % int(bar.value)
	
func _on_contracts_remaining_changed(remaining: int) -> void:
	if finish_btn:
		finish_btn.text = "Finish (%d left today)" % int(remaining)
	_validate()

func _validate() -> void:
	var ok := (current_index >= 0) and (offers.size() > 0) and (asks.size() > 0) and (clauses.size() > 0)
	if ok and ContractLimits and not ContractLimits.can_start():
		ok = false
		if finish_btn:
			finish_btn.tooltip_text = "No more contracts today. Press Next Day."
	else:
		if finish_btn:
			finish_btn.tooltip_text = ""
	if finish_btn:
		finish_btn.disabled = not ok

func _on_finish() -> void:
	# daily limit gate
	if ContractLimits and not ContractLimits.consume_one():
		_show_hint("You've reached today's contract limit. Press Next Day.")
		_validate()
		return

	var p: float = float(bar.value) / 100.0

	# --- ECONOMY EFFECTS ---
	# Deduct offered Money (strings like "Money: $1000" or "Money: 1000")
	for o in offers:
		var s := String(o)
		if s.begins_with("Money"):
			var n := _extract_int(s)
			if n > 0:
				Economy.add(Economy.Currency.MONEY, -n)

	# Grant asked resources
	for a in asks:
		var s2 := String(a)
		if s2.begins_with("Soul"):
			Economy.add(Economy.Currency.SOULS, 1)
		elif s2.begins_with("Money"):
			var m := _extract_int(s2)
			if m > 0:
				Economy.add(Economy.Currency.MONEY, m)

	# --- persist and remove human (your existing flow) ---
	var sid := GameDB.id_by_index(current_index)
	var sname := GameDB.name_by_index(current_index)
	var contract := {
		"soul_id": sid,
		"name": sname,
		"offers": offers.duplicate(),
		"asks": asks.duplicate(),
		"clauses": clauses.duplicate(),
		"acceptance": p
	}
	GameDB.add_contract(contract)
	GameDB.remove_soul_by_index(current_index)

	emit_signal("contract_ready", current_index, offers.duplicate(), asks.duplicate(), clauses.duplicate(), p)

	var ongoing := get_node_or_null("../Ongoing")
	if ongoing and ongoing.has_method("add_contract_entry"):
		ongoing.add_contract_entry(sname, offers.duplicate(), asks.duplicate(), clauses.duplicate())

	reset()

# --- helpers ---
func _sections() -> Array:
	return [sec_offer, sec_ask, sec_clause]

func _reset_sections() -> void:
	for s in _sections():
		if s == null:
			continue
		if s.has_method("set_items"):
			# IMPORTANT: pass a *typed* empty array to match ContractSection.set_items(Array[Dictionary])
			var empty: Array[Dictionary] = []
			s.set_items(empty)
		elif s.has_method("clear"):
			s.clear()

func _clear_children(node: Node) -> void:
	if node == null: return
	for c in node.get_children():
		c.queue_free()

# remove from parchment (Offer/Ask/Clause)
func _remove_item_from_section(key: String, label: String) -> void:
	match key:
		"offer":
			# rebuild the offer section without this label
			var keep: Array[String] = []
			for t in offers:
				if t != label:
					keep.append(t)
			if sec_offer and sec_offer.has_method("set_items"):
				var empty: Array[Dictionary] = []
				sec_offer.set_items(empty)
			for t in keep:
				sec_offer.add_item(t)

		"ask":
			var keep2: Array[String] = []
			for t2 in asks:
				if t2 != label:
					keep2.append(t2)
			if sec_ask and sec_ask.has_method("set_items"):
				var empty2: Array[Dictionary] = []
				sec_ask.set_items(empty2)
			for t2 in keep2:
				sec_ask.add_item(t2)

		"clause":
			# find by label in meta and rebuild
			var keep_meta: Array[Dictionary] = []
			for m in clause_meta:
				if String(m.get("label","")) != label:
					keep_meta.append(m)
			if sec_clause and sec_clause.has_method("set_items"):
				var empty3: Array[Dictionary] = []
				sec_clause.set_items(empty3)
			for m in keep_meta:
				sec_clause.add_item(String(m.get("label","Clause")), m)

	# items_changed will sync arrays, refresh lists, and re-enable options
	
	# Wrap widgets in a styled panel so they don't collapse and look consistent
func _wrap_panel(child: Control) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.10, 0.85)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.25, 0.25, 0.9)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6

	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(child)
	return panel
	
func _extract_int(text: String) -> int:
	var digits := ""
	var n := text.length()
	for i in range(n):
		# use substr to ensure a 1-char String
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			# stop at first non-digit after we've started collecting
			break
	if digits == "":
		return 0
	return int(digits)
