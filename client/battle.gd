extends Control

## Battle slice, single-player. Turn flow (design doc v1 simplified):
##   ATTACK  — answer a question correctly to deal damage (full damage the
##             first time you see it, half on repeats). Wrong/timeout: none.
##   DEFEND  — they strike back; answer correctly to block, wrong/timeout
##             costs you HP.
##   LAST CHANCE — when the trainer drops below ~20% HP, one final question.
##             Correct finishes them.
##
## Every question comes from the trainer's own specialty set (game_data.gd,
## imported from the spreadsheet). The stock placeholder questions were
## removed by design.
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
var question_label: Label
var options_box: VBoxContainer
var player_bar: ProgressBar
var player_stats_label: Label

func _ready() -> void:
	answer_seconds = TWITCH_ANSWER_SECONDS if Backend.mode() == "twitch" else SOLO_ANSWER_SECONDS
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

func _draw_time() -> void:
	var secs := int(ceil(time_left))
	time_label.text = "%ds" % secs
	var urgent := secs <= URGENT_SECONDS
	time_label.add_theme_color_override("font_color", THEME.WINE if urgent else THEME.NAVY)

func _build_ui() -> void:
	add_child(THEME.make_background())

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	trainer_name_label = Label.new()
	trainer_name_label.name = "TrainerName"
	trainer_name_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(trainer_name_label)

	trainer_bar = ProgressBar.new()
	trainer_bar.name = "TrainerBar"
	trainer_bar.max_value = TRAINER_MAX_HP
	trainer_bar.custom_minimum_size = Vector2(0, 22)
	trainer_bar.show_percentage = false
	vbox.add_child(trainer_bar)

	trainer_hp_label = Label.new()
	trainer_hp_label.name = "TrainerHpLabel"
	trainer_hp_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(trainer_hp_label)

	message_label = Label.new()
	message_label.name = "Message"
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)

	result_label = Label.new()
	result_label.name = "Result"
	result_label.add_theme_font_size_override("font_size", 15)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(result_label)

	question_label = Label.new()
	question_label.name = "Question"
	question_label.add_theme_font_size_override("font_size", 22)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(question_label)

	time_label = Label.new()
	time_label.name = "Clock"
	time_label.add_theme_font_size_override("font_size", 26)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(time_label)

	options_box = VBoxContainer.new()
	options_box.name = "Options"
	options_box.add_theme_constant_override("separation", 8)
	vbox.add_child(options_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	player_bar = ProgressBar.new()
	player_bar.name = "PlayerBar"
	player_bar.max_value = PLAYER_MAX_HP
	player_bar.custom_minimum_size = Vector2(0, 22)
	player_bar.show_percentage = false
	vbox.add_child(player_bar)

	player_stats_label = Label.new()
	player_stats_label.name = "Stats"
	player_stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(player_stats_label)

func start_battle() -> void:
	player_hp = PLAYER_MAX_HP
	player_mana = PLAYER_MAX_MANA
	trainer_hp = TRAINER_MAX_HP
	seen.clear()
	phase = Phase.PLAYER_ATTACK
	trainer_name_label.text = TRAINER_NAME
	var mode := "solo" if answer_seconds == SOLO_ANSWER_SECONDS else "twitch"
	message_label.text = "A trivia match begins! (%s · %ds per question)" % [mode, int(answer_seconds)]
	result_label.text = ""
	_refresh_stats()
	_next_question()

func _refresh_stats() -> void:
	trainer_bar.value = max(trainer_hp, 0)
	trainer_hp_label.text = "Trainer HP: %d/%d" % [max(trainer_hp, 0), TRAINER_MAX_HP]
	player_bar.value = max(player_hp, 0)
	player_stats_label.text = "Your HP: %d/%d    Mana: %d/%d" % [
		max(player_hp, 0), PLAYER_MAX_HP, player_mana, PLAYER_MAX_MANA]

func _clear_options() -> void:
	for child in options_box.get_children():
		child.queue_free()

func _next_question() -> void:
	_clear_options()
	match phase:
		Phase.PLAYER_ATTACK:
			message_label.text = "Your turn — answer to attack!"
		Phase.PLAYER_DEFEND:
			message_label.text = "Incoming! Answer to defend."
		Phase.LAST_CHANCE:
			message_label.text = "LAST CHANCE! Their final question."
		Phase.WON:
			_show_end("You win! %s yields their question set." % TRAINER_NAME)
			return
		Phase.LOST:
			_show_end("You lose... ashamed, you run away.")
			return

	time_left = answer_seconds
	_draw_time()
	current_question = _pick(GD.TRAINERS[TRAINER_NAME])
	question_label.text = current_question["question"]
	for choice in GD.choices(current_question):
		var b := Button.new()
		b.text = choice
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(answer.bind(choice))
		THEME.style_button(b)
		options_box.add_child(b)
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
				result_label.text = "Correct! You deal %d damage." % dmg
			elif timed_out:
				result_label.text = "Time's up! No damage."
			else:
				result_label.text = "Wrong! No damage this turn."
			if trainer_hp <= 0:
				phase = Phase.WON
			elif trainer_hp <= int(TRAINER_MAX_HP * LAST_CHANCE_THRESHOLD):
				phase = Phase.LAST_CHANCE
			else:
				phase = Phase.PLAYER_DEFEND
		Phase.PLAYER_DEFEND, Phase.LAST_CHANCE:
			if correct:
				result_label.text = "Correct! You hold them off."
			else:
				player_hp -= TRAINER_DAMAGE
				if timed_out:
					result_label.text = "Time's up! You take %d damage." % TRAINER_DAMAGE
				else:
					result_label.text = "Wrong! You take %d damage." % TRAINER_DAMAGE
			if player_hp <= 0:
				phase = Phase.LOST
			elif phase == Phase.LAST_CHANCE and correct:
				phase = Phase.WON
			else:
				phase = Phase.PLAYER_ATTACK
	_refresh_stats()
	_next_question()

func _show_end(text: String) -> void:
	time_label.text = ""
	question_label.text = text
	var again := Button.new()
	again.text = "Fight again"
	again.custom_minimum_size = Vector2(0, 40)
	again.pressed.connect(start_battle)
	THEME.style_button(again)
	options_box.add_child(again)

	var back := Button.new()
	back.text = "Back to title"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://main.tscn"))
	THEME.style_button(back)
	options_box.add_child(back)
	_refresh_stats()