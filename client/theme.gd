extends RefCounted

## First-pass "scrapbook" visual theme: pre-1930s public-domain palette,
## era-flavored fonts, and buttons that sit at slightly random angles like
## scraps that fell onto the screen. Replaced with scanned paper elements
## later; for now simple rectangles do the work.
##
## Palette (from the design notes): navy blues, dark scholarly reds as
## accents, emerald greens, antique white, muddy sepia and parchment.

const NAVY := Color8(0x1F, 0x2A, 0x44)
const NAVY_DARK := Color8(0x10, 0x16, 0x28)
const WINE := Color8(0x9A, 0x2A, 0x3A)  # Brighter for attention (health/trainer)
const WINE_DARK := Color8(0x7A, 0x20, 0x2A)
const EMERALD := Color8(0x2E, 0x5E, 0x3A)
const EMERALD_DARK := Color8(0x1E, 0x3E, 0x26)
const ANTIQUE := Color8(0xFB, 0xF4, 0xDE)
const PARCHMENT := Color8(0xD7, 0xC0, 0x93)
const PARCHMENT_DARK := Color8(0x4A, 0x3E, 0x2A)
const SEPIA_INK := Color8(0x40, 0x33, 0x20)

const BODY_FONT := preload("res://fonts/SpecialElite-Regular.ttf")
const HEAD_FONT := preload("res://fonts/IMFeENrm28P.ttf")
const HEAD_FONT_IT := preload("res://fonts/IMFeENit28P.ttf")

## Style every Control under root: labels get palette + era fonts, buttons
## get navy paper-slips with a small random tilt, bars get parchment tracks.
static func apply(root: Node) -> void:
	_walk(root)

static func _walk(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			_style_button(child as Button)
		elif child is Label:
			_style_label(child as Label)
		elif child is ProgressBar:
			_style_bar(child as ProgressBar, _is_trainer_bar(child))
		_walk(child)

static func _is_trainer_bar(bar: Node) -> bool:
	return bar.name.begins_with("trainer") or bar.name.begins_with("Trainer")

## Style a freshly-created button (used by dynamic option rows): navy slip
## with antique-white type, tilted a few degrees so no two sit quite square.
static func _style_button(btn: Button) -> void:
	btn.add_theme_font_override("font", BODY_FONT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", ANTIQUE)
	btn.add_theme_color_override("font_hover_color", PARCHMENT)
	btn.add_theme_color_override("font_pressed_color", ANTIQUE)
	btn.add_theme_color_override("font_focus_color", ANTIQUE)
	btn.add_theme_stylebox_override("normal", _rect_style(NAVY, NAVY_DARK))
	btn.add_theme_stylebox_override("hover", _rect_style(NAVY.lightened(0.08), NAVY_DARK))
	btn.add_theme_stylebox_override("pressed", _rect_style(NAVY_DARK, NAVY_DARK))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.rotation = deg_to_rad(randf_range(-6.0, 6.0))  # Slightly more ajar

static func _rect_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## Public entry for styling dynamic buttons (option rows, end-screen).
static func style_button(btn: Button) -> void:
	_style_button(btn)

## Labels: large sizes get the antique serif (headings), the rest the
## typewriter face. Color by role.
static func _style_label(lbl: Label) -> void:
	if lbl.name == "Result":
		lbl.add_theme_font_override("font", HEAD_FONT_IT)
		lbl.add_theme_color_override("font_color", SEPIA_INK)
		return
	var big := lbl.get_theme_font_size("font_size") >= 22
	if big:
		lbl.add_theme_font_override("font", HEAD_FONT)
	else:
		lbl.add_theme_font_override("font", BODY_FONT)
	if lbl.name == "Title" or lbl.name == "TrainerName" or lbl.name == "TrainerNameLabel":
		lbl.add_theme_color_override("font_color", NAVY)
	else:
		lbl.add_theme_color_override("font_color", SEPIA_INK)

static func _style_bar(bar: ProgressBar, trainer: bool) -> void:
	bar.add_theme_stylebox_override("background", _rect_style(PARCHMENT_DARK, PARCHMENT_DARK))
	var fill_color := WINE if trainer else EMERALD
	bar.add_theme_stylebox_override("fill", _rect_style(fill_color, fill_color))

## Background parchment for a full-rect scene.
static func make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = PARCHMENT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg