extends Node
class_name DebtSystemService

var mephisto_enabled := false

func enable_mephisto(v: bool) -> void:
	mephisto_enabled = v

# Placeholder hooks for when contracts create debts
func compute_default_chance(base: float) -> float:
	# Mephisto reduces default by 10 percentage points
	return max(0.0, base - (0.10 if mephisto_enabled else 0.0))

func recover_on_default(amount: int) -> int:
	# Mephisto recovers 50% of defaulted value as Money
	return int(round(amount * (0.5 if mephisto_enabled else 0.0)))
