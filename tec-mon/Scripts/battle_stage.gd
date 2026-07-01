extends CanvasLayer


@onready var battle_ui: Control = %BattleUI
@onready var enemy_sprite: TextureRect = %EnemyTecmon
@onready var player_sprite: TextureRect = %PlayerTecmon

@onready var enemy_name_label: Label = %EnemyName
@onready var enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var player_name_label: Label = %PlayerName
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var player_hp_label: Label = %PlayerHPLabel

@onready var move_container: VBoxContainer = %MoveContainer
@onready var move_one: Button = %MoveOne
@onready var move_two: Button = %MoveTwo
@onready var move_three: Button = %MoveThree
@onready var move_four: Button = %MoveFour

@onready var tecmon_ui: Control = %TecmonUI

@export var tecmon_details_template: PackedScene
@onready var tecmon_detail_container: VBoxContainer = %TecmonDetailContainer
@onready var tecmon_swap_texture: TextureRect = %TecmonSwapTexture
@onready var animation_player: AnimationPlayer = $BattleUI/AnimationPlayer
@onready var tecmon_desc: RichTextLabel = %TecmonDesc

var can_input: bool = false
var buttons: Array[Button]
var is_switching: bool = false
var force_switch: bool = false

func _ready() -> void:
	EncounterManager.encounter_started.connect(_on_encounter_started)
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	BattleSystem.turn_ended.connect(_on_turn_ended)
	BattleSystem.move_executed.connect(_on_move_executed)
	BattleSystem.switch_mon.connect(_on_force_switch)
	
	buttons = [move_one, move_two, move_three, move_four]
	
	move_one.pressed.connect(_on_move_button_pressed.bind(0))
	move_two.pressed.connect(_on_move_button_pressed.bind(1))
	move_three.pressed.connect(_on_move_button_pressed.bind(2))
	move_four.pressed.connect(_on_move_button_pressed.bind(3))
	hide()
	tecmon_ui.hide()
	

func _on_encounter_started(enemy_instance: TecmonInstance) -> void:
	## Block movement and show the encounter message. BattleSystem hasn't
	## started yet so we handle this message ourselves.
	MessageBus.send(["You encountered a " + enemy_instance.display_name() + "!"])
	MessageBus.switch_message_box_mode(true)
	await MessageBus.message_box_closed

	await SceneManager._transition_out()
	var party: Array[TecmonInstance] = Global.player.tecmon_party
	_refresh_hp_bars()
	var e_party : Array[TecmonInstance] = [enemy_instance]
	BattleSystem.start_battle(e_party, party)
	
func _on_battle_started() -> void:
	AudioManager.play_music(preload("res://Assets/Sounds/Music/battle_theme.wav"))
	animation_player.play("idle")
	_refresh_hp_bars()
	new_turn()
	show()
	await SceneManager._transition_in()

func _set_battle_buttons_enabled(enabled: bool) -> void:
	can_input = enabled

	for button in buttons:
		button.disabled = not enabled

func _on_turn_ended() -> void:
	## HP bars were already updated after each move_executed signal.
	## Just show the action prompt and menu again.
	_refresh_hp_bars()
	new_turn()

func new_turn() -> void:
	_set_battle_buttons_enabled(true)
	move_container.hide()
	if not is_switching:
		MessageBus.send_passive(
			"What will " + BattleSystem.player_participant.display_name() + " do?"
		)

func _refresh_hp_bars() -> void:
	var enemy  : BattleParticipant = BattleSystem.enemy_participant
	var player : BattleParticipant = BattleSystem.player_participant
	
	if enemy:
		enemy_sprite.texture = enemy.current_mon.get_front_sprite()
		enemy_name_label.text = enemy.display_name() + " Lv." + str(enemy.current_mon.level)
		enemy_hp_bar.value = enemy.hp_percent() * 100.0
		enemy_hp_label.text = (str(enemy.current_hp()) + "/ " + str(enemy.max_hp()))
		
	if player:
		var player_tecmon : TecmonInstance = player.current_mon
		player_sprite.texture = player_tecmon.get_back_sprite()
		player_name_label.text = player.display_name() + " Lv." + str(player_tecmon.level)
		player_hp_bar.value = player.hp_percent() * 100.0
		player_hp_label.text = (str(player.current_hp()) + "/ " + str(player.max_hp()))

func _on_move_executed(_user: BattleParticipant, _target: BattleParticipant,
		_move: MoveInstance, _result: MoveResult) -> void:
	_refresh_hp_bars()
	## TODO: play damage animation / screen shake here before _say() fires.

#Action menu buttons
func _on_fight_pressed() -> void:
	if not can_input:
		return
	
	move_container.show()
	AudioManager.play_sfx("select")
	MessageBus._message_box._clear_passive()
	var inst: TecmonInstance = BattleSystem.player_participant.current_mon
	
	for i in 4:
		var btn: Button = buttons[i]
		if i < inst.moves.size():
			var mi: MoveInstance = inst.moves[i]
			btn.text = mi.move.move_name + "  " + str(mi.current_pp) + "/" + str(mi.move.max_pp)
			btn.show()
		else:
			btn.hide()

func _on_move_button_pressed(index: int) -> void:
	var inst: TecmonInstance = BattleSystem.player_participant.current_mon
	var move: MoveInstance = inst.moves.get(index)
	if move == null:
		return
		
	_set_battle_buttons_enabled(false)
	move_container.hide()
	AudioManager.play_sfx("select")
	BattleSystem.queue_move(move)

func _on_items_pressed() -> void:
	if not can_input:
		return
	AudioManager.play_sfx("select")
	pass  ## TODO

func _on_tecmons_pressed() -> void:
	if not can_input:
		return
	AudioManager.play_sfx("select")

	for child in tecmon_detail_container.get_children():
		child.queue_free()

	for tecmon: TecmonInstance in Global.player.tecmon_party:
		var idx = Global.player.tecmon_party.find(tecmon)
		var details = tecmon_details_template.instantiate()
		details.idx = idx
		tecmon_detail_container.add_child(details)
		details.get_node("%MiniTecmon").texture = tecmon.data.mini_sprite
		details.get_node("%TecmonName").text = tecmon.display_name()
		details.get_node("%TecmonLvl").text = "Lv." + str(tecmon.level)
		details.get_node("%TecmonHP").text = "HP: " + str(roundi(tecmon.current_hp)) + "/ " + str(roundi(tecmon.max_hp))
		details.tecmon_hp_bar.value = tecmon.hp_percent() * 100
		if tecmon.current_hp <= 0:
			details.disabled = true
		
		details.selected.connect(_on_tecmon_switched)
		details.hovered.connect(_on_tecmon_hovered)
	
	_on_tecmon_hovered()
	tecmon_ui.show()
	MessageBus._message_box.hide()
	battle_ui.hide()
	
func _on_escape_pressed() -> void:
	if not can_input:
		return
		
	AudioManager.play_sfx("select")
	BattleSystem.queue_flee()

func _on_battle_ended(outcome: BattleSystem.BattleOutcome) -> void:
	## BattleSystem already sent all result messages and awaited them.
	## Just do the transition back to the overworld.
	var msg: String
	match outcome:
		BattleSystem.BattleOutcome.PLAYER_WIN: msg = "You won!"
		BattleSystem.BattleOutcome.PLAYER_FLED: msg = "Got away safely!"
		BattleSystem.BattleOutcome.PLAYER_LOST: msg = "You blacked out..."
	MessageBus.send([msg], 30)
	MessageBus.switch_message_box_mode(false)
	await MessageBus.message_box_closed
	MessageBus._message_box.switch_mode()
	await SceneManager._transition_out()
	hide()
	AudioManager.play_music(SceneManager.current_level.bgm)
	await SceneManager._transition_in()

func _on_force_switch() -> void:
	can_input = true
	is_switching = true
	force_switch = true
	MessageBus._message_box.hide()
	MessageBus._message_box._clear_passive()
	tecmon_ui.get_node("%BackButton").disabled = true
	tecmon_ui.get_node("%BackButton").hide()
	_on_tecmons_pressed()
	
func _on_tecmon_switched() -> void:	
	_refresh_hp_bars()
	tecmon_ui.hide()
	tecmon_ui.get_node("%BackButton").show()
	tecmon_ui.get_node("%BackButton").disabled = false
		
	MessageBus._message_box.show()
	battle_ui.show()
	MessageBus.send(["You sent out " + BattleSystem.player_participant.display_name() + "!"])
	await MessageBus.message_box_closed
	
	if not force_switch:
		BattleSystem.skip_turn()
	
	is_switching = false
	force_switch = false
	MessageBus.send_passive("What will " + BattleSystem.player_participant.display_name() + " do?")

func _on_tecmon_hovered():
	var instance: TecmonInstance = BattleSystem.player_participant.current_mon
	var data : TecmonData = instance.data
	tecmon_swap_texture.texture = instance.data.front_sprite
	
	var ailment_text: String = "None"
	if instance.ailments.size() > 0:
		ailment_text = Global.AILMENT_MAP.get(instance.ailments[0].type, "Unknown")

	var text: String = "%s\n[%s/%s]\nHP: %d/%d\nAilment: %s" % [
		data.tecmon_name,
		Enums.TecmonType.keys()[data.type_one],
		Enums.TecmonType.keys()[data.type_two],
		roundi(instance.current_hp),
		roundi(instance.max_hp),
		ailment_text
	]
	
	tecmon_desc.text = text
	
func _on_back_button_pressed() -> void:
	tecmon_ui.hide()
	MessageBus._message_box.show()
	battle_ui.show()
