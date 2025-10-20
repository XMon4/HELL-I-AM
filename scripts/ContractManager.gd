extends Node

var contracts: Array[Dictionary] = []
var _next_id: int = 1

func evaluate(offers: Array[String], asks: Array[String], clauses: Array[String], _traits: Dictionary) -> float:
	var score := 0.0

	# Base heuristics
	for l in offers:
		if l.begins_with("Money"):
			score += 5.0
		elif "Years of life" in l:
			score += 8.0
		else:
			score += 4.0

	for l2 in asks:
		if l2.begins_with("Money"):
			score -= 5.0
		elif "Years of life" in l2:
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
		var low := a.to_lower()
		if low.begins_with("money"):
			wants_money = true
		if ("skill" in low) or ("beauty" in low) or ("charisma" in low):
			wants_skill = true

	var tithe_re := RegEx.new()
	tithe_re.compile("Tithe: Satan charges (\\d+)% of earnings")

	for c in clauses:
		var m := tithe_re.search(c)
		if m:
			var pct := float(m.get_string(1).to_int())
			if wants_money:
				suspicion += 2.0 * pct    # +20 per 10% → 2×%
			elif wants_skill:
				suspicion += 1.0 * pct    # +10 per 10% → 1×%
			continue

		if c.find("No Returns") != -1:
			suspicion += 30.0
			continue

		if c.find("Maintenance: evil act every Day") != -1:
			suspicion += 80.0
			continue
		if c.find("Maintenance: evil act every Week") != -1:
			suspicion += 20.0
			continue
		if c.find("Maintenance: evil act every Month") != -1:
			suspicion += 5.0
			continue

		if c.find("Death Clause: Contract is void") != -1:
			trust += 40.0
			continue
		if c.find("Death Clause: Satan takes soul") != -1:
			suspicion += 40.0
			continue

		# Generic markers from Conditions
		if c.find("(+40 trust)") != -1:
			trust += 40.0
			continue
		if c.find("(+40 suspicion)") != -1:
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
func compute_bars(offers: Array[String], asks: Array[String], clauses: Array[String], human: Dictionary, equipped_traits: Array[String]) -> Dictionary:
	var trust := 0.0
	var suspicion := 0.0

	# ---- Clauses from C&C.pdf ----
	for c in clauses:
		var lower := c.to_lower()

		if lower.find("percentage") != -1:
			var pct := _extract_int(c)
			var blocks := int(roundi(pct / 10.0))
			if _asks_money(asks):
				suspicion += 20.0 * blocks   # +20 per 10% if the human wants money
			elif _asks_skill(asks):
				suspicion += 10.0 * blocks   # +10 per 10% if the human wants a skill
		elif lower.find("no return") != -1:
			suspicion += 30.0
		elif lower.find("act of evil") != -1:
			if lower.find("day") != -1:      suspicion += 80.0
			elif lower.find("week") != -1:   suspicion += 20.0
			elif lower.find("month") != -1:  suspicion += 5.0
		elif lower.find("dies before") != -1:
			trust += 40.0

	# ---- Conditions from Conditions.pdf ----
	# Add trust/susp bumps based on the human’s desire
	for c in clauses:
		var lower := c.to_lower()
		if lower.find("isn't famous") != -1 or lower.find("not receive") != -1:
			trust += 40.0

	# ---- Asking for Soul adds suspicion equal to its value (PROTOTYPE RUN) ----
	if _asks_soul(asks):
		suspicion += _soul_value_for(human)  # 50 easy, 100-140 medium, 130-170 hard

	# ---- Equipped trait modifiers (Charm +10% trust; Seduction -10% suspicion) ----
	var trust_pct := 0.0
	var susp_pct  := 0.0
	for t in equipped_traits:
		if t.begins_with("charm"):      trust_pct += 0.10
		if t.begins_with("seduction"):  susp_pct  -= 0.10

	# ---- Human class modifiers (Desperate / Naive / Lawyer) ----
	var klass := String(human.get("class","")).to_lower()
	if klass == "desperate": susp_pct -= 0.10
	if klass == "naive":     trust_pct += 0.10
	if klass == "lawyer":
		susp_pct += 0.20
		trust_pct -= 0.20

	# Apply per-stat %
	trust = max(0.0, trust * (1.0 + trust_pct))
	suspicion = max(0.0, suspicion * (1.0 + susp_pct))

	return {"trust": trust, "suspicion": suspicion}

func _asks_money(lines: Array[String]) -> bool:
	for l in lines:
		if l.to_lower().begins_with("money"): return true
	return false

func _asks_skill(lines: Array[String]) -> bool:
	for l in lines:
		if l.to_lower().find("skill") != -1: return true
	return false

func _asks_soul(lines: Array[String]) -> bool:
	for l in lines:
		if l.to_lower().find("soul") != -1: return true
	return false

func _extract_int(text: String) -> int:
	var s := ""
	for ch in text:
		if ch >= "0" and ch <= "9": s += ch
	return int(s if s != "" else "0")

func _soul_value_for(human: Dictionary) -> int:
	var diff := String(human.get("difficulty","easy")).to_lower()
	if diff == "easy": return 50
	if diff == "medium": return 120 # mid of 100-140
	if diff == "hard": return 150   # mid of 130-170
	return 50
