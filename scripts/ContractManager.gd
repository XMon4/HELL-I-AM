extends Node

var contracts: Array[Dictionary] = []
var _next_id: int = 1
const TRUST_PER_1000_MONEY := 1.0
const COST_SKILL := 40.0
const COST_TRAIT := 40.0
const COST_BUSINESS_SILVER := 80.0

func evaluate(offers: Array[String], asks: Array[String], clauses: Array[String], _traits: Dictionary) -> float:
	var score := 0.0

	# Base heuristics
	for l in offers:
		if l.begins_with("Money"):
			score += 5.0
		elif l.find("Years of life") != -1:
			score += 8.0
		else:
			score += 4.0

	for l2 in asks:
		if l2.begins_with("Money"):
			score -= 5.0
		elif l2.find("Years of life") != -1:
			score -= 10.0
		else:
			score -= 6.0

	var st: Dictionary = _compute_clause_effects(clauses, asks)
	var suspicion: float = float(st.get("suspicion", 0.0))
	var trust: float = float(st.get("trust", 0.0))

	score += trust * 0.5
	score -= suspicion * 0.5

	return clampf((score + 50.0) / 100.0, 0.0, 1.0)

func _compute_clause_effects(clauses: Array[String], asks: Array[String]) -> Dictionary:
	var suspicion := 0.0
	var trust := 0.0

	var wants_money := false
	var wants_skill := false
	for a in asks:
		var al := a.to_lower()
		if al.begins_with("money"):
			wants_money = true
		if al.find("skill") != -1 or al.find("beauty") != -1 or al.find("charisma") != -1:
			wants_skill = true

	# Case-insensitive tithe by matching lower-cased text
	var tithe_re := RegEx.new()
	tithe_re.compile("tithe: satan charges (\\d+)% of earnings")

	for c in clauses:
		var cl := c.to_lower()

		var m := tithe_re.search(cl)
		if m:
			var pct := float(m.get_string(1).to_int())
			if wants_money: suspicion += 2.0 * pct   # +20 per 10%
			elif wants_skill: suspicion += 1.0 * pct # +10 per 10%
			continue

		if cl.find("no returns") != -1 or cl.find("no return") != -1:
			suspicion += 30.0
			continue

		if cl.find("evil act every day") != -1:
			suspicion += 80.0
			continue
		if cl.find("evil act every week") != -1:
			suspicion += 20.0
			continue
		if cl.find("evil act every month") != -1:
			suspicion += 5.0
			continue

		if cl.find("contract is void") != -1:
			trust += 40.0
			continue
		if cl.find("takes soul") != -1:
			suspicion += 40.0
			continue

		# Generic (+40) markers, case-insensitive
		if cl.find("(+40 trust)") != -1:
			trust += 40.0
			continue
		if cl.find("(+40 suspicion)") != -1:
			suspicion += 40.0
			continue

	return {"suspicion": suspicion, "trust": trust}

func create_contract(soul_id: String, human_name: String, offers: Array[String], asks: Array[String], clauses: Array[String], acceptance: float) -> String:
	var id := "c_%d" % _next_id
	_next_id += 1
	contracts.append({
		"id": id, "soul_id": soul_id, "soul_name": human_name,
		"offers": offers.duplicate(), "asks": asks.duplicate(), "clauses": clauses.duplicate(),
		"acceptance": acceptance, "status": "ACTIVE"
	})
	return id
	
func compute_bars(_offers: Array[String], asks: Array[String], clauses: Array[String], human: Dictionary, equipped_traits: Array[String]) -> Dictionary:
	var trust := 0.0
	var suspicion := 0.0

	# ---- OFFERS → Trust
	for l in _offers:
		var low := l.to_lower()
		if low.begins_with("money"):
			var amt := _extract_int(l)
			if amt > 0:
				trust += float(amt) / 1000.0 * TRUST_PER_1000_MONEY
		elif low.begins_with("skill"):
			# “Mental business (silver)”
			if low.find("business mentality (silver)") != -1 or low.find("mental business (silver)") != -1:
				trust += COST_BUSINESS_SILVER
			else:
				trust += COST_SKILL
		elif low.begins_with("trait"):
			trust += COST_TRAIT

	# ---- ASKS → Suspicion
	for l in asks:
		var low := l.to_lower()
		if low.begins_with("skill"):
			if low.find("business mentality (silver)") != -1 or low.find("mental business (silver)") != -1:
				suspicion += COST_BUSINESS_SILVER
			else:
				suspicion += COST_SKILL
		elif low.begins_with("trait"):
			suspicion += COST_TRAIT

	# ---- Clauses/context
	var st := _compute_clause_effects(clauses, asks)
	trust     += float(st.get("trust", 0.0))
	suspicion += float(st.get("suspicion", 0.0))

	# ---- Asking for Soul adds suspicion by difficulty
	if _asks_soul(asks):
		suspicion += _soul_value_for(human)

	# ---- Modifiers
	var trust_pct := 0.0
	var susp_pct  := 0.0

	# Player equipped traits
	for t in equipped_traits:
		var tl := t.to_lower()
		if tl.begins_with("charm"):      trust_pct += 0.10
		if tl.begins_with("seduction"):  susp_pct  -= 0.10

	# Human class
	var klass := String(human.get("class","")).to_lower()
	if klass == "desperate": susp_pct -= 0.10
	if klass == "naive":     trust_pct += 0.10
	if klass == "lawyer":
		susp_pct += 0.20
		trust_pct -= 0.20

	# Human trait: Manipulation → extra -10% trust
	var inv := human.get("inv", {}) as Dictionary
	for k in inv.keys():
		var kl := String(k).to_lower()
		if inv[k] and kl.find("trait: manipulation") != -1:
			trust_pct -= 0.10
			break

	trust     = max(0.0, trust * (1.0 + trust_pct))
	suspicion = max(0.0, suspicion * (1.0 + susp_pct))

	return {"trust": trust, "suspicion": suspicion}

func _asks_money(lines: Array[String]) -> bool:
	for l in lines:
		if l.to_lower().begins_with("money"): return true
	return false

func _asks_skill(lines: Array[String]) -> bool:
	for l in lines:
		var s := l.to_lower()
		if s.find("skill") != -1:
			return true
		# heuristic: treat tiered upgrades as "skill-like"
		if s.find("(bronze") != -1 or s.find("(silver") != -1 or s.find("(gold") != -1:
			return true
	return false


func _asks_soul(lines: Array[String]) -> bool:
	for l in lines:
		if l.to_lower().find("soul") != -1: return true
	return false

func _extract_int(text: String) -> int:
	var digits := ""
	var n := text.length()
	for i in range(n):
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits if digits != "" else "0")


func _soul_value_for(human: Dictionary) -> int:
	var diff := String(human.get("difficulty","easy")).to_lower()
	if diff == "easy": return 50
	if diff == "medium": return 120 # mid of 100-140
	if diff == "hard": return 150   # mid of 130-170
	return 50
