extends Control

## First playable battle slice, single-player only.
##
## Turn flow (from the design doc, v1 simplified):
##   ATTACK  — answer a question from YOUR bank. Correct deals damage
##             (full damage first time, half on repeats). Wrong deals none.
##   DEFEND  — the trainer attacks; answer a question from THEIR bank.
##             Correct blocks. Wrong costs you HP.
##   LAST CHANCE — when the trainer drops below ~20% HP, one special
##             question. Correct finishes them.
##
## Question data is the placeholder bank in questions.gd; the real content
## (spreadsheet → Elements backend) replaces it later. Twitch voting is an
## optional overlay on the same answer loop — solo play is the baseline.

const QB := preload("res://questions.gd")

const PLAYER_MAX_HP := 30
const PLAYER_MAX_MANA := 10
const TRAINER_MAX_HP := 20
const BASE_DAMAGE := 5
const HALF_DAMAGE := 2
const TRAINER_DAMAGE := 4
const LAST_CHANCE_THRESHOLD := 0.2

enum Phase { PLAYER_ATTACK, PLAYER_DEFEND, LAST_CHANCE, WON, LOST }

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
var question_label: Label
var options_box: VBoxContainer
var player_bar: ProgressBar
var player_stats_label: Label

func _ready() -> void:
	_build_ui()
	start_battle()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	trainer_name_label = Label.new()
	trainer_name_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(trainer_name_label)

	trainer_bar = ProgressBar.new()
	trainer_bar.max_value = TRAINER_MAX_HP
	trainer_bar.custom_minimum_size = Vector2(0, 22)
	trainer_bar.show_percentage = false
	vbox.add_child(trainer_bar)

	trainer_hp_label = Label.new()
	trainer_hp_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(trainer_hp_label)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)

	question_label = Label.new()
	question_label.add_theme_font_size_override("font_size", 22)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(question_label)

	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 8)
	vbox.add_child(options_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	player_bar = ProgressBar.new()
	player_bar.max_value = PLAYER_MAX_HP
	player_bar.custom_minimum_size = Vector2(0, 22)
	player_bar.show_percentage = false
	vbox.add_child(player_bar)

	player_stats_label = Label.new()
	player_stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(player_stats_label)

func start_battle() -> void:
	player_hp = PLAYER_MAX_HP
	player_mana = PLAYER_MAX_MANA
	trainer_hp = TRAINER_MAX_HP
	seen.clear()
	phase = Phase.PLAYER_ATTACK
	trainer_name_label.text = "Bird Scientist"
	message_label.text = "A trivia match begins!"
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
			current_question = _pick(QB.PLAYER_SET)
		Phase.PLAYER_DEFEND:
			message_label.text = "Incoming! Answer to defend."
			current_question = _pick(QB.TRAINER_SET)
		Phase.LAST_CHANCE:
			message_label.text = "LAST CHANCE! Their final question."
			current_question = _pick(QB.TRAINER_SET)
		Phase.WON:
			_show_end("You win! The Bird Scientist yields their question set.")
			return
		Phase.LOST:
			_show_end("You lose... ashamed, you run away.")
			return

	question_label.text = current_question["question"]
	for choice in QB.choices(current_question):
		var b := Button.new()
		b.text = choice
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(answer.bind(choice))
		options_box.add_child(b)
	_refresh_stats()

func _pick(bank: Array) -> Dictionary:
	var unseen: Array = []
	for q in bank:
		if not seen.has(q["id"]):
			unseen.append(q)
	var pool: Array = unseen if not unseen.is_empty() else bank
	return pool[randi() % pool.size()]

## Called by an answer button (and by tests). Applies the result of the
## current question and moves to the next phase.
func answer(choice: String) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	var correct: bool = choice == current_question["correct"]
	match phase:
		Phase.PLAYER_ATTACK:
			if correct:
				var dmg := BASE_DAMAGE if not seen.has(current_question["id"]) else HALF_DAMAGE
				seen[current_question["id"]] = true
				trainer_hp -= dmg
				message_label.text = "Correct! You deal %d damage." % dmg
			else:
				message_label.text = "Wrong! No damage this turn."
			if trainer_hp <= 0:
				phase = Phase.WON
			elif trainer_hp <= int(TRAINER_MAX_HP * LAST_CHANCE_THRESHOLD):
				phase = Phase.LAST_CHANCE
			else:
				phase = Phase.PLAYER_DEFEND
		Phase.PLAYER_DEFEND, Phase.LAST_CHANCE:
			if correct:
				message_label.text = "Correct! You hold them off."
			else:
				player_hp -= TRAINER_DAMAGE
				message_label.text = "Wrong! You take %d damage." % TRAINER_DAMAGE
			if player_hp <= 0:
				phase = Phase.LOST
			elif phase == Phase.LAST_CHANCE and correct:
				phase = Phase.WON
			else:
				phase = Phase.PLAYER_ATTACK
	_refresh_stats()
	_next_question()

func _show_end(text: String) -> void:
	question_label.text = text
	var again := Button.new()
	again.text = "Fight again"
	again.custom_minimum_size = Vector2(0, 40)
	again.pressed.connect(start_battle)
	options_box.add_child(again)

	var back := Button.new()
	back.text = "Back to title"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://main.tscn"))
	options_box.add_child(back)
	_refresh_stats()