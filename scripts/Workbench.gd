extends Control

signal contract_ready(
	soul_index: int,
	offers: Array[String],
	asks: Array[String],
	clauses: Array[String],
	acceptance: float
)

# --- Stat bars
@onready var susp_slider: Range      = $"BarsDock/SuspSlider"
@onready var trust_slider: Range     = $"BarsDock/TrustSlider"
@onready var susp_value_lbl: Label   = $"BarsDock/Susp_Row/SuspValue"
@onready var trust_value_lbl: Label  = $"BarsDock/Trust_Row/TrustValue"

# LEFT: sections under parchment
@onready var sec_offer: ContractSection  = $WB_VBox/WB_Rows/ScrollHolder/Parchment/ContractScroll/Scroll/ContractBox/Section_Offer
@onready var sec_ask: ContractSection    = $WB_VBox/WB_Rows/ScrollHolder/Parchment/ContractScroll/Scroll/ContractBox/Section_Ask
@onready var sec_clause: ContractSection = $WB_VBox/WB_Rows/ScrollHolder/Parchment/ContractScroll/Scroll/ContractBox/Section_Clause

# RIGHT: options panel
@onready var options_title: Label            = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/OptionsTitle
@onready var options_scroll: ScrollContainer = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll
@onready var options_box: VBoxContainer      = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll/OptionsBox
@onready var header: HBoxContainer           = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll/OptionsBox/Header
@onready var btn_clauses: Button             = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll/OptionsBox/Header/BtnClauses
@onready var btn_conditions: Button          = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll/OptionsBox/Header/BtnConditions
@onready var list_holder: VBoxContainer      = $WB_VBox/WB_Rows/OptionsPanel/VBoxContainer/Scroll/OptionsBox/ListHolder
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

# visual lists on parchment
var _offer_list: VBoxContainer
var _ask_list: VBoxContainer
var _clause_list: VBoxContainer

func _ready() -> void:
	if sec_offer:  sec_offer.section_key  = "offer"
	if sec_ask:    sec_ask.section_key    = "ask"
	if sec_clause: sec_clause.section_key = "clause"
	_ensure_options_layout()
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
	if bar:
		bar.visible = false
		bar.tooltip_text = ""

	if susp_slider:
		susp_slider.min_value = 0
		susp_slider.max_value = 100
	if trust_slider:
		trust_slider.min_value = 0
		trust_slider.max_value = 100

	_show_hint("Tap Offer / Ask / Clauses to see options.")
	_refresh_accept()
	_validate()

	# tabs behavior (scene-defined buttons)
	if not btn_clauses.is_connected("pressed", Callable(self, "_on_btn_clauses")):
		btn_clauses.pressed.connect(_on_btn_clauses)
	if not btn_conditions.is_connected("pressed", Callable(self, "_on_btn_conditions")):
		btn_conditions.pressed.connect(_on_btn_conditions)

	_show_hint("Tap Offer / Ask / Clauses to see options.")
	_refresh_accept()
	_validate()

	if ContractLimits and not ContractLimits.contracts_count_changed.is_connected(_on_contracts_remaining_changed):
		ContractLimits.contracts_count_changed.connect(_on_contracts_remaining_changed)
		_on_contracts_remaining_changed(ContractLimits.remaining_today)

	call_deferred("_show_options_for", "offer")

# ---- layout helpers ----
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
	_clear_children(_offer_list)
	for t in offers:
		_offer_list.add_child(_make_selected_row("offer", t))
	_clear_children(_ask_list)
	for t in asks:
		_ask_list.add_child(_make_selected_row("ask", t))
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
	hb.add_child(dot); hb.add_child(lbl); hb.add_child(remove)
	return hb

# Called by outer controller
func set_current_soul(index: int) -> void:
	current_index = index
	offers.clear(); asks.clear(); clauses.clear(); clause_meta.clear()
	_reset_sections()
	_refresh_selected_lists()
	_refresh_accept(); _validate()
	_show_hint("Choose a section to view options for this person.")
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
		_show_options_for(_current_panel_key)

func _show_hint(text: String) -> void:
	options_title.text = "Options"
	hint_label.visible = true
	hint_label.text = text
	options_scroll.visible = false
	header.visible = false
	_clear_children(list_holder)

func _show_options_for(key: String) -> void:
	var k := key.strip_edges().to_lower()
	if k != "offer" and k != "ask" and k != "clause":
		push_warning("Workbench: unknown section key '%s' (ignoring)" % key)
		return
	_current_panel_key = k

	hint_label.visible = false
	options_scroll.visible = true
	_ensure_options_layout()
	_clear_children(list_holder)

	match k:
		"offer":
			header.visible = false
			options_title.text = "What You Can Offer"
			for text in GameDB.list_player_offers():
				if text.begins_with("Money"):
					list_holder.add_child(_wrap_panel(	_money_offer_widget()))
				else:
					list_holder.add_child(_make_simple_option_button(text, "offer"))
		"ask":
			header.visible = false
			options_title.text = "What You Can Ask For"
			if current_index < 0:
				_show_hint("Select a human first.")
				return
			for text in GameDB.list_soul_asks(GameDB.id_by_index(current_index)):
				list_holder.add_child(_make_simple_option_button(text, "ask"))

		"clause":
			header.visible = true
			options_title.text = "Clauses & Conditions"
			# default tab = CLAUSES
			_switch_clause_tab(false)

	options_box.queue_sort()
	options_scroll.queue_redraw()

func _money_offer_widget() -> Control:
	var vb := VBoxContainer.new()
	var title := Label.new(); title.text = "Offer Money (±10,000)"
	var hb := HBoxContainer.new()

	var max_money := Economy.get_balance(Economy.Currency.MONEY) if Economy else int(GameDB.player_inventory.get("Money", 0))
	var offer := 0

	var minus := Button.new(); minus.text = "-10k"
	var value := Label.new(); value.text = "$0"; value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plus  := Button.new(); plus.text  = "+10k"
	var apply := Button.new(); apply.text = "Offer"

	# local callable instead of a nested func
	var refresh := func() -> void:
		minus.disabled = offer <= 0
		plus.disabled  = offer + 10_000 > max_money
		value.text = "$" + str(offer)

	minus.pressed.connect(func() -> void:
		offer = max(0, offer - 10_000)
		refresh.call()
	)
	plus.pressed.connect(func() -> void:
		offer = min(max_money, offer + 10_000)
		refresh.call()
	)
	apply.pressed.connect(func() -> void:
		_upsert_money_offer(offer)  # ensures only one Money line exists
	)

	hb.add_child(minus)
	hb.add_child(value)
	hb.add_child(plus)
	hb.add_child(apply)
	vb.add_child(title)
	vb.add_child(hb)

	refresh.call()
	return vb

func _upsert_money_offer(amount:int) -> void:
	# Remove any previous "Money:" entry, then add the new one (or none if 0)
	sec_offer.remove_by_prefix("Money")
	if amount > 0:
		sec_offer.add_item("Money: $" + str(amount))

# --------- header tab behavior ---------
func _on_btn_clauses() -> void:
	_switch_clause_tab(false)

func _on_btn_conditions() -> void:
	_switch_clause_tab(true)

func _switch_clause_tab(show_conditions: bool) -> void:
	btn_clauses.button_pressed = not show_conditions
	btn_conditions.button_pressed = show_conditions
	_populate_clause_list(show_conditions)

func _populate_clause_list(show_conditions: bool) -> void:
	_clear_children(list_holder)
	var cat := "condition" if show_conditions else "clause"
	var catalog: Array[Dictionary] = GameDB.get_catalog_by_category(cat)
	if catalog.is_empty():
		var lbl := Label.new(); lbl.text = "No options available."
		list_holder.add_child(lbl)
		return

	for cdef in catalog:
		var id := String(cdef.get("id",""))
		if _clause_id_taken(id):
			list_holder.add_child(_wrap_panel(_clause_taken_row(cdef)))
		else:
			list_holder.add_child(_wrap_panel(_build_clause_widget(cdef)))

# ---------- add buttons ----------
func _make_simple_option_button(text: String, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _is_selected(key, text): b.disabled = true
	b.pressed.connect(func() -> void:
		match key:
			"offer":  sec_offer.add_item(text)
			"ask":    sec_ask.add_item(text)
		b.disabled = true
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
	var new_meta: Array[Dictionary] = []
	for m in clause_meta:
		if String(m.get("id","")) != id:
			new_meta.append(m)
	if sec_clause and sec_clause.has_method("set_items"):
		var empty: Array[Dictionary] = []
		sec_clause.set_items(empty)
	for m in new_meta:
		sec_clause.add_item(String(m.get("label","Clause")), m)

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
	# --- compute Trust/Susp from selections
	var trust_f := 0.0
	var susp_f  := 0.0

	if current_index >= 0 and current_index < GameDB.index_count():
		var human: Dictionary = GameDB.souls[current_index]
		var eq: Array[String] = []
		if GameDB and GameDB.has_method("get_equipped_traits"):
			eq = GameDB.get_equipped_traits()

		var st: Dictionary = ContractManager.compute_bars(
			offers.duplicate(), asks.duplicate(), clauses.duplicate(),
			human, eq
		)
		trust_f = float(st.get("trust", 0.0))
		susp_f  = float(st.get("suspicion", 0.0))

	# Clamp to 0..100 and push to UI
	var trust_i := clampi(int(round(trust_f)), 0, 100)
	var susp_i  := clampi(int(round(susp_f)),  0, 100)

	if trust_slider:     trust_slider.value = trust_i
	if susp_slider:      susp_slider.value  = susp_i
	if trust_value_lbl:  trust_value_lbl.text = str(trust_i)
	if susp_value_lbl:   susp_value_lbl.text  = str(susp_i)

	# --- keep computing acceptance for internal use
	var p := 0.0
	if current_index >= 0:
		var traits: Dictionary = GameDB.traits_by_index(current_index)
		p = ContractManager.evaluate(offers.duplicate(), asks.duplicate(), clauses.duplicate(), traits)

	if bar:
		bar.value = int(round(p * 100.0))

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
	if ContractLimits and not ContractLimits.consume_one():
		_show_hint("You've reached today's contract limit. Press Next Day.")
		_validate()
		return

	var p: float = float(bar.value) / 100.0

	# --- ECONOMY EFFECTS ---
	for o in offers:
		var s := String(o)
		if s.begins_with("Money"):
			var n := _extract_int(s)
			if n > 0:
				Economy.add(Economy.Currency.MONEY, -n)

	for a in asks:
		var s2 := String(a)
		if s2.begins_with("Soul"):
			GameDB.add_souls(1)     
		elif s2.begins_with("Money"):
			var m := _extract_int(s2)
			if m > 0:
				Economy.add(Economy.Currency.MONEY, m)
	for a in asks:
		var s2 := String(a)
		if s2.begins_with("Soul"):
			GameDB.add_souls(1)
		elif s2.begins_with("Money"):
			var m := _extract_int(s2)
			if m > 0:
				Economy.add(Economy.Currency.MONEY, m)
		elif s2.begins_with("Skill"):
			var label := s2.substr(s2.find(":") + 1).strip_edges()  # e.g. "Guitar Player (bronze)"
			var id := "skill:" + label.to_lower().replace(" ", "_")
			GameDB.give_skill(id)
		elif s2.begins_with("Trait"):
			var label := s2.substr(s2.find(":") + 1).strip_edges()  # e.g. "Charm (bronze)"
			var id := "trait:" + label.to_lower().replace(" ", "_")
			GameDB.give_trait(id)
			
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
	emit_signal("contract_ready", current_index, offers.duplicate(), asks.duplicate(), clauses.duplicate(), p)
	GameDB.remove_soul_by_index(current_index)

	reset()

# --- helpers ---
func _sections() -> Array:
	return [sec_offer, sec_ask, sec_clause]

func _reset_sections() -> void:
	for s in _sections():
		if s == null:
			continue
		if s.has_method("set_items"):
			var empty: Array[Dictionary] = []
			s.set_items(empty)
		elif s.has_method("clear"):
			s.clear()

func _clear_children(node: Node) -> void:
	if node == null: return
	for c in node.get_children():
		c.queue_free()

func _remove_item_from_section(key: String, label: String) -> void:
	match key:
		"offer":
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
			var keep_meta: Array[Dictionary] = []
			for m in clause_meta:
				if String(m.get("label","")) != label:
					keep_meta.append(m)
			if sec_clause and sec_clause.has_method("set_items"):
				var empty3: Array[Dictionary] = []
				sec_clause.set_items(empty3)
			for m in keep_meta:
				sec_clause.add_item(String(m.get("label","Clause")), m)

# wrap child in a styled panel
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
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	if digits == "":
		return 0
	return int(digits)
