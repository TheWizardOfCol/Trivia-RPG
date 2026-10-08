extends Control

## Chat vote HUD: polls the backend for the current vote round and renders
## live totals. Rows are rebuilt when the question changes; counts and bars
## update in place between rebuilds. A closed round keeps its final tally on
## screen (with a "Closed:" header) until the next round opens.

const POLL_SECONDS := 3.0

@onready var question_label: Label = $Margin/VBox/Question
@onready var options_box: VBoxContainer = $Margin/VBox/Options
@onready var status_label: Label = $Margin/VBox/Status
@onready var http: HTTPRequest = $HTTP

var _rows: Dictionary = {}
var _current_question_id := ""

func _ready() -> void:
	http.timeout = 8.0
	http.request_completed.connect(_on_vote_response)
	print("Trivia-RPG HUD: polling %s" % Backend.vote_url())

	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()

	_poll()

func _poll() -> void:
	var err := http.request(Backend.vote_url())
	if err != OK:
		status_label.text = "Could not start request (error %d)" % err

func _on_vote_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Trivia-RPG HUD: poll finished — result=%d http=%d" % [result, code])
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status_label.text = "Backend unreachable (result %d · HTTP %d) — retrying" % [result, code]
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		status_label.text = "Unexpected response from backend"
		return

	_render(data)

func _render(data: Dictionary) -> void:
	# JSON null arrives as GDScript null — coerce before comparing.
	var question_id := _get_str(data, "questionId")
	var active := bool(data.get("active", false))
	var raw_options = data.get("options")
	var options: Array = raw_options if typeof(raw_options) == TYPE_ARRAY else []

	# No round has ever been opened on this backend.
	if question_id == "":
		question_label.text = "No vote yet — open one from the game or API"
		status_label.text = "Idle · polling every %ss · %s" % [str(POLL_SECONDS), Backend.vote_url()]
		_clear_rows()
		_current_question_id = ""
		return

	# Rebuild rows only when a new round replaces the old one.
	if question_id != _current_question_id:
		_current_question_id = question_id
		_clear_rows()
		for option in options:
			_rows[str(option.get("id", ""))] = _make_row(str(option.get("text", "")))

	var total := 0
	for option in options:
		total += _get_int(option, "votes")

	for option in options:
		var row: Dictionary = _rows.get(str(option.get("id", "")), {})
		if row.is_empty():
			continue
		var votes := _get_int(option, "votes")
		var pct := 0.0 if total == 0 else 100.0 * float(votes) / float(total)
		(row["count"] as Label).text = "%d votes · %d%%" % [votes, int(round(pct))]
		(row["bar"] as ProgressBar).value = pct

	if active:
		question_label.text = _get_str(data, "question", "?")
		status_label.text = "Live · closes in %s · %s" % [_time_left(data), Backend.vote_url()]
	else:
		# Round closed (manually or by timer) — keep the final tally on screen.
		question_label.text = "Closed: %s" % _get_str(data, "question", "?")
		status_label.text = "Final tally · %s" % Backend.vote_url()

func _get_str(data: Dictionary, key: String, fallback: String = "") -> String:
	var value = data.get(key)
	return fallback if value == null else str(value)

func _time_left(data: Dictionary) -> String:
	var closes_at := _get_int(data, "closesAtEpochMs")
	if closes_at <= 0:
		return "no time limit"
	var local_now := int(Time.get_unix_time_from_system() * 1000)
	var seconds := int(ceil(max(0, closes_at - local_now) / 1000.0))
	return _fmt_seconds(seconds)

func _get_int(data: Dictionary, key: String, fallback: int = 0) -> int:
	# JSON null arrives as GDScript null — int(null) is a runtime error.
	var value = data.get(key)
	if value == null:
		return fallback
	return int(value)

func _fmt_seconds(seconds: int) -> String:
	if seconds >= 60:
		return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%ds" % seconds

func _make_row(text: String) -> Dictionary:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(300, 0)

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(420, 24)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var count := Label.new()
	count.custom_minimum_size = Vector2(160, 0)

	row.add_child(label)
	row.add_child(bar)
	row.add_child(count)
	options_box.add_child(row)

	return {"label": label, "bar": bar, "count": count}

func _clear_rows() -> void:
	for child in options_box.get_children():
		child.queue_free()
	_rows.clear()
