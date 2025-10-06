extends Control
class_name NPCShopPanel

@onready var rows: VBoxContainer = $"ScrollContainer/Rows"
@onready var row_template: Control = $"ScrollContainer/Rows/RowTemplate"

@export var cost_mephisto: CostBundle
@export var cost_taura:    CostBundle
@export var cost_asmodea:  CostBundle
@export var cost_jackie:   CostBundle

func _ready() -> void:
	# Fallbacks if paths changed
	if rows == null:
		rows = _find_rows_container()
	if row_template == null:
		row_template = _find_row_template()
	_ensure_cost_defaults()
	_build_rows()
	if not Economy.balance_changed.is_connected(_on_bal):
		Economy.balance_changed.connect(_on_bal)
	if not NPCManager.npc_hired.is_connected(_on_hired):
		NPCManager.npc_hired.connect(_on_hired)
	_refresh_all()

# ---------- BUILD ----------

func _build_rows() -> void:
	if rows == null:
		push_error("NPCShopPanel: rows container not found. Name a VBox 'Rows' under the shop ScrollContainer (or give it a Unique Name and adjust).")
		return

	# Clear existing rows but KEEP the template if it lives under rows
	for child in rows.get_children():
		if row_template != null and child == row_template:
			continue
		child.queue_free()

	if row_template != null:
		row_template.visible = false

	# Add the four NPCs
	_make_row("mephisto", "Mephisto — hunts debtors (reduces defaults / recovers funds)", cost_mephisto)
	_make_row("taura",    "Taura — big ore boost in mines (+flat ore/day)",               cost_taura)
	_make_row("asmodea",  "Asmodea — +50% casino income",                                  cost_asmodea)
	_make_row("jackie",   "Jackie — increases Producer power (unlock National)",           cost_jackie)

func _make_row(id: String, desc: String, cost: CostBundle) -> void:
	var row: Control = _instantiate_row()
	row.visible = true
	row.set_meta("npc_id", id)
	rows.add_child(row)

	# Tolerant lookups (works with either template structure or the minimal row)
	var name_lbl: Label = row.get_node_or_null("VBoxContainer/HBoxContainer/Name") as Label
	if name_lbl == null: name_lbl = row.get_node_or_null("Name") as Label
	var owned_lbl: Label = row.get_node_or_null("VBoxContainer/HBoxContainer/Owned") as Label
	if owned_lbl == null: owned_lbl = row.get_node_or_null("Owned") as Label
	var desc_lbl: Label  = row.get_node_or_null("VBoxContainer/Desc") as Label
	if desc_lbl == null: desc_lbl = row.get_node_or_null("Desc") as Label
	var cost_lbl: Label  = row.get_node_or_null("VBoxContainer/Cost") as Label
	if cost_lbl == null: cost_lbl = row.get_node_or_null("Cost") as Label
	var hire_btn: Button = _find_hire_button(row)

	if name_lbl != null: name_lbl.text = id.capitalize()
	if owned_lbl != null: owned_lbl.text = ""
	if desc_lbl != null:
		desc_lbl.text = desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if cost_lbl != null:
		cost_lbl.text = _cost_text(cost)
	if hire_btn != null:
		hire_btn.text = "Hire" if hire_btn.text == "" else hire_btn.text
		hire_btn.tooltip_text = ""
		hire_btn.pressed.connect(func() -> void:
			var ok: bool = NPCManager.hire(id, cost)
			if not ok and hire_btn != null:
				hire_btn.tooltip_text = "Already owned or cannot afford."
			_refresh_row(row)
		)

	_refresh_row(row)

func _instantiate_row() -> Control:
	# Prefer duplicating a designer-made template; otherwise build a minimal row on the fly
	if row_template != null and is_instance_valid(row_template):
		var dup: Control = row_template.duplicate() as Control
		return dup
	return _build_minimal_row()

func _build_minimal_row() -> Control:
	# Creates a simple row that matches expected node names
	var root := PanelContainer.new()
	var v := VBoxContainer.new()
	var h := HBoxContainer.new()
	var name_lbl := Label.new(); name_lbl.name = "Name"
	var owned_lbl := Label.new(); owned_lbl.name = "Owned"
	h.add_child(name_lbl)
	h.add_child(owned_lbl)

	var desc_lbl := Label.new(); desc_lbl.name = "Desc"; desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var cost_lbl := Label.new(); cost_lbl.name = "Cost"
	var hire_btn := Button.new(); hire_btn.name = "Hire"; hire_btn.text = "Hire"

	v.add_child(h)
	v.add_child(desc_lbl)
	v.add_child(cost_lbl)
	v.add_child(hire_btn)
	root.add_child(v)
	return root

# ---------- REFRESH ----------

func _refresh_all() -> void:
	if rows == null: return
	for child in rows.get_children():
		if child is Control and (child as Control).has_meta("npc_id"):
			_refresh_row(child as Control)

func _refresh_row(row: Control) -> void:
	if not row.has_meta("npc_id"): return
	var id: String = String(row.get_meta("npc_id"))
	var owned: bool = NPCManager.is_hired(id)
	var cost: CostBundle = _cost_for(id)

	var owned_lbl: Label = row.get_node_or_null("VBoxContainer/HBoxContainer/Owned") as Label
	if owned_lbl == null: owned_lbl = row.get_node_or_null("Owned") as Label
	var cost_lbl: Label  = row.get_node_or_null("VBoxContainer/Cost") as Label
	if cost_lbl == null: cost_lbl = row.get_node_or_null("Cost") as Label
	var hire_btn: Button = _find_hire_button(row)

	if owned_lbl != null:
		owned_lbl.text = "Owned" if owned else ""

	if cost_lbl != null:
		cost_lbl.text = _cost_text(cost)

	if hire_btn != null:
		var can_afford: bool = Economy.can_afford(cost)
		var disabled: bool = owned or (not can_afford)
		hire_btn.disabled = disabled
		hire_btn.tooltip_text = "Already owned" if owned else ("" if can_afford else "Cannot afford")

# ---------- HELPERS ----------

func _find_hire_button(row: Node) -> Button:
	var b: Button = row.get_node_or_null("VBoxContainer/Hire") as Button
	if b != null: return b
	b = row.get_node_or_null("Hire") as Button
	if b != null: return b
	var any_node: Node = row.find_child("Hire", true, false)
	return any_node as Button

func _find_rows_container() -> VBoxContainer:
	# Try common locations, then fallback to a deep search
	var n: Node = get_node_or_null("ScrollContainer/Rows")
	if n == null: n = find_child("Rows", true, false)
	return n as VBoxContainer

func _find_row_template() -> Control:
	var n: Node = get_node_or_null("ScrollContainer/Rows/RowTemplate")
	if n == null and rows != null:
		n = rows.find_child("RowTemplate", true, false)
	return n as Control

func _cost_for(id: String) -> CostBundle:
	if id == "mephisto": return cost_mephisto
	if id == "taura":    return cost_taura
	if id == "asmodea":  return cost_asmodea
	if id == "jackie":   return cost_jackie
	return CostBundle.new()

func _cost_text(c: CostBundle) -> String:
	var parts: Array[String] = []
	if c.money > 0: parts.append("Money: %d" % c.money)
	if c.ore   > 0: parts.append("Ore: %d" % c.ore)
	if c.souls > 0: parts.append("Souls: %d" % c.souls)
	if parts.is_empty(): return "Free"
	var out: String = ""
	for i in range(parts.size()):
		out += parts[i]
		if i < parts.size() - 1:
			out += "  •  "
	return out

func _ensure_cost_defaults() -> void:
	if cost_mephisto == null:
		cost_mephisto = CostBundle.new(); cost_mephisto.money = 600; cost_mephisto.ore = 10; cost_mephisto.souls = 1
	if cost_taura == null:
		cost_taura    = CostBundle.new(); cost_taura.money    = 400; cost_taura.ore    = 25; cost_taura.souls    = 0
	if cost_asmodea == null:
		cost_asmodea  = CostBundle.new(); cost_asmodea.money  = 500; cost_asmodea.ore  = 0;  cost_asmodea.souls  = 1
	if cost_jackie == null:
		cost_jackie   = CostBundle.new(); cost_jackie.money   = 300; cost_jackie.ore   = 0;  cost_jackie.souls   = 0

func _on_bal(_c: int, _v: int) -> void:
	_refresh_all()

func _on_hired(_id: String) -> void:
	_refresh_all()
