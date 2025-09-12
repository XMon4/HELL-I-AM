extends Control
class_name OngoingPanel

@onready var list_box: VBoxContainer     = %OngoingList
@onready var row_template: VBoxContainer = %OngoingRowTemplate

func _ready() -> void:
	if row_template:
		row_template.visible = false

func add_contract_entry(human_name: String, offers: Array[String], asks: Array[String], clauses: Array[String]) -> void:
	var row: VBoxContainer = row_template.duplicate() as VBoxContainer if row_template else VBoxContainer.new()
	row.visible = true

	var title := row.get_node_or_null("Title") as Label
	var body  := row.get_node_or_null("Body") as Label
	if title == null:
		title = Label.new(); row.add_child(title)
	if body == null:
		body = Label.new(); body.autowrap_mode = TextServer.AUTOWRAP_WORD; row.add_child(body)

	title.text = "%s — signed" % human_name
	body.text  = "Offer: %s\nAsk: %s\nClauses: %s" % [_join(offers), _join(asks), _join(clauses)]

	list_box.add_child(row)
	list_box.add_child(HSeparator.new())

func _join(arr: Array[String]) -> String:
	var out := ""
	for i in range(arr.size()):
		out += arr[i]
		if i < arr.size() - 1: out += ", "
	return out
