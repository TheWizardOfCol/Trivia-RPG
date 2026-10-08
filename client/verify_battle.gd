extends SceneTree

## Headless smoke test for the battle slice: plays an entire battle to
## completion, deliberately taking one wrong answer while defending, then
## answers correctly to win. Prints the final state. Not part of the game.

func _initialize() -> void:
	var battle := (load("res://battle.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await create_timer(0.3).timeout

	var steps := 0
	var took_damage := false
	# Phase: 0=PLAYER_ATTACK 1=PLAYER_DEFEND 2=LAST_CHANCE 3=WON 4=LOST
	while battle.phase < 3 and steps < 30:
		var choice: String = str(battle.current_question["correct"])
		if not took_damage and battle.phase == 1:
			choice = str(battle.current_question["wrong"][0])
			took_damage = true
		battle.answer(choice)
		await create_timer(0.05).timeout
		steps += 1

	print("FINAL_PHASE=", battle.phase, " (expect 3 = WON)")
	print("PLAYER_HP=", battle.player_hp, " (expect 26: one wrong defend, 30-4)")
	print("TRAINER_HP=", battle.trainer_hp, " (expect 0)")
	print("MESSAGE=", battle.message_label.text)
	print("QUESTION_LABEL=", battle.question_label.text)
	print("STEPS=", steps)
	quit(0)