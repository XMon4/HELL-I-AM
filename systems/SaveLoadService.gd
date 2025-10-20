extends Node
class_name SaveLoadService

signal game_saved(path: String)
signal game_loaded(state: Dictionary)

const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://savegame.json"

func save_game(path: String = DEFAULT_PATH) -> bool:
	var state: Dictionary = _collect_state()
	var json: String = JSON.stringify(state, "\t")

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveLoad: cannot open file for write: " + path)
		return false
	f.store_string(json)
	f.flush()
	f.close()
	game_saved.emit(path)
	return true


func load_game(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("SaveLoad: file does not exist: " + path)
		return false

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SaveLoad: cannot open file for read: " + path)
		return false
	var txt: String = f.get_as_text()
	f.close()

	var parser: JSON = JSON.new()
	var err: int = parser.parse(txt)
	if err != OK:
		push_error("SaveLoad: JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return false

	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveLoad: root is not a Dictionary")
		return false
	var state: Dictionary = data

	var ver: int = int(state.get("version", 0))
	if ver != SAVE_VERSION:
		push_warning("SaveLoad: version mismatch (have %d, file %d) — attempting best-effort restore." % [SAVE_VERSION, ver])

	_apply_state(state)
	game_loaded.emit(state)
	return true


# ---------- snapshot ----------
func _collect_state() -> Dictionary:
	var d: Dictionary = {}

	d["version"] = SAVE_VERSION

	# Day / ContractLimits
	var dc: Dictionary = {}
	dc["day"] = int(DayCycle.day)
	d["day_cycle"] = dc
	d["contract_limits"] = _snapshot_contract_limits()

	# Economy
	var eco: Dictionary = {}
	eco["money"] = int(Economy.get_balance(Economy.Currency.MONEY))
	eco["ore"]   = int(Economy.get_balance(Economy.Currency.ORE))
	eco["souls"] = int(Economy.get_balance(Economy.Currency.SOULS))
	d["economy"] = eco

	# Mines / Casino
	var mines: Dictionary = {}
	mines["souls_bound"] = int(Mines.souls_bound)
	mines["taura_owned"] = bool(Mines.taura_owned)
	d["mines"] = mines

	var casin: Dictionary = {}
	casin["asmodea_owned"] = bool(Casino.asmodea_owned)
	d["casino"] = casin

	# NPCs / Producer / Debt
	var hired_copy: Dictionary = {}
	for k in NPCManager.hired.keys():
		hired_copy[String(k)] = bool(NPCManager.hired[k])
	var npcs: Dictionary = {}
	npcs["hired"] = hired_copy
	d["npcs"] = npcs

	var prod: Dictionary = {}
	prod["tier"] = String(ProducerSystem.current_tier)
	d["producer"] = prod

	var debt: Dictionary = {}
	debt["mephisto_enabled"] = bool(DebtSystem.mephisto_enabled)
	d["debt"] = debt

	# Curses (optional autoload)
	var cur: Dictionary = {}
	if get_node_or_null("/root/Curses") != null:
		cur["count"] = int(Curses.count)
	else:
		cur["count"] = 0
	d["curses"] = cur

	# GameDB (souls + inventory/store + ongoing)
	var gdb: Dictionary = {}
	gdb["souls"]           = GameDB.souls
	gdb["souls_currency"]  = int(GameDB.souls_currency)   # mirror (Economy is canonical)
	gdb["max_trait_slots"] = int(GameDB.max_trait_slots)
	gdb["traits_owned"]    = GameDB.traits_owned
	gdb["skills_owned"]    = GameDB.skills_owned
	gdb["equipped_traits"] = GameDB.equipped_traits

	var ongoing_any: Variant = GameDB.get("ongoing_contracts")
	if ongoing_any != null:
		gdb["ongoing_contracts"] = ongoing_any
	d["gamedb"] = gdb

	return d


# ---------- restore ----------
func _apply_state(d: Dictionary) -> void:
	# Day (no emit)
	var dc_any: Variant = d.get("day_cycle", {})
	if typeof(dc_any) == TYPE_DICTIONARY:
		var dc: Dictionary = dc_any
		if dc.has("day"):
			DayCycle.day = int(dc["day"])
			if DayCycle.has_signal("day_changed"):
				DayCycle.day_changed.emit(DayCycle.day)

	# Contract limits
	var lim_any: Variant = d.get("contract_limits", {})
	if typeof(lim_any) == TYPE_DICTIONARY:
		_restore_contract_limits(lim_any)

	# Economy (emit via setters)
	var eco_any: Variant = d.get("economy", {})
	if typeof(eco_any) == TYPE_DICTIONARY:
		var eco: Dictionary = eco_any
		if eco.has("money"):
			Economy.set_balance(Economy.Currency.MONEY, int(eco["money"]))
		if eco.has("ore"):
			Economy.set_balance(Economy.Currency.ORE,   int(eco["ore"]))
		if eco.has("souls"):
			Economy.set_balance(Economy.Currency.SOULS, int(eco["souls"]))

	# Mines
	var mines_any: Variant = d.get("mines", {})
	if typeof(mines_any) == TYPE_DICTIONARY:
		var mines: Dictionary = mines_any
		if mines.has("souls_bound"):
			Mines.souls_bound = int(mines["souls_bound"])
			if Mines.has_signal("souls_bound_changed"):
				Mines.souls_bound_changed.emit(Mines.souls_bound)
		if mines.has("taura_owned"):
			Mines.taura_owned = bool(mines["taura_owned"])

	# Casino
	var casin_any: Variant = d.get("casino", {})
	if typeof(casin_any) == TYPE_DICTIONARY:
		var casin: Dictionary = casin_any
		if casin.has("asmodea_owned"):
			Casino.asmodea_owned = bool(casin["asmodea_owned"])

	# NPCs (and passives)
	var npcs_any: Variant = d.get("npcs", {})
	if typeof(npcs_any) == TYPE_DICTIONARY:
		var npcs: Dictionary = npcs_any
		if npcs.has("hired"):
			var hired_dict: Dictionary = npcs["hired"] as Dictionary
			NPCManager.hired = hired_dict
			_reapply_npc_passives()
			# wake shop/other UIs that listen to npc_hired
			if NPCManager.has_signal("npc_hired"):
				NPCManager.npc_hired.emit("__refresh__")

	# Producer
	var prod_any: Variant = d.get("producer", {})
	if typeof(prod_any) == TYPE_DICTIONARY:
		var prod: Dictionary = prod_any
		if prod.has("tier"):
			ProducerSystem.current_tier = String(prod["tier"])

	# Debt
	var debt_any: Variant = d.get("debt", {})
	if typeof(debt_any) == TYPE_DICTIONARY:
		var debt: Dictionary = debt_any
		if debt.has("mephisto_enabled"):
			DebtSystem.enable_mephisto(bool(debt["mephisto_enabled"]))

	# Curses
	if get_node_or_null("/root/Curses") != null:
		var cur_any: Variant = d.get("curses", {})
		if typeof(cur_any) == TYPE_DICTIONARY:
			var cur: Dictionary = cur_any
			if cur.has("count"):
				Curses.count = int(cur["count"])
				if Curses.has_signal("count_changed"):
					Curses.count_changed.emit(Curses.count)

	# GameDB
	var gdb_any: Variant = d.get("gamedb", {})
	if typeof(gdb_any) == TYPE_DICTIONARY:
		var gdb: Dictionary = gdb_any

		# souls: JSON -> Array[Dictionary]
		if gdb.has("souls"):
			var src_souls: Array = gdb["souls"] as Array
			var souls_typed: Array[Dictionary] = []
			for it in src_souls:
				if typeof(it) == TYPE_DICTIONARY:
					souls_typed.append(it as Dictionary)
			GameDB.souls = souls_typed
			if GameDB.has_signal("souls_changed"):
				GameDB.souls_changed.emit()

		# Inventory/Store state
		if gdb.has("max_trait_slots"):
			GameDB.max_trait_slots = int(gdb["max_trait_slots"])
		if gdb.has("traits_owned"):
			GameDB.traits_owned = gdb["traits_owned"] as Dictionary
		if gdb.has("skills_owned"):
			GameDB.skills_owned = gdb["skills_owned"] as Dictionary
		if gdb.has("equipped_traits"):
			GameDB.equipped_traits = gdb["equipped_traits"] as Array

		# ongoing_contracts: JSON -> Array[Dictionary]
		if gdb.has("ongoing_contracts"):
			var src_oc: Array = gdb["ongoing_contracts"] as Array
			var oc_typed: Array[Dictionary] = []
			for it2 in src_oc:
				if typeof(it2) == TYPE_DICTIONARY:
					oc_typed.append(it2 as Dictionary)
			GameDB.ongoing_contracts = oc_typed
			if GameDB.has_signal("contracts_changed"):
				GameDB.contracts_changed.emit()

	# Sync the UI mirror of Souls to Economy (Economy is canonical)
	GameDB.souls_currency = Economy.get_balance(Economy.Currency.SOULS)
	if GameDB.has_signal("inventory_changed"):
		GameDB.inventory_changed.emit()


# ---------- helpers ----------
func _snapshot_contract_limits() -> Dictionary:
	var out: Dictionary = {}
	var dl_any: Variant = ContractLimits.get("daily_limit")
	if dl_any != null:
		out["daily_limit"] = int(dl_any)
	var rem_any: Variant = ContractLimits.get("remaining")
	if rem_any != null:
		out["remaining"] = int(rem_any)
	else:
		var rem2_any: Variant = ContractLimits.get("remaining_today")
		if rem2_any != null:
			out["remaining"] = int(rem2_any)
	return out


func _restore_contract_limits(src_any: Variant) -> void:
	if typeof(src_any) != TYPE_DICTIONARY:
		return
	var src: Dictionary = src_any
	var dl_any: Variant = src.get("daily_limit")
	if dl_any != null and ContractLimits.get("daily_limit") != null:
		ContractLimits.daily_limit = int(dl_any)

	var rem: int = 0
	var rem_any: Variant = src.get("remaining")
	if rem_any != null:
		rem = int(rem_any)
		if ContractLimits.get("remaining") != null:
			ContractLimits.remaining = rem
		elif ContractLimits.get("remaining_today") != null:
			ContractLimits.remaining_today = rem

	# notify UI
	if ContractLimits.has_signal("contracts_count_changed"):
		ContractLimits.contracts_count_changed.emit(rem)


func _reapply_npc_passives() -> void:
	if NPCManager.is_hired("taura"):
		Mines.taura_owned = true
	if NPCManager.is_hired("asmodea"):
		Casino.asmodea_owned = true
	if NPCManager.is_hired("jackie"):
		ProducerSystem.unlock_national()
	if NPCManager.is_hired("mephisto"):
		DebtSystem.enable_mephisto(true)
