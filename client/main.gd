extends Control

func _ready() -> void:
	$StartBattle.pressed.connect(_on_start_battle_pressed)

func _on_start_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://battle.tscn")