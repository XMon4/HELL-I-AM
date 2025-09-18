extends Node
# AutoLoad this as "GameDB" (no class_name here)

signal souls_changed
signal contracts_changed

# ----- player inventory -----
var player_inventory := {
	"Money": 1000,
	"Years of life": 10,
	"Fame": true
}
var player := player_inventory  # legacy alias

# ----- souls (PUBLIC, used by main.gd and panels) -----
var souls: Array[Dictionary] = []  # [{id,name,inv,traits}...]

# ----- clause & condition catalog (SOURCE OF TRUTH) -----
const CAT_CLAUSE    := "clause"
const CAT_CONDITION := "condition"
const _VAR_CHOICES := ["VOID (+40 trust)", "SOUL (+40 suspicion)"]

# original list here. normalize below.
var clause_catalog: Array[Dictionary] = [
	{"id":"tithe_percent","label":"Satan will charge a percentage of the human's earnings","ui":"percent","min":10,"max":100,"step":10},
	{"id":"no_returns","label":"If the signer wants to return the Item, Satan will not return his","ui":"button"},
	{"id":"maintenance_evil_act","label":"The human must commit one act of evil every","ui":"choice","choices":["Day","Week","Month"]},

	{"id":"death_void","label":"If the human dies before this contract is completed — The contract is void (+40 trust)","ui":"button"},
	{"id":"death_soul","label":"If the human dies before this contract is completed — Satan takes their soul (+40 suspicion)","ui":"button"},

	{"id":"cond_revenge_renounce","label":"Cond: Revenge — renounces revenge","ui":"choice","choices":_VAR_CHOICES},
	{"id":"cond_revenge_no_take","label":"Cond: Revenge — does not take revenge","ui":"choice","choices":_VAR_CHOICES},

	{"id":"cond_love_finds","label":"Cond: Love — finds true love","ui":"choice","choices":_VAR_CHOICES},
	{"id":"cond_love_not_find","label":"Cond: Love — doesn't find true love","ui":"choice","choices":_VAR_CHOICES},
	{"id":"cond_love_let_go","label":"Cond: Love — lets go true love — SOUL (+40 suspicion)","ui":"button"},

	{"id":"cond_happiness_object_ceases","label":"Cond: Happiness — object ceases to provide happiness","ui":"choice","choices":_VAR_CHOICES},

	{"id":"cond_money_not_received_1m","label":"Cond: Money — not received in 1 month — VOID (+40 trust)","ui":"button"},
	{"id":"cond_fame_not_famous_1m","label":"Cond: Fame — isn't famous within 1 month — VOID (+40 trust)","ui":"button"},
	{"id":"cond_fame_wants_to_stop","label":"Cond: Fame — wants to stop being famous","ui":"choice","choices":_VAR_CHOICES},

	{"id":"cond_lust_falls_in_love","label":"Cond: Lust — falls in love","ui":"choice","choices":_VAR_CHOICES}
]

# Known condition IDs so we don't rely only on name heuristics.
const _KNOWN_CONDITION_IDS := {
	"death_void": true,
	"death_soul": true,

	"cond_revenge_renounce": true,
	"cond_revenge_no_take": true,

	"cond_love_finds": true,
	"cond_love_not_find": true,
	"cond_love_let_go": true,

	"cond_happiness_object_ceases": true,

	"cond_money_not_received_1m": true,
	"cond_fame_not_famous_1m": true,
	"cond_fame_wants_to_stop": true,

	"cond_lust_falls_in_love": true
}

func _is_condition_id(idl: String, label: String) -> bool:
	idl = idl.to_lower()
	var lab := label.to_lower()
	if _KNOWN_CONDITION_IDS.has(idl): return true
	# Conservative heuristics for any future entries
	if idl.begins_with("cond_"): return true
	if lab.begins_with("cond:"): return true
	if idl.begins_with("death_"): return true
	if lab.find("— void") != -1 or lab.find("— soul") != -1: return true
	return false

# Normalizes the source catalog by injecting "category": "clause"|"condition"
func _normalized_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in clause_catalog:
		var d := c.duplicate(true)
		var id := String(d.get("id",""))
		var label := String(d.get("label",""))
		if not d.has("category"):
			d["category"] = CAT_CONDITION if _is_condition_id(id, label) else CAT_CLAUSE
		out.append(d)
	return out

# === PUBLIC API used by UI ===
func get_clause_catalog() -> Array[Dictionary]:
	# Return ALL entries with category field included (backward-compatible name)
	return _normalized_catalog()

func get_catalog_by_category(cat: String) -> Array[Dictionary]:
	var want := cat.to_lower()
	var out: Array[Dictionary] = []
	for d in _normalized_catalog():
		if String(d.get("category", CAT_CLAUSE)).to_lower() == want:
			out.append(d)
	return out

func get_clauses_only() -> Array[Dictionary]:
	return get_catalog_by_category(CAT_CLAUSE)

func get_conditions_only() -> Array[Dictionary]:
	return get_catalog_by_category(CAT_CONDITION)

# ----- ongoing contracts -----
var ongoing_contracts: Array[Dictionary] = []   # [{soul_id,name,offers,asks,clauses,acceptance}]

func _ready() -> void:
	seed_if_empty()
	emit_signal("souls_changed")
	emit_signal("contracts_changed")

# ====== contracts ======
func add_contract(c: Dictionary) -> void:
	ongoing_contracts.append(c)
	emit_signal("contracts_changed")

# ====== seeding & CRUD ======
func add_soul(s: Dictionary) -> void:
	souls.append(s)
	emit_signal("souls_changed")

func remove_soul_by_index(i: int) -> void:
	if i >= 0 and i < souls.size():
		souls.remove_at(i)
		emit_signal("souls_changed")

func is_empty() -> bool:
	return souls.is_empty()

func seed_if_empty(count: int = 7) -> void:
	if not souls.is_empty():
		return
	for i in range(count):
		var inv := {"Soul": true, "Body": true, "Years of life": 12 + i}
		if (i % 2) == 0:
			inv["Musical skill"] = true
		if (i % 3) == 0:
			inv["Money"] = 10000 + i * 777
		souls.append({
			"id": "s_%d" % (i + 1),
			"name": "Human %d" % (i + 1),
			"inv": inv,
			"traits": {"morality": "neutral", "fear": 0.2, "greed": 0.5}
		})
	emit_signal("souls_changed")

# ====== queries used by UI ======
func list_player_offers() -> Array[String]:
	var out: Array[String] = []

	# 1) regular inventory offers (skip the raw "Fame" key)
	for k in player_inventory.keys():
		if k == "Fame":
			continue
		var v = player_inventory[k]
		if v is int:
			var val_text := ""
			if k == "Money":
				val_text = "$%d" % int(v)
			else:
				val_text = str(v)
			out.append("%s: %s" % [k, val_text])
		else:
			out.append(k)

	# 2) tiered Fame offers (based on ProducerSystem)
	var have_fame := false
	if player_inventory.has("Fame"):
		var fv = player_inventory["Fame"]
		have_fame = (fv == true)

	if have_fame:
		out.append("Fame (Local)")

		var can_national := false
		if ProducerSystem and ProducerSystem.has_method("can_offer_fame_tier"):
			can_national = ProducerSystem.can_offer_fame_tier("National")
		if can_national:
			out.append("Fame (National)")

	return out

func list_soul_asks(soul_id: String) -> Array[String]:
	var s := _find_soul(soul_id)
	if s.is_empty():
		return []
	var inv: Dictionary = s.inv
	var out: Array[String] = []
	for k in inv.keys():
		var v = inv[k]
		if v is int:
			var val_text := "$%d" % int(v) if k == "Money" else str(v)
			out.append("%s: %s" % [k, val_text])
		else:
			out.append(k)
	return out

# ====== utilities ======
func index_count() -> int:
	return souls.size()

func id_by_index(i: int) -> String:
	if i >= 0 and i < souls.size():
		return String(souls[i].id)
	return ""

func name_by_index(i: int) -> String:
	if i >= 0 and i < souls.size():
		return String(souls[i].name)
	return ""

func traits_by_index(i: int) -> Dictionary:
	if i >= 0 and i < souls.size():
		return souls[i].traits
	return {}

func _find_soul(id: String) -> Dictionary:
	for s in souls:
		if String(s.id) == id:
			return s
	return {}
