extends Node
class_name ClauseCatalog

# Human-readable choice strings we show in UI for "variable outcome" conditions
const VAR_CHOICES: Array[String] = ["VOID (+40 trust)", "SOUL (+40 suspicion)"]

# Catalog entries: id + UI metadata (Godot uses these to build widgets)
var _defs: Array[Dictionary] = [
	# --- Core clauses ---
	{"id":"tithe_percent","label":"Satan will charge a percentage of the human's earnings","ui":"percent","min":10,"max":100,"step":10},
	{"id":"no_returns","label":"If the signer wants to return the Item, Satan will not return his","ui":"button"},
	{"id":"maintenance_evil_act","label":"The human must commit one act of evil every","ui":"choice","choices":["Day","Week","Month"]},
	{"id":"death_void","label":"If the human dies before this contract is completed — The contract is void (+40 trust)","ui":"button"},
	{"id":"death_soul","label":"If the human dies before this contract is completed — Satan takes their soul (+40 suspicion)","ui":"button"},

	# --- Conditions (grouped by theme) ---
	{"id":"cond_revenge_renounce","label":"Cond: Revenge — renounces revenge","ui":"choice","choices":VAR_CHOICES},
	{"id":"cond_revenge_no_take","label":"Cond: Revenge — does not take revenge","ui":"choice","choices":VAR_CHOICES},

	{"id":"cond_love_finds","label":"Cond: Love — finds true love","ui":"choice","choices":VAR_CHOICES},
	{"id":"cond_love_not_find","label":"Cond: Love — doesn't find true love","ui":"choice","choices":VAR_CHOICES},
	{"id":"cond_love_let_go","label":"Cond: Love — lets go true love — SOUL (+40 suspicion)","ui":"button"},

	{"id":"cond_happiness_object_ceases","label":"Cond: Happiness — object ceases to provide happiness","ui":"choice","choices":VAR_CHOICES},

	{"id":"cond_money_not_received_1m","label":"Cond: Money — not received in 1 month — VOID (+40 trust)","ui":"button"},

	{"id":"cond_fame_not_famous_1m","label":"Cond: Fame — isn't famous within 1 month — VOID (+40 trust)","ui":"button"},
	{"id":"cond_fame_wants_to_stop","label":"Cond: Fame — wants to stop being famous","ui":"choice","choices":VAR_CHOICES},

	{"id":"cond_lust_falls_in_love","label":"Cond: Lust — falls in love","ui":"choice","choices":VAR_CHOICES},
]

func all() -> Array[Dictionary]:
	return _defs

func get_def(id: String) -> Dictionary:
	for d in _defs:
		if String(d.get("id","")) == id:
			return d
	return {}

# Pretty label for a clause instance (what we show in the ItemList)
func make_label(def: Dictionary, params: Dictionary) -> String:
	var id := String(def.get("id",""))
	match id:
		"tithe_percent":
			return "Tithe: Satan charges %d%% of earnings" % int(params.get("percent", 10))
		"no_returns":
			return "No Returns: If signer returns the item, Satan keeps his"
		"maintenance_evil_act":
			return "Maintenance: evil act every %s" % String(params.get("choice", "Week"))
		"death_void":
			return "Death Clause: Contract is void (+40 trust)"
		"death_soul":
			return "Death Clause: Satan takes soul (+40 suspicion)"
		_:
			# For choice-based conditions, append the chosen outcome
			if String(def.get("ui","")) == "choice":
				return "%s — %s" % [String(def.get("label","Condition")), String(params.get("choice", VAR_CHOICES[0]))]
			return String(def.get("label","Condition"))

# Returns {"suspicion": float, "trust": float} for a clause instance
func calc_effect(def: Dictionary, params: Dictionary, asks_labels: Array[String]) -> Dictionary:
	var suspicion := 0.0
	var trust := 0.0
	var id := String(def.get("id",""))

	# For the tithe, penalties depend on what the human is asking for
	if id == "tithe_percent":
		var pct := float(int(params.get("percent", 10)))
		var wants_money := false
		var wants_skill := false
		for a in asks_labels:
			var low := a.to_lower()
			if low.begins_with("money"):
				wants_money = true
			if ("skill" in low) or ("beauty" in low) or ("charisma" in low):
				wants_skill = true
		if wants_money: suspicion += 2.0 * pct      # +20 per 10% => 2×%
		elif wants_skill: suspicion += 1.0 * pct    # +10 per 10% => 1×%
		return {"suspicion": suspicion, "trust": trust}

	if id == "no_returns":
		return {"suspicion": 30.0, "trust": 0.0}

	if id == "maintenance_evil_act":
		var choice := String(params.get("choice","Week"))
		if choice == "Day":   suspicion += 80.0
		if choice == "Week":  suspicion += 20.0
		if choice == "Month": suspicion += 5.0
		return {"suspicion": suspicion, "trust": trust}

	if id == "death_void":
		return {"suspicion": 0.0, "trust": 40.0}
	if id == "death_soul":
		return {"suspicion": 40.0, "trust": 0.0}

	# Generic outcomes for condition variants
	if params.has("choice"):
		var ch := String(params.get("choice"))
		if "trust" in ch:  trust += 40.0
		if "suspicion" in ch: suspicion += 40.0
	elif id == "cond_love_let_go":
		suspicion += 40.0
	elif id == "cond_money_not_received_1m" or id == "cond_fame_not_famous_1m":
		trust += 40.0

	return {"suspicion": suspicion, "trust": trust}
