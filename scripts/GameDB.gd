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

# ----- clause & condition catalog -----
const _VAR_CHOICES := ["VOID (+40 trust)", "SOUL (+40 suspicion)"]

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
	{"id":"cond_lust_falls_in_love","label":"Cond: Lust — falls in love","ui":"choice","choices":_VAR_CHOICES},
]

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
		# Local is always available when Fame is owned
		out.append("Fame (Local)")

		# National only if Producer power allows it
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

func get_clause_catalog() -> Array[Dictionary]:
	return clause_catalog

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
