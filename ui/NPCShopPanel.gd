extends Control
class_name NPCShopPanel

@onready var rows: VBoxContainer = $"ScrollContainer/Rows"
@onready var row_template: Control = $"ScrollContainer/Rows/RowTemplate"

@export var cost_mephisto: CostBundle
@export var cost_taura:    CostBundle
@export var cost_asmodea:  CostBundle
@export var cost_jackie:   CostBundle

func _ready() -> void:
	_ensure_cost_defaults()
	_build_rows()
	if not Economy.balance_changed.is_connected(_on_bal): Economy.balance_changed.connect(_on_bal)
	if not NPCManager.npc_hired.is_connected(_on_hired): NPCManager.npc_hired.connect(_on_hired)
	_refresh_all()

func _ensure_cost_defaults() -> void:
	if cost_mephisto == null:
		cost_mephisto = CostBundle.new(); cost_mephisto.money = 600; cost_mephisto.ore = 10; cost_mephisto.souls = 1
	if cost_taura == null:
		cost_taura = CostBundle.new();    cost_taura.money = 400;    cost_taura.ore = 25;    cost_taura.souls = 0
	if cost_asmodea == null:
		cost_asmodea = CostBundle.new();  cost_asmodea.money = 500;  cost_asmodea.ore = 0;   cost_asmodea.souls = 1
	if cost_jackie == null:
		cost_jackie = CostBundle.new();   cost_jackie.money = 300;   cost_jackie.ore = 0;    cost_jackie.souls = 0

func _build_rows() -> void:
	if rows == null: return
	for c in rows.get_children(): c.queue_free()
	if row_template != null: row_template.visible = false

	_make_row("mephisto", "Mephisto — hunts debtors (reduces defaults / recovers funds)", cost_mephisto)
	_make_row("taura",    "Taura — big ore boost in mines (+flat ore/day)",               cost_taura)
	_make_row("asmodea",  "Asmodea — +50% casino income",                                  cost_asmodea)
	_make_row("jackie",   "Jackie — increases Producer power (unlock National)",           cost_jackie)

func _make_row(id: String, desc: String, cost: CostBundle) -> void:
	var row: Control
	if row_template != null:
		row = row_template.duplicate() as Control
		row.visible = true
	else:
		row = PanelContainer.new()
	row.set_meta("npc_id", id)
	rows.add_child(row)

	var name_lbl := row.get_node("VBoxContainer/HBoxContainer/Name") as Label
	var owned_lbl := row.get_node("VBoxContainer/HBoxContainer/Owned") as Label
	var desc_lbl  := row.get_node("VBoxContainer/Desc") as Label
	var cost_lbl  := row.get_node("VBoxContainer/Cost") as Label
	var hire_btn  := row.get_node("VBoxContainer/Hire") as Button

	if name_lbl != null: name_lbl.text = id.capitalize()
	if owned_lbl != null: owned_lbl.text = ""
	if desc_lbl != null: desc_lbl.text = desc
	if cost_lbl != null: cost_lbl.text = _cost_text(cost)
	if hire_btn != null:
		hire_btn.pressed.connect(func() -> void:
			var ok := NPCManager.hire(id, cost)
			if not ok: hire_btn.tooltip_text = "Already owned or cannot afford."
			_refresh_row(row)
		)

	_refresh_row(row)

func _refresh_all() -> void:
	if rows == null: return
	for row in rows.get_children():
		_refresh_row(row as Control)

func _refresh_row(row: Control) -> void:
	var id := String(row.get_meta("npc_id"))
	var owned := NPCManager.is_hired(id)
	var cost := _cost_for(id)

	var owned_lbl := row.get_node("VBoxContainer/HBoxContainer/Owned") as Label
	var cost_lbl  := row.get_node("VBoxContainer/Cost") as Label
	var hire_btn  := row.get_node("VBoxContainer/Hire") as Button

	if owned_lbl != null:
		owned_lbl.text = "Owned" if owned else ""

	if cost_lbl != null:
		cost_lbl.text = _cost_text(cost)

	if hire_btn != null:
		var can_afford := Economy.can_afford(cost)
		var disabled := owned or (not can_afford)
		hire_btn.disabled = disabled
		if disabled:
			hire_btn.tooltip_text = "Already owned" if owned else "Cannot afford"
		else:
			hire_btn.tooltip_text = ""

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
	var out := ""
	for i in range(parts.size()):
		out += parts[i]
		if i < parts.size() - 1: out += "  •  "
	return out

func _on_bal(_c: int, _v: int) -> void: _refresh_all()
func _on_hired(_id: String) -> void: _refresh_all()
