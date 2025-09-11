extends Node
class_name ProducerSystemService

var current_tier := "Local"  # "Local"|"National"

func unlock_national() -> void:
	if current_tier == "Local":
		current_tier = "National"

func can_offer_fame_tier(tier: String) -> bool:
	var order := {"Local": 1, "National": 2}
	return order.get(tier, 999) <= order.get(current_tier, 1)
