extends Node
# AutoLoad this as "GameDB" (no class_name here)

signal souls_changed
signal contracts_changed
signal inventory_changed

# ----- player inventory -----
var player_inventory := {
	"Money": 100000,        # can edit for testing
	"Years of life": 10,
	"Fame": true
}
var player := player_inventory  # legacy alias
var traits_owned := {}            # {"charm_bronze": true, "seduction_bronze": true}
var skills_owned := {             # {"guitar_bronze": true}
	"skill:painter": true,
	"skill:shooter": true} 
var equipped_traits: Array[String] = []
var max_trait_slots := 1
var souls_currency := 0           # spent in Power Store

func get_equipped_traits() -> Array[String]:
	return equipped_traits.duplicate()

func add_souls(n:int) -> void:
	Economy.add(Economy.Currency.SOULS, n)

func spend_souls(n:int) -> bool:
	var have := Economy.get_balance(Economy.Currency.SOULS)
	if have >= n:
		Economy.add(Economy.Currency.SOULS, -n)
		return true
	return false

func give_trait(id:String) -> void:
	traits_owned[id] = true
	emit_signal("inventory_changed")

func equip_trait(id:String) -> bool:
	if not traits_owned.has(id): return false
	if equipped_traits.has(id): return true
	if equipped_traits.size() >= max_trait_slots: return false
	equipped_traits.append(id)
	emit_signal("inventory_changed")
	return true

func unequip_trait(id:String) -> void:
	equipped_traits.erase(id)
	emit_signal("inventory_changed")
# ----- souls (PUBLIC, used by main.gd and panels) -----
# Each soul now may include:
var souls: Array[Dictionary] = [
{"id":"s_ratzz",  "name":"Ratzz",  "class":"desperate","difficulty":"easy","desire":"money",     "inv":{"Soul":true}},
{"id":"s_sussie","name":"Sussie", "class":"naive",    "difficulty":"easy","desire":"money",     "inv":{"Soul":true}},

{"id":"s_andrew","name":"Andrew","class":"", "difficulty":"medium","desire":"fame",
 "inv":{"Soul":true, "Trait: Charm (bronze)":true, "Skill: Guitar Player (bronze)":true}},

{"id":"s_cecylia","name":"Cecylia","class":"", "difficulty":"medium","desire":"happiness",
 "inv":{"Soul":true, "Trait: Seduction (bronze)":true, "Skill: Mental business (bronze)":true}},

{"id":"s_vixy",  "name":"Vixy",  "class":"", "difficulty":"medium","desire":"revenge",
 "inv":{"Soul":true, "Trait: Intelligence (bronze)":true, "Skill: Tactician (bronze)":true}},

{"id":"s_marcus","name":"Marcus","class":"", "difficulty":"medium","desire":"happiness",
 "inv":{"Soul":true, "Trait: Intelligence (bronze)":true, "Skill: Card Player (bronze)":true}},

{"id":"s_reggie","name":"Reggie","class":"lawyer","difficulty":"hard","desire":"happiness",
 "inv":{"Soul":true, "Trait: Manipulation (bronze)":true, "Skill: Business Mentality (silver)":true}},

]
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

# Legacy name->portrait fallback (kept for compatibility; profiles now carry 'portrait')
var _portrait_paths := {
	"andrew": "res://art/Andrew.png",
	"vixy": "res://art/Vixy.png",
	"cecylia": "res://art/Cecylia.png",
	"reggie": "res://art/Reggie.png",
	"marcus": "res://art/Marcus.png",
	"susie": "res://art/Susie.png"
}

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

# ---------- NPC profile helpers ----------
var _portrait_cache: Dictionary = {}

func add_soul_profile(p: Dictionary) -> void:
	# Minimal normalized record (keeps backward compat with existing UI)
	var s := {
		"id":      p.get("id",""),
		"name":    p.get("name",""),
		"portrait":p.get("portrait",""),   # new
		"desire":  p.get("desire",""),     # new
		"inv":     p.get("inv", {}),       # inventory / asks
		"traits":  p.get("traits", {}),    # used by acceptance later
		"skills":  p.get("skills", [])     # optional
	}
	souls.append(s)

func get_desire_for_index(i: int) -> String:
	if i < 0 or i >= souls.size(): return ""
	return String(souls[i].get("desire",""))

func get_portrait_path_by_index(i: int) -> String:
	if i < 0 or i >= souls.size():
		return ""
	# Prefer explicit 'portrait' on the soul; fallback to legacy map
	var portrait := String(souls[i].get("portrait",""))
	if portrait != "":
		return portrait
	var nm := String(souls[i].get("name","")).to_lower()
	return String(_portrait_paths.get(nm, ""))

func get_portrait_tex_by_index(i: int) -> Texture2D:
	var path := get_portrait_path_by_index(i)
	if path == "":
		return null
	if _portrait_cache.has(path):
		return _portrait_cache[path]
	var res := ResourceLoader.load(path)
	if res is Texture2D:
		_portrait_cache[path] = res
		return res
	return null
	
func give_skill(id:String) -> void:
	skills_owned[id] = true
	emit_signal("inventory_changed")

# ----- ongoing contracts -----
var ongoing_contracts: Array[Dictionary] = []   # [{soul_id,name,offers,asks,clauses,acceptance}]

func _ready() -> void:
	seed_if_empty()

	# Hook Economy → UI mirror
	if Economy and not Economy.balance_changed.is_connected(Callable(self, "_on_bal")):
		Economy.balance_changed.connect(Callable(self, "_on_bal"))
	else:
		# If autoload order is uncertain, try again next frame
		call_deferred("_try_hook_economy")

	# Initialize mirror now
	souls_currency = Economy.get_balance(Economy.Currency.SOULS)
	inventory_changed.emit()  # UI refresh

func _try_hook_economy() -> void:
	if Economy and not Economy.balance_changed.is_connected(Callable(self, "_on_bal")):
		Economy.balance_changed.connect(Callable(self, "_on_bal"))

func _on_bal(currency: int, _value: int) -> void:
	if currency == Economy.Currency.SOULS:
		souls_currency = Economy.get_balance(Economy.Currency.SOULS)
		inventory_changed.emit()

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

# Replace dummy generator with real profiles
func seed_if_empty(count: int = 0) -> void:
	if not souls.is_empty():
		return

	# --- Andrew ---
	add_soul_profile({
		"id":"s_andrew",
		"name":"Andrew",
		"portrait":"res://art/Andrew.png",
		"desire":"fame",
		"inv": {"Soul": true, "Body": true, "Money": 1200, "Guitar Player (Bronze)": true},
		"traits": {"morality": 30, "cowardice": 20, "charm": "bronze"},
		"skills": ["Guitar Player (Bronze)"]
	})

	# --- Vixy ---
	add_soul_profile({
		"id":"s_vixy",
		"name":"Vixy",
		"portrait":"res://art/Vixy.png",
		"desire":"revenge",
		"inv": {"Soul": true, "Body": true, "Money": 800, "Tactician (Bronze)": true},
		"traits": {"morality": -30, "cowardice": 5, "intelligence": "bronze"},
		"skills": ["Tactician (Bronze)"]
	})

	# --- Cecylia ---
	add_soul_profile({
		"id":"s_cecylia",
		"name":"Cecylia",
		"portrait":"res://art/Cecylia.png",
		"desire":"happiness",
		"inv": {"Soul": true, "Body": true, "Money": 2500, "Business mental (Bronze)": true},
		"traits": {"morality": -20, "cowardice": 20, "seduction": "bronze"},
		"skills": ["Business mental (Bronze)"]
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
				var v_money := Economy.get_balance(Economy.Currency.MONEY) if Economy else int(player_inventory.get("Money", 0))
				out.append("Money: $" + str(v_money))
				continue
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
	var inv: Dictionary = s.get("inv", {})
	var out: Array[String] = []
	for k in inv.keys():
		var v = inv[k]
		if v is int:
			var val_text := ( "$%d" % int(v) ) if k == "Money" else str(v)
			out.append("%s: %s" % [k, val_text])
		else:
			out.append(k)
	return out

# ====== utilities ======
func index_count() -> int:
	return souls.size()

func id_by_index(i: int) -> String:
	if i >= 0 and i < souls.size():
		return String(souls[i].get("id",""))
	return ""

func name_by_index(i: int) -> String:
	if i >= 0 and i < souls.size():
		return String(souls[i].get("name",""))
	return ""

func traits_by_index(i: int) -> Dictionary:
	if i >= 0 and i < souls.size():
		return souls[i].get("traits", {})
	return {}

func _find_soul(id: String) -> Dictionary:
	for s in souls:
		if String(s.get("id","")) == id:
			return s
	return {}
