extends SceneTree

## Headless smoke test for the battle: plays a full battle to completion
## (one deliberate wrong answer while defending, then all-correct to win),
## and separately checks that a timeout counts as a wrong answer. Prints the
## final states. Not part of the game.

func _initialize() -> void:
	await _test_full_battle()
	await _test_timeout()
	quit(0)

func _test_full_battle() -> void:
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
	print("RESULT_MSG=", battle.result_label.text, " (expect Correct! You deal 5 damage.)")
	battle.queue_free()
	await create_timer(0.1).timeout

func _test_timeout() -> void:
	var battle := (load("res://battle.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await create_timer(0.3).timeout

	print("TIMER_SECONDS=", battle.answer_seconds, " (expect 25 solo)")
	print("CLOCK_TEXT=", battle.time_label.text, " (expect 25s)")
	battle._timeout()
	await create_timer(0.05).timeout
	print("TIMEOUT_PHASE=", battle.phase, " (expect 1 = PLAYER_DEFEND)")
	print("TIMEOUT_MSG=", battle.result_label.text, " (expect Time's up! No damage.)")
	battle.queue_free()
	await create_timer(0.1).timeout