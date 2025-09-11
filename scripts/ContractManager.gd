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
