extends Control

var spin: SpinBox
var bind_btn: Button
var bound_label: Label

func _ready() -> void:
	spin = get_node_or_null("VBoxContainer/HBoxContainer/SoulAmount") as SpinBox
	if spin == null: spin = find_child("SoulAmount", true, false) as SpinBox

	bind_btn = get_node_or_null("VBoxContainer/BindButton") as Button
	if bind_btn == null: bind_btn = find_child("BindButton", true, false) as Button

	bound_label = get_node_or_null("VBoxContainer/BoundLabel") as Label
	if bound_label == null: bound_label = find_child("BoundLabel", true, false) as Label

	if bind_btn:
		bind_btn.pressed.connect(_on_bind)

	Economy.balance_changed.connect(_on_bal_changed)
	Mines.souls_bound_changed.connect(func(_v): _refresh())
	_refresh()

func _on_bal_changed(currency: int, _value: int) -> void:
	if currency == Economy.Currency.SOULS:
		_refresh()

func _need() -> int:
	return int(spin.value) if spin else 1

func _enough() -> bool:
	return Economy.get_balance(Economy.Currency.SOULS) >= _need()

func _on_bind() -> void:
	if not _enough():
		if bind_btn: bind_btn.tooltip_text = "Not enough Souls."
		return
	var amt := _need()
	var ok := Mines.bind_souls(amt)
	if not ok and bind_btn:
		bind_btn.tooltip_text = "Bind failed."
	_refresh()

func _refresh() -> void:
	if bound_label:
		bound_label.text = "Bound souls: %d" % Mines.souls_bound
	if bind_btn:
		bind_btn.disabled = not _enough()
		bind_btn.tooltip_text = "" if _enough() else "Not enough Souls."
