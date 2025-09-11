extends Control
class_name CasinoPanel

const LOG_MAX: int = 8

@onready var asmodea_lbl: Label = $"VBoxContainer/Asmodea"
@onready var base_lbl:     Label = $"VBoxContainer/Base"
@onready var mult_lbl:     Label = $"VBoxContainer/Mult"
@onready var expect_lbl:   Label = $"VBoxContainer/Expect"
@onready var total_lbl:    Label = $"VBoxContainer/Total"
@onready var logs_box:     VBoxContainer = $"VBoxContainer/Logs"

var _total_generated: int = 0

func _ready() -> void:
	if not DayCycle.day_advanced.is_connected(_on_day): DayCycle.day_advanced.connect(_on_day)
	if not Casino.money_generated.is_connected(_on_payout): Casino.money_generated.connect(_on_payout)
	if not NPCManager.npc_hired.is_connected(_on_hired): NPCManager.npc_hired.connect(_on_hired)
	_refresh_static()
	_refresh_expect()

func _refresh_static() -> void:
	var t := Economy.tuning
	base_lbl.text = "Base per day: %d" % int(t.casino_base_money_per_day)
	var mult := 1.0
	if Casino.asmodea_owned:
		mult = 1.0 + t.asmodea_money_multiplier
	mult_lbl.text = "Multiplier: x%.2f" % mult
	if Casino.asmodea_owned: asmodea_lbl.text = "Asmodea owned: YES"
	else: asmodea_lbl.text = "Asmodea owned: NO"
	total_lbl.text = "Total generated this session: %d" % _total_generated

func _refresh_expect() -> void:
	var t := Economy.tuning
	var mult := 1.0
	if Casino.asmodea_owned:
		mult = 1.0 + t.asmodea_money_multiplier
	var expect := int(floor(float(t.casino_base_money_per_day) * mult))
	expect_lbl.text = "Expected next day: +%d money" % expect

func _on_day(_day: int) -> void:
	_refresh_static()
	_refresh_expect()

func _on_payout(gain: int, day: int) -> void:
	_total_generated += gain
	_refresh_static()
	_add_log("Day %d: +%d money" % [day, gain])

func _on_hired(_id: String) -> void:
	_refresh_static()
	_refresh_expect()

func _add_log(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	logs_box.add_child(lbl)
	while logs_box.get_child_count() > LOG_MAX:
		logs_box.get_child(0).queue_free()
