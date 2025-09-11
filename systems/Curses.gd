extends Node
class_name CursesService

signal count_changed(count: int)

var count: int = 0
const ORE_COST := 15

func craft_one() -> bool:
	if Economy.get_balance(Economy.Currency.ORE) < ORE_COST:
		return false
	Economy.add(Economy.Currency.ORE, -ORE_COST)
	count += 1
	count_changed.emit(count)
	return true
