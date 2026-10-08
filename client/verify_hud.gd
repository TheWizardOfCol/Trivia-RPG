extends SceneTree

## Temporary headless smoke test for the vote HUD: runs main.tscn against
## the backend in client/backend.txt for 7 seconds, then prints what the
## labels actually show. Not part of the game — delete after use.

func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	var hud := main.get_node("VoteHUD")
	var question: Label = hud.get_node("Margin/VBox/Question")
	var status: Label = hud.get_node("Margin/VBox/Status")
	var options := hud.get_node("Margin/VBox/Options")
	print("QUESTION=", question.text)
	print("STATUS=", status.text)
	for row in options.get_children():
		print("ROW=", row.get_child(0).text, " | ", row.get_child(2).text)
	quit(0)
