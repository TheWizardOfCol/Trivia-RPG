extends SceneTree

## Smoke test for the title -> battle transition.
##
## Part A (structural): the invisible-blocker check. A full-screen Control
## placed AFTER the button in the scene tree would swallow clicks (default
## mouse_filter = STOP). VoteHUD must be MOUSE_FILTER_IGNORE, and GUI
## picking at the button's center must land on StartBattle, not on VoteHUD.
##
## Part B (functional): press the button's own signal and confirm the battle
## scene takes over as current_scene. (Real mouse events can't be routed in
## headless mode — no input is delivered to controls there — so the click
## path is verified by the picking analysis in Part A.)

const PICK_IGNORE := Control.MOUSE_FILTER_IGNORE

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout

	var btn: Button = main.get_node_or_null("StartBattle")
	if btn == null:
		print("NO_START_BUTTON")
		quit(1)
		return
	print("BUTTON_TEXT=", btn.text)

	var hud: Control = main.get_node_or_null("VoteHUD")
	print("HUD_MOUSE_FILTER=", "IGNORE" if hud != null and hud.mouse_filter == PICK_IGNORE else "STOP -- click blocker!")
	var center: Vector2 = btn.get_global_rect().get_center()
	var picked: Node = _pick(main, center)
	print("PICKED_AT_BUTTON=", picked.name, " (expect StartBattle)")
	print("CLICK_BLOCKED=", picked != btn)

	var ok: bool = hud != null and hud.mouse_filter == PICK_IGNORE and picked == btn
	btn.emit_signal("pressed")
	await create_timer(0.6).timeout
	var cur: Node = root.get_tree().current_scene
	var transitioned := cur != null and cur.has_method("answer")
	print("CURRENT_SCENE=", "<null>" if cur == null else cur.name)
	print("TRANSITION_OK=", transitioned)
	quit(0 if ok and transitioned else 1)


## Faithful enough to Godot's GUI pick: walk the tree, consider only
## visible controls whose mouse_filter is not IGNORE whose global rect
## contains the point, ordered by draw order (children handled before
## their parents across siblings in tree order), topmost wins.
func _pick(from: Node, point: Vector2) -> Node:
	var best: Node = null
	for child in from.get_children():
		var hit := _pick(child, point)
		if hit != null:
			best = hit
	if best != null:
		return best
	if from is Control:
		var c := from as Control
		if c.mouse_filter != PICK_IGNORE and c.visible and c.get_global_rect().has_point(point):
			return c
	return null