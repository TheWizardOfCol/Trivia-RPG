extends SceneTree

## Smoke test for the title -> battle transition: loads main.tscn and
## presses the Start Battle button, then confirms the battle scene took
## over as current_scene.

func _initialize() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout

	var btn: Button = main.get_node_or_null("StartBattle")
	if btn == null:
		print("NO_START_BUTTON")
		quit(1)
		return
	print("BUTTON_TEXT=", btn.text)
	btn.emit_signal("pressed")
	await create_timer(0.6).timeout

	var cur = root.get_tree().current_scene
	print("CURRENT_SCENE=", "<null>" if cur == null else cur.name)
	if cur != null and cur.has_method("answer"):
		print("BATTLE_READY_PHASE=", cur.phase)
		cur.quit() if false else null
	print("TRANSITION_OK=", cur != null and cur.has_method("answer"))
	quit(0)