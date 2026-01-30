extends Node
# AutoLoad this as "GameDB" (no class_name here)

signal souls_changed
signal contracts_changed
signal inventory_changed

# ----- player inventory -----
var player_inventory := {
	"Money": 80000,
	"Lifespan": 10,
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
var bodies_owned: Array[Dictionary] = [
  {"id":"b_001","type":"Healthy","gender":"female","age":24}
]
const BODY_VALUE := {
  "Beautiful": 40,
  "Healthy": 20,
  "Sick": 10,
  "Dying": 3
}
func add_lifespan(delta: int) -> void:
	player_inventory["Lifespan"] = max(0, get_lifespan() + delta)
	emit_signal("inventory_changed")

func remove_body_by_id(body_id: String) -> bool:
	for i in range(bodies_owned.size()):
		if bodies_owned[i].get("id","") == body_id:
			bodies_owned.remove_at(i)
			emit_signal("inventory_changed")
			return true
	return false

func add_body(b: Dictionary) -> void:
	if not b.has("id"):
		b["id"] = "b_" + str(Time.get_ticks_msec())
	bodies_owned.append(b)
	emit_signal("inventory_changed")

func body_to_label(b: Dictionary) -> String:
	return "Body: [%s] [%s] [%s]" % [b.get("gender","?"), str(b.get("age","?")), b.get("type","?")]

func body_value(b: Dictionary) -> int:
	return int(BODY_VALUE.get(b.get("type","Healthy"), 0))

func get_lifespan() -> int:
	return int(player_inventory.get("Lifespan", 0))

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
	
func remove_trait(id:String) -> void:
	traits_owned.erase(id)
	equipped_traits.erase(id)
	emit_signal("inventory_changed")

func equip_trait(id:String) -> bool:
	if not bool(traits_owned.get(id, false)): return false
	if equipped_traits.has(id): return true
	if equipped_traits.size() >= max_trait_slots: return false
	equipped_traits.append(id)
	emit_signal("inventory_changed")
	return true

func remove_skill(id:String) -> void:
	skills_owned.erase(id)
	emit_signal("inventory_changed")

func unequip_trait(id:String) -> void:
	equipped_traits.erase(id)
	emit_signal("inventory_changed")

func list_owned_skills_pretty() -> Array[String]:
	var out: Array[String] = []
	for id in skills_owned.keys():
		if skills_owned[id]:
			out.append(_pretty_from_skill_id(id))
	out.sort()
	return out

func _pretty_from_skill_id(id: String) -> String:
	var parts := id.split(":")
	var core := parts[1] if parts.size() > 1 else id
	return core.replace("_", " ").capitalize()

# ----- souls (PUBLIC, used by main.gd and panels) -----
# Each soul now may include:
var souls: Array[Dictionary] = [
	{
		"id":"s_ratzz","name":"Ratzz","class":"desperate","difficulty":"easy","desire":"money",
		"body": {"id":"npc_body_s_ratzz","type":"Sick","gender":"male","age":37},
		"lifespan": 33,
		"inv": {"Soul": true}
	},
	{
		"id":"s_susie","name":"Susie","class":"naive","difficulty":"easy","desire":"money",
		"body": {"id":"npc_body_s_susie","type":"Healthy","gender":"female","age":22},
		"lifespan": 48,
		"inv": {"Soul": true}
	},
	{
		"id":"s_andrew","name":"Andrew","class":"","difficulty":"medium","desire":"fame",
		"body": {"id":"npc_body_s_andrew","type":"Healthy","gender":"male","age":30},
		"lifespan": 40,
		"inv": {"Soul": true, "Trait: Charm (bronze)": true, "Skill: Guitar Player (bronze)": true}
	},
	{
		"id":"s_cecylia","name":"Cecylia","class":"","difficulty":"medium","desire":"happiness",
		"body": {"id":"npc_body_s_cecylia","type":"Beautiful","gender":"female","age":28},
		"lifespan": 42,
		"inv": {"Soul": true, "Trait: Seduction (bronze)": true, "Skill: Mental business (bronze)": true}
	},
	{
		"id":"s_vixy","name":"Vixy","class":"","difficulty":"medium","desire":"revenge",
		"body": {"id":"npc_body_s_vixy","type":"Healthy","gender":"female","age":26},
		"lifespan": 44,
		"inv": {"Soul": true, "Trait: Intelligence (bronze)": true, "Skill: Tactician (bronze)": true}
	},
	{
		"id":"s_marcus","name":"Marcus","class":"","difficulty":"medium","desire":"happiness",
		"body": {"id":"npc_body_s_marcus","type":"Sick","gender":"male","age":41},
		"lifespan": 29,
		"inv": {"Soul": true, "Trait: Intelligence (bronze)": true, "Skill: Card Player (bronze)": true}
	},
	{
		"id":"s_reggie","name":"Reggie","class":"lawyer","difficulty":"hard","desire":"happiness",
		"body": {"id":"npc_body_s_reggie","type":"Dying","gender":"male","age":55},
		"lifespan": 15,
		"inv": {"Soul": true, "Trait: Manipulation (bronze)": true, "Skill: Business Mentality (silver)": true}
	},
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
	"susie": "res://art/Susie.png",
	"ratzz": "res://art/Ratzz.png",
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
	var s := {
		"id":       p.get("id",""),
		"name":     p.get("name",""),
		"portrait": p.get("portrait",""),
		"desire":   p.get("desire",""),

		# NEW:
		"body":     p.get("body", {}),
		"lifespan": int(p.get("lifespan", 0)),
		"body_need": p.get("body_need", ""), # maybe Transformation later)

		"inv":      p.get("inv", {}),
		"traits":   p.get("traits", {}),
		"skills":   p.get("skills", [])
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
	emit_signal("souls_changed")


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
	"body": {"id":"npc_body_s_andrew","type":"Healthy","gender":"male","age":30},
	"lifespan": 40,
	"inv": {"Soul": true, "Money": 1200, "Guitar Player (Bronze)": true},
		"traits": {"morality": 30, "cowardice": 20, "charm": "bronze"},
		"skills": ["Guitar Player (Bronze)"]
	})

	# --- Vixy ---
	add_soul_profile({
		"id":"s_vixy",
		"name":"Vixy",
		"portrait":"res://art/Vixy.png",
		"desire":"revenge",
	"body": {"id":"npc_body_s_vixy","type":"Healthy","gender":"female","age":26},
	"lifespan": 44,
	"inv": {"Soul": true, "Money": 800, "Tactician (Bronze)": true},
		"traits": {"morality": -30, "cowardice": 5, "intelligence": "bronze"},
		"skills": ["Tactician (Bronze)"]
	})

	# --- Cecylia ---
	add_soul_profile({
		"id":"s_cecylia",
		"name":"Cecylia",
		"portrait":"res://art/Cecylia.png",
		"desire":"happiness",
	"body": {"id":"npc_body_s_cecylia","type":"Beautiful","gender":"female","age":28},
	"lifespan": 42,
	"inv": {"Soul": true, "Money": 2500, "Business mental (Bronze)": true},
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
	for b in bodies_owned:
		out.append(body_to_label(b))
	return out

func list_soul_asks(soul_id: String) -> Array[String]:
	var s := _find_soul(soul_id)
	if s.is_empty():
		return []

	var out: Array[String] = []

	# NEW: Body line (mockup)
	if s.has("body") and s["body"] is Dictionary:
		out.append(body_to_label(s["body"]))

	# NEW: Lifespan line (askable in 5s later)
	if s.has("lifespan"):
		out.append("Lifespan: %d" % int(s["lifespan"]))

	# existing inv items
	var inv: Dictionary = s.get("inv", {})
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
