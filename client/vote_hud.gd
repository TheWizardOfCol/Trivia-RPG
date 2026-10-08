extends Control

## Chat vote HUD: polls the backend for the current vote round and renders
## live totals. Rows are rebuilt when the question changes; counts and bars
## update in place between rebuilds.

const POLL_SECONDS := 3.0

@onready var question_label: Label = $Margin/VBox/Question
@onready var options_box: VBoxContainer = $Margin/VBox/Options
@onready var status_label: Label = $Margin/VBox/Status
@onready var http: HTTPRequest = $HTTP

var _rows: Dictionary = {}
var _current_question_id := ""

func _ready() -> void:
	http.request_completed.connect(_on_vote_response)

	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()

	_poll()

func _poll() -> void:
	var err := http.request(Backend.vote_url())
	if err != OK:
		status_label.text = "Could not reach backend (request failed to start)"

func _on_vote_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status_label.text = "Backend offline — showing last known state"
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		status_label.text = "Unexpected response from backend"
		return

	_render(data)
	status_label.text = "Live · polling every %ss · %s" % [str(POLL_SECONDS), Backend.vote_url()]

func _render(data: Dictionary) -> void:
	if not data.get("active", false):
		question_label.text = "No active vote right now"
		_clear_rows()
		_current_question_id = ""
		return

	question_label.text = str(data.get("question", "?"))

	var options: Array = data.get("options", [])
	var question_id := str(data.get("questionId", ""))
	if question_id != _current_question_id:
		_current_question_id = question_id
		_clear_rows()
		for option in options:
			_rows[str(option.get("id", ""))] = _make_row(str(option.get("text", "")))

	var total := 0
	for option in options:
		total += int(option.get("votes", 0))

	for option in options:
		var row: Dictionary = _rows.get(str(option.get("id", "")), {})
		if row.is_empty():
			continue
		var votes := int(option.get("votes", 0))
		var pct := 0.0 if total == 0 else 100.0 * float(votes) / float(total)
		(row["count"] as Label).text = "%d votes · %d%%" % [votes, int(round(pct))]
		(row["bar"] as ProgressBar).value = pct

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
