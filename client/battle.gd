extends Control

## Battle slice, single-player. Turn flow (design doc v1 simplified):
##   ATTACK  — answer your own starter bank correctly to deal damage (full
##             damage the first time you see a question, half on repeats).
##             Wrong/timeout: none.
##   DEFEND  — they strike back with their own set; answer correctly to
##             block, wrong/timeout costs you HP.
##   LAST CHANCE — when the trainer drops below ~20% HP, one final question.
##             Correct finishes them.
##
## The starter bank is King Tut Oiral's gift in The Wastes: for now it is
## the merged general-knowledge spread of every trainer's questions (see
## game_data.gd); a dedicated "General" bank replaces it later.
##
## Answer timer: 25s solo; 35s in Twitch mode so the chat has time to vote.
## Mode comes from Backend.mode() = --mode=twitch arg or backend.txt.

const GD := preload("res://game_data.gd")
const THEME := preload("res://theme.gd")

const TRAINER_NAME := "Dr. Embiggen"

const SOLO_ANSWER_SECONDS := 25.0
const TWITCH_ANSWER_SECONDS := 35.0
const URGENT_SECONDS := 5

const PLAYER_MAX_HP := 30
const PLAYER_MAX_MANA := 10
const TRAINER_MAX_HP := 20
const BASE_DAMAGE := 5
const HALF_DAMAGE := 2
const TRAINER_DAMAGE := 4
const LAST_CHANCE_THRESHOLD := 0.2

enum Phase { PLAYER_ATTACK, PLAYER_DEFEND, LAST_CHANCE, WON, LOST }

var answer_seconds := SOLO_ANSWER_SECONDS
var time_left := SOLO_ANSWER_SECONDS
var starter_bank: Array = []
var player_hp := PLAYER_MAX_HP
var player_mana := PLAYER_MAX_MANA
var trainer_hp := TRAINER_MAX_HP
var seen: Dictionary = {}
var phase: int = Phase.PLAYER_ATTACK
var current_question: Dictionary = {}

var trainer_name_label: Label
var trainer_bar: ProgressBar
var trainer_hp_label: Label
var message_label: Label
var result_label: Label
var time_label: Label
var timer_popup
var question_label: Label
var options_box: VBoxContainer
var player_bar: ProgressBar
var player_stats_label: Label

func _ready() -> void:
	answer_seconds = TWITCH_ANSWER_SECONDS if Backend.mode() == "twitch" else SOLO_ANSWER_SECONDS
	starter_bank = GD.player_starter_bank()
	_build_ui()
	THEME.apply(self)
	start_battle()

func _process(delta: float) -> void:
	if _done():
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_timeout()
		return
	_draw_time()
	if timer_popup: timer_popup.update_timer(delta)

func _draw_time() -> void:
	var secs := int(ceil(time_left))
	if time_label:
		time_label.text = "%ds" % secs
		var urgent := secs <= URGENT_SECONDS
		time_label.add_theme_color_override("font_color", THEME.WINE if urgent else THEME.NAVY)

func _build_ui() -> void:
	add_child(THEME.make_background())

	# View area (top) for NPC/background
	var view := Control.new()
	view.name = "View"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.offset_bottom = -get_viewport_rect().size.y * 0.42  # leave bottom space
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

	# NPC sprite placeholder slot
	var npc := Sprite2D.new()
	npc.name = "NPCSprite"
	npc.centered = true
	npc.position = view.get_viewport_rect().size / 2
	npc.position.y -= 60
	view.add_child(npc)

	# Bottom menu panel (< half)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.42)
	panel.offset_top = -get_viewport_rect().size.y * 0.42
	panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var sbp := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sbp:
		sbp.bg_color = Color(0xD7,0xC0,0x93, 0.96)
		sbp.border_color = Color(0x4A,0x3E,0x2A)
		sbp.set_border_width_all(2)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	timer_popup = preload("res://timer_popup.gd").new()
	add_child(timer_popup)

	trainer_name_label = Label.new()
	trainer_name_label.name = "TrainerName"
	trainer_name_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(trainer_name_label)

	trainer_bar = ProgressBar.new()
	trainer_bar.name = "TrainerBar"
	trainer_bar.max_value = TRAINER_MAX_HP
	trainer_bar.custom_minimum_size = Vector2(0, 24)
	trainer_bar.show_percentage = false
	vbox.add_child(trainer_bar)

	trainer_hp_label = Label.new()
	trainer_hp_label.name = "TrainerHpLabel"
	trainer_hp_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(trainer_hp_label)

	message_label = Label.new()
	message_label.name = "Message"
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)

	result_label = Label.new()
	result_label.name = "Result"
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(result_label)

	question_label = Label.new()
	question_label.name = "Question"
	question_label.add_theme_font_size_override("font_size", 26)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(question_label)

	time_label = Label.new()
	time_label.name = "Clock"
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(time_label)

	options_box = VBoxContainer.new()
	options_box.name = "Options"
	options_box.add_theme_constant_override("separation", 10)
	vbox.add_child(options_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	player_bar = ProgressBar.new()
	player_bar.name = "PlayerBar"
	player_bar.max_value = PLAYER_MAX_HP
	player_bar.custom_minimum_size = Vector2(0, 24)
	player_bar.show_percentage = false
	vbox.add_child(player_bar)

	player_stats_label = Label.new()
	player_stats_label.name = "Stats"
	player_stats_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(player_stats_label)

func start_battle() -> void:
	player_hp = PLAYER_MAX_HP
	player_mana = PLAYER_MAX_MANA
	trainer_hp = TRAINER_MAX_HP
	seen.clear()
	phase = Phase.PLAYER_ATTACK
	if trainer_name_label: trainer_name_label.text = TRAINER_NAME
	var mode := "solo" if answer_seconds == SOLO_ANSWER_SECONDS else "twitch"
	if message_label: message_label.text = "A trivia match begins! (%s · %ds per question)" % [mode, int(answer_seconds)]
	if result_label: result_label.text = ""
	_refresh_stats()
	_next_question()

func _refresh_stats() -> void:
	if trainer_bar: trainer_bar.value = max(trainer_hp, 0)
	if trainer_hp_label: trainer_hp_label.text = "Trainer HP: %d/%d" % [max(trainer_hp, 0), TRAINER_MAX_HP]
	if player_bar: player_bar.value = max(player_hp, 0)
	if player_stats_label: player_stats_label.text = "Your HP: %d/%d    Mana: %d/%d" % [
		max(player_hp, 0), PLAYER_MAX_HP, player_mana, PLAYER_MAX_MANA]

func _clear_options() -> void:
	if options_box:
		for child in options_box.get_children():
			child.queue_free()

func _next_question() -> void:
	_clear_options()
	match phase:
		Phase.PLAYER_ATTACK:
			if message_label: message_label.text = "Your turn — answer to attack!"
			current_question = _pick(starter_bank)
		Phase.PLAYER_DEFEND:
			if message_label: message_label.text = "Incoming! Answer to defend."
		Phase.LAST_CHANCE:
			if message_label: message_label.text = "LAST CHANCE! Their final question."
		Phase.WON:
			_show_end("You win! %s yields their question set." % TRAINER_NAME)
			return
		Phase.LOST:
			_show_end("You lose... ashamed, you run away.")
			return

	time_left = answer_seconds
	_draw_time()
	if timer_popup: timer_popup.set_timer(answer_seconds)
	current_question = _pick(GD.TRAINERS[TRAINER_NAME])
	if question_label: question_label.text = current_question["question"]
	for choice in GD.choices(current_question):
		var b := Button.new()
		b.text = choice
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(answer.bind(choice))
		THEME.style_button(b)
		if options_box: options_box.add_child(b)
	_refresh_stats()

func _pick(bank: Array) -> Dictionary:
	var unseen: Array = []
	for q in bank:
		if not seen.has(q["id"]):
			unseen.append(q)
	var pool: Array = unseen if not unseen.is_empty() else bank
	return pool[randi() % pool.size()]

func _done() -> bool:
	return phase == Phase.WON or phase == Phase.LOST

## Called by an answer button (and by tests).
func answer(choice: String) -> void:
	if _done():
		return
	_resolve_question(choice == current_question["correct"], false)

## Called when the countdown reaches zero — counts as a wrong answer, with
## its own message.
func _timeout() -> void:
	if _done():
		return
	_resolve_question(false, true)

func _resolve_question(correct: bool, timed_out: bool) -> void:
	match phase:
		Phase.PLAYER_ATTACK:
			if correct:
				var dmg := BASE_DAMAGE if not seen.has(current_question["id"]) else HALF_DAMAGE
				seen[current_question["id"]] = true
				trainer_hp -= dmg
				if result_label: result_label.text = "Correct! You deal %d damage." % dmg
			elif timed_out:
				if result_label: result_label.text = "Time's up! No damage."
			else:
				if result_label: result_label.text = "Wrong! No damage this turn."
			if trainer_hp <= 0:
				phase = Phase.WON
			elif trainer_hp <= int(TRAINER_MAX_HP * LAST_CHANCE_THRESHOLD):
				phase = Phase.LAST_CHANCE
			else:
				phase = Phase.PLAYER_DEFEND
		Phase.PLAYER_DEFEND, Phase.LAST_CHANCE:
			if correct:
				if result_label: result_label.text = "Correct! You hold them off."
			else:
				player_hp -= TRAINER_DAMAGE
				if timed_out:
					if result_label: result_label.text = "Time's up! You take %d damage." % TRAINER_DAMAGE
				else:
					if result_label: result_label.text = "Wrong! You take %d damage." % TRAINER_DAMAGE
			if player_hp <= 0:
				phase = Phase.LOST
			elif phase == Phase.LAST_CHANCE and correct:
				phase = Phase.WON
			else:
				phase = Phase.PLAYER_ATTACK
	_refresh_stats()
	_next_question()

func _show_end(text: String) -> void:
	if time_label: time_label.text = ""
	if timer_popup: timer_popup.hide()
	if question_label: question_label.text = text
	var again := Button.new()
	again.text = "Fight again"
	again.custom_minimum_size = Vector2(0, 40)
	again.pressed.connect(start_battle)
	THEME.style_button(again)
	if options_box: options_box.add_child(again)

	var back := Button.new()
	back.text = "Back to title"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://main.tscn"))
	THEME.style_button(back)
	if options_box: options_box.add_child(back)
	_refresh_stats()