extends Control

const URGENT := 5

var time_left := 0.0
var urgent := false
var _tween: Tween

@onready var circle := ColorRect.new()
@onready var label := Label.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 10)
	custom_minimum_size = Vector2(90, 90)
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	circle.color = Color(0xFB, 0xF4, 0xDE, 0.98)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(circle)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color8(0x40,0x33,0x20))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func set_timer(total_secs: float) -> void:
	time_left = total_secs
	urgent = false
	_update_label()
	_reset_pulse()
	show()

func update_timer(dt: float) -> void:
	if not visible:
		return
	time_left = max(time_left - dt, 0.0)
	_update_label()
	var now_urgent := int(ceil(time_left)) <= URGENT and time_left > 0
	if now_urgent and not urgent:
		urgent = true
		_pulse()
	if time_left <= 0.0:
		hide()

func _update_label() -> void:
	label.text = "%ds" % int(ceil(time_left))

func _pulse() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_loops()
	circle.modulate = Color(1.0, 1.0, 1.0)
	_tween.tween_property(circle, "modulate", Color(1.25, 0.8, 0.8), 0.18)
	_tween.tween_property(circle, "modulate", Color(1.0, 1.0, 1.0), 0.18)

func _reset_pulse() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	circle.modulate = Color(1.0, 1.0, 1.0)
