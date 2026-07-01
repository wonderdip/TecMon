extends Button

var idx : float
signal selected()
signal hovered()

@onready var tecmon_name: Label = %TecmonName
@onready var tecmon_lvl: Label = %TecmonLvl
@onready var tecmon_hp_bar: ProgressBar = %TecmonHPBar
@onready var tecmon_hp: Label = %TecmonHP
@onready var outline: NinePatchRect = $Outline

func _ready() -> void:
	outline.hide()

func _on_tecmon_details_pressed() -> void:
	if BattleSystem.player_participant and BattleSystem.enemy_participant:
		BattleSystem.player_participant.current_mon = BattleSystem.player_participant.party[idx]
		selected.emit()

func _on_mouse_entered() -> void:
	if BattleSystem.player_participant and BattleSystem.enemy_participant:
		BattleSystem.player_participant.current_mon = BattleSystem.player_participant.party[idx]
		outline.show()
		hovered.emit()

func _on_mouse_exited() -> void:
	outline.hide()
