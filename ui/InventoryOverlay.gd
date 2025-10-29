extends PanelContainer

@onready var flow: FlowContainer = $"VBoxContainer/ChipFlow"
@onready var equip_a: Button = $"VBoxContainer/EquipRow/EquipBtnA"
@onready var equip_b: Button = $"VBoxContainer/EquipRow/EquipBtnB"

func _ready() -> void:
	if GameDB and not GameDB.inventory_changed.is_connected(_refresh):
		GameDB.inventory_changed.connect(_refresh)
	equip_a.pressed.connect(_on_equip_a)
	equip_b.pressed.connect(_on_equip_b)
	_refresh()

func _refresh() -> void:
	equip_b.disabled = GameDB.max_trait_slots < 2
	for c in flow.get_children(): c.queue_free()

	# -- Persistent (top)
	var money: int = Economy.get_balance(Economy.Currency.MONEY) if Economy else int(GameDB.player_inventory.get("Money", 0))
	flow.add_child(_make_chip("MONEY: " + str(money), "money"))

	var souls_bal: int = Economy.get_balance(Economy.Currency.SOULS) if Economy else int(GameDB.souls_currency)
	flow.add_child(_make_chip("SOULS: " + str(souls_bal), "souls"))

	# -- Variable (bottom)
	# Skills
	for k in GameDB.skills_owned.keys():
		if GameDB.skills_owned[k]:
			flow.add_child(_make_chip(_pretty(k) + " (Skill)", "skill"))

	# Traits (click to toggle equip)
	for k in GameDB.traits_owned.keys():
		if GameDB.traits_owned[k]:
			var chip: Button = _make_chip(_pretty(k), "trait")
			if GameDB.equipped_traits.has(k): chip.text += " [EQUIPPED]"
			chip.pressed.connect(Callable(self, "_on_trait_chip").bind(k))
			flow.add_child(chip)

	# Fame goes last (treat as variable for now)
	var fame_on: bool = bool(GameDB.player_inventory.get("Fame", false))
	var fame_text: String = "Fame" if fame_on else "No Fame"
	flow.add_child(_make_chip(fame_text, "fame"))


func _make_chip(text: String, kind: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.toggle_mode = false

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6

	match kind:
		"money":
			sb.bg_color = Color(0.2, 0.6, 0.2, 0.9)
		"souls":
			sb.bg_color = Color(0.5, 0.3, 0.8, 0.9)
		"fame":
			sb.bg_color = Color(0.1, 0.7, 0.7, 0.9)
		"skill":
			sb.bg_color = Color(0.8, 0.2, 0.2, 0.9)
		"trait":
			sb.bg_color = Color(0.1, 0.6, 0.8, 0.9)
		_:
			sb.bg_color = Color(0.3, 0.3, 0.3, 0.9)

	b.add_theme_stylebox_override("normal", sb)
	return b

func _pretty(id: String) -> String:
	# "trait:charm_bronze" -> "Charm (bronze)"
	var parts: PackedStringArray = id.split(":")
	var name: String = parts[1] if parts.size() > 1 else id
	name = name.replace("_", " ")

	# Avoid pop_back on PackedStringArray; use rfind()
	var last_space: int = name.rfind(" ")
	if last_space >= 0:
		var first: String = name.substr(0, last_space)
		var last: String = name.substr(last_space + 1, name.length() - last_space - 1)

		var words: PackedStringArray = first.split(" ")
		var first_cap: String = ""
		for i in range(words.size()):
			if i > 0: first_cap += " "
			first_cap += String(words[i]).capitalize()
		return first_cap + " (" + last + ")"

	return name.capitalize()

func _on_trait_chip(trait_id: String) -> void:
	if GameDB.equipped_traits.has(trait_id):
		GameDB.unequip_trait(trait_id)
	else:
		var ok: bool = GameDB.equip_trait(trait_id)
		if not ok:
			# optional: show a toast
			pass

func _on_equip_a() -> void:
	_open_trait_picker(0)

func _on_equip_b() -> void:
	if GameDB.max_trait_slots >= 2:
		_open_trait_picker(1)

func _open_trait_picker(slot: int) -> void:
	for t in GameDB.traits_owned.keys():
		if GameDB.traits_owned[t] and not GameDB.equipped_traits.has(t):
			if GameDB.equip_trait(t):
				break
