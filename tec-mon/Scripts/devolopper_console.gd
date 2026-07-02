extends StaticBody2D

var _tecmons: Array[TecmonData] = []
var _items: Array[ItemData] = []

const TECMON_PATH := "res://TecMons/"
const ITEM_PATH := "res://Items/"

@onready var ui: Control = %UI
@onready var back_button: Button = %BackButton

@onready var tab_bar: TabContainer = %TabContainer

@onready var tecmon_list: VBoxContainer = %TecmonList
@onready var tecmon_search: LineEdit = %TecmonSearch
@onready var lvl_box: SpinBox = %LvlBox
@onready var nickname_box: LineEdit = %Nickname

@onready var item_list: VBoxContainer = %ItemList
@onready var item_search: LineEdit = %ItemSearch
@onready var item_amount_box: SpinBox = %ItemAmountBox

var _all_tecmon_buttons: Array[Button] = []
var _all_item_buttons: Array[Button] = []
var _busy: bool = false

func _ready() -> void:
	ui.hide()
	_register_all_tecmons()
	_register_all_items()
	tecmon_search.text_changed.connect(_filter_tecmons)
	item_search.text_changed.connect(_filter_items)

func interact(_player: Player) -> void:
	if ui.visible:
		return
	Global.set_movement_blocked(true)
	ui.show()
	_populate_tecmons()
	_populate_items()

func _populate_tecmons() -> void:
	for b in _all_tecmon_buttons:
		b.queue_free()
	_all_tecmon_buttons.clear()

	for tecmon in _tecmons:
		var btn := Button.new()
		btn.text = "#%d  %s" % [tecmon.id, tecmon.tecmon_name]
		btn.pressed.connect(_on_tecmon_pressed.bind(tecmon))
		tecmon_list.add_child(btn)
		_all_tecmon_buttons.append(btn)

func _populate_items() -> void:
	for b in _all_item_buttons:
		b.queue_free()
	_all_item_buttons.clear()

	for item in _items:
		var btn := Button.new()
		btn.text = item.item_name
		btn.pressed.connect(_on_item_pressed.bind(item))
		item_list.add_child(btn)
		_all_item_buttons.append(btn)

func _filter_tecmons(query: String) -> void:
	query = query.to_lower()
	for btn in _all_tecmon_buttons:
		btn.visible = query.is_empty() or btn.text.to_lower().contains(query)

func _filter_items(query: String) -> void:
	query = query.to_lower()
	for btn in _all_item_buttons:
		btn.visible = query.is_empty() or btn.text.to_lower().contains(query)

func _on_tecmon_pressed(tecmon: TecmonData) -> void:
	if _busy:
		return
	if Global.player.tecmon_party.size() >= 6:
		await _say("Party is full! (max 6)")
		return

	var lvl := roundi(lvl_box.value)
	var nickname := nickname_box.text
	var instance := TecmonInstance.create(tecmon, lvl, nickname, false)
	Global.player.tecmon_party.push_front(instance)

	await _say("Spawned lv.%d %s (nickname: %s)" % [lvl, tecmon.tecmon_name, instance.display_name()])

func _on_item_pressed(item: ItemData) -> void:
	if _busy:
		return
	var amount := roundi(item_amount_box.value)
	Global.player.inventory.add(item, amount)
	await _say("Added x%d %s to inventory." % [amount, item.item_name])

func _say(text: String) -> void:
	_set_buttons_enabled(false)
	MessageBus.send([text])
	await MessageBus.message_box_closed
	_set_buttons_enabled(true)
	Global.set_movement_blocked(true)

func _set_buttons_enabled(enabled: bool) -> void:
	_busy = not enabled
	back_button.disabled = not enabled
	for btn in _all_tecmon_buttons:
		btn.disabled = not enabled
	for btn in _all_item_buttons:
		btn.disabled = not enabled

func _register_all_tecmons() -> void:
	var dir := DirAccess.open(TECMON_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.get_extension() == "tres":
			var res := load(TECMON_PATH + file)
			if res is TecmonData:
				_tecmons.append(res)
		file = dir.get_next()
	_tecmons.sort_custom(func(a, b): return a.id < b.id)

func _register_all_items() -> void:
	var dir := DirAccess.open(ITEM_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.get_extension() == "tres":
			var res := load(ITEM_PATH + file)
			if res is ItemData:
				_items.append(res)
		file = dir.get_next()
	_items.sort_custom(func(a, b): return a.item_name < b.item_name)

func _on_back_button_pressed() -> void:
	tecmon_search.text = ""
	item_search.text = ""
	ui.hide()
	Global.set_movement_blocked(false)
