extends Control
class_name GothicHUD

## ---------------------------------------------------------------------------
## Gothic Metal HUD — health/mana orbs + 9-slot hotbar + stamina/XP bars
## ---------------------------------------------------------------------------
## Drop this script onto any Control node (a child of a CanvasLayer in your
## main scene, or use the included GothicHUD.tscn). Everything is drawn
## procedurally in code — no image/font assets required — so it works as
## soon as the script is attached.
##
## WIRE UP YOUR PLAYER STATS by calling the public functions below whenever
## a stat changes (from your player/stats script, a signal callback, etc.):
##
##   hud.set_health(current_hp, max_hp)
##   hud.set_mana(current_mp, max_mp)
##   hud.set_stamina(current_sp, max_sp)
##   hud.set_xp(current_xp, xp_needed_for_next_level, current_level)
##   hud.set_selected_slot(slot_index)   # 1-9
##
## All bars fill by PERCENTAGE, so any max_* value works — the HUD scales
## automatically whether your player has 100 max HP or 100,000. Large
## numbers in the orbs auto-abbreviate (12,400 -> "12.4k") once they pass
## `abbreviate_threshold`; tweak or disable that below. `ui_scale` resizes
## the whole HUD (pivoted on its bottom-center anchor) and `font_scale`
## resizes just the text, for quick fitting to different resolutions.
## ---------------------------------------------------------------------------

# ============================= STAT CONFIG ==================================
@export var max_health: int = 140
@export var max_mana: int = 90
@export var max_stamina: float = 100.0
@export var xp_to_next_level: int = 100
@export var level: int = 12
@export var num_hotbar_slots: int = 9

## Visual scaling knobs
@export var ui_scale: float = 1.0:
	set(value):
		ui_scale = value
		if is_inside_tree() and _cluster:
			_cluster.scale = Vector2(ui_scale, ui_scale)
@export var font_scale: float = 1.0
@export var bottom_margin: float = 24.0

## Number formatting as stats scale up over the course of the game
@export var abbreviate_large_numbers: bool = true
@export var abbreviate_threshold: int = 10000

# ============================= PALETTE ======================================
const C_STEEL_DARK      := Color(0.11, 0.115, 0.13)
const C_STEEL_MID        := Color(0.19, 0.195, 0.21)
const C_STEEL_BORDER     := Color(0.42, 0.43, 0.47)
const C_STEEL_BORDER_DIM := Color(0.28, 0.285, 0.31)
const C_GLASS            := Color(0.09, 0.09, 0.105, 0.72)

const C_HEALTH  := Color(0.70, 0.17, 0.13)
const C_MANA    := Color(0.23, 0.38, 0.63)
const C_STAMINA := Color(0.85, 0.63, 0.22)
const C_XP      := Color(0.52, 0.28, 0.72)
const C_XP_GLOW := Color(0.72, 0.48, 0.90)

const C_TEXT     := Color(0.92, 0.92, 0.95)
const C_TEXT_DIM := Color(0.58, 0.58, 0.62)

# ============================= LAYOUT (px) ===================================
const ORB_SIZE    := 90.0
const ORB_OVERLAP := 12.0
const ORB_INSET   := 8.0
const SLOT_SIZE   := 34.0
const SLOT_GAP    := 4.0
const SLOT_CUT    := 0.28   # corner-cut fraction -> octagon "forged plate" shape
const BAR_WIDTH   := 254.0
const BAR_HEIGHT  := 7.0
const SIDE_COL    := 20.0  # fixed-width left/right columns so every bar lines up
const PANEL_PAD   := 8.0
const ROW_H       := 14.0
const ROW_GAP     := 5.0

# ============================= RUNTIME STATE =================================
var health: int
var mana: int
var stamina: float
var xp: int
var selected_slot: int = 1

var _cluster: Control
var _health_bar: TextureProgressBar
var _health_label: Label
var _mana_bar: TextureProgressBar
var _mana_label: Label
var _stamina_bar: ProgressBar
var _xp_bar: ProgressBar
var _xp_level_label: Label
var _hotbar_slots: Array = []  # [{glow, border, label}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	health = max_health
	mana = max_mana
	stamina = max_stamina
	xp = 0

	_build_ui()

	# --- Demo values so the HUD looks populated the first time you run it.
	# Replace these three calls with your real player stats. ---
	set_health(101, max_health)
	set_mana(41, max_mana)
	set_stamina(88.0, max_stamina)
	set_xp(34, xp_to_next_level, level)
	set_selected_slot(1)


# ============================================================================
# PUBLIC API
# ============================================================================

func set_health(current: int, new_max: int = -1) -> void:
	if new_max > 0:
		max_health = new_max
	health = clamp(current, 0, max_health)
	if _health_bar:
		_health_bar.value = _pct(health, max_health)
		_health_label.text = _format_number(health)


func set_mana(current: int, new_max: int = -1) -> void:
	if new_max > 0:
		max_mana = new_max
	mana = clamp(current, 0, max_mana)
	if _mana_bar:
		_mana_bar.value = _pct(mana, max_mana)
		_mana_label.text = _format_number(mana)


func set_stamina(current: float, new_max: float = -1.0) -> void:
	if new_max > 0.0:
		max_stamina = new_max
	stamina = clamp(current, 0.0, max_stamina)
	if _stamina_bar:
		_stamina_bar.value = _pct(stamina, max_stamina)


func set_xp(current_xp: int, to_next: int = -1, new_level: int = -1) -> void:
	if to_next > 0:
		xp_to_next_level = to_next
	if new_level > 0:
		level = new_level
	xp = clamp(current_xp, 0, xp_to_next_level)
	if _xp_bar:
		_xp_bar.value = _pct(xp, xp_to_next_level)
		_xp_level_label.text = _format_number(level)


func set_selected_slot(index: int) -> void:
	selected_slot = clamp(index, 1, num_hotbar_slots)
	for i in _hotbar_slots.size():
		var is_sel: bool = (i + 1 == selected_slot)
		var slot: Dictionary = _hotbar_slots[i]
		slot.glow.visible = is_sel
		slot.border.default_color = C_XP_GLOW if is_sel else C_STEEL_BORDER
		slot.label.add_theme_color_override("font_color", Color(0.95, 0.88, 1.0) if is_sel else C_TEXT_DIM)


# ============================================================================
# BUILD
# ============================================================================

func _build_ui() -> void:
	var panel_w: float = SLOT_SIZE * num_hotbar_slots + SLOT_GAP * (num_hotbar_slots - 1) + PANEL_PAD * 2.0
	var panel_h: float = PANEL_PAD * 2.0 + ROW_H * 2.0 + ROW_GAP * 2.0 + SLOT_SIZE

	var health_x: float = 0.0
	var panel_x: float = ORB_SIZE - ORB_OVERLAP
	var mana_x: float = panel_x + panel_w - ORB_OVERLAP
	var total_w: float = mana_x + ORB_SIZE
	var total_h: float = ORB_SIZE + 6.0 + 14.0 * font_scale  # orb + gap + caption

	_cluster = Control.new()
	_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cluster.size = Vector2(total_w, total_h)
	_cluster.pivot_offset = Vector2(total_w / 2.0, total_h)
	_cluster.scale = Vector2(ui_scale, ui_scale)
	add_child(_cluster)

	var health_info := _build_orb(_cluster, health_x, C_HEALTH)
	_health_bar = health_info.bar
	_health_label = health_info.label
	_add_orb_caption(_cluster, health_x, "Health")

	var panel_y: float = ORB_SIZE - panel_h
	var bars := _build_hotbar_panel(_cluster, Vector2(panel_x, panel_y), panel_w, panel_h)
	_xp_bar = bars.xp_bar
	_xp_level_label = bars.xp_level_label
	_stamina_bar = bars.stamina_bar

	var mana_info := _build_orb(_cluster, mana_x, C_MANA)
	_mana_bar = mana_info.bar
	_mana_label = mana_info.label
	_add_orb_caption(_cluster, mana_x, "Mana")

	_cluster.anchor_left = 0.5
	_cluster.anchor_right = 0.5
	_cluster.anchor_top = 1.0
	_cluster.anchor_bottom = 1.0
	_cluster.offset_left = -total_w / 2.0
	_cluster.offset_right = total_w / 2.0
	_cluster.offset_bottom = -bottom_margin
	_cluster.offset_top = -bottom_margin - total_h


func _build_orb(parent: Control, x: float, liquid_color: Color) -> Dictionary:
	var root := Control.new()
	root.position = Vector2(x, 0.0)
	root.size = Vector2(ORB_SIZE, ORB_SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var bezel := Panel.new()
	bezel.size = Vector2(ORB_SIZE, ORB_SIZE)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_STEEL_MID
	sb.set_border_width_all(3)
	sb.border_color = C_STEEL_BORDER
	sb.set_corner_radius_all(int(ORB_SIZE / 2.0))
	bezel.add_theme_stylebox_override("panel", sb)
	root.add_child(bezel)

	# 4 gothic claws gripping the bezel, N/E/S/W
	var center := Vector2(ORB_SIZE / 2.0, ORB_SIZE / 2.0)
	for dir in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_add_claw(root, center, ORB_SIZE / 2.0, dir, dir.orthogonal())

	var glass_size: float = ORB_SIZE - ORB_INSET * 2.0
	var glass := Panel.new()
	glass.position = Vector2(ORB_INSET, ORB_INSET)
	glass.size = Vector2(glass_size, glass_size)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = C_GLASS
	sb2.set_corner_radius_all(int(glass_size / 2.0))
	glass.add_theme_stylebox_override("panel", sb2)
	root.add_child(glass)

	var bar := TextureProgressBar.new()
	bar.position = Vector2(ORB_INSET, ORB_INSET)
	bar.size = Vector2(glass_size, glass_size)
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.min_value = 0
	bar.max_value = 100
	bar.step = 0.1
	bar.texture_progress = _make_circle_texture(int(glass_size), liquid_color)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	var value_label := Label.new()
	value_label.size = Vector2(ORB_SIZE, ORB_SIZE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", C_TEXT)
	value_label.add_theme_font_size_override("font_size", int(14 * font_scale))
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(value_label)

	return {"bar": bar, "label": value_label}


func _add_claw(parent: Node, center: Vector2, radius: float, dir: Vector2, perp: Vector2) -> void:
	var base_r: float = radius + 2.0
	var tip_r: float = radius - 9.0
	var spread: float = 6.0
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		center + dir * base_r + perp * spread,
		center + dir * base_r - perp * spread,
		center + dir * tip_r
	])
	poly.color = C_STEEL_BORDER
	parent.add_child(poly)


func _add_orb_caption(parent: Control, x: float, text: String) -> void:
	var label := Label.new()
	label.position = Vector2(x, ORB_SIZE + 6.0)
	label.size = Vector2(ORB_SIZE, 14.0)
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", C_TEXT_DIM)
	label.add_theme_font_size_override("font_size", int(9.5 * font_scale))
	label.add_theme_constant_override("line_spacing", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _build_hotbar_panel(parent: Control, pos: Vector2, panel_w: float, panel_h: float) -> Dictionary:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_STEEL_DARK
	sb.set_border_width_all(1)
	sb.border_color = C_STEEL_BORDER_DIM
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	# small corner rivets
	for corner in [Vector2(3, 3), Vector2(panel_w - 8, 3), Vector2(3, panel_h - 8), Vector2(panel_w - 8, panel_h - 8)]:
		var rivet := Polygon2D.new()
		rivet.polygon = PackedVector2Array([Vector2(0, 2.5), Vector2(2.5, 0), Vector2(5, 2.5), Vector2(2.5, 5)])
		rivet.position = corner
		rivet.color = C_STEEL_BORDER
		panel.add_child(rivet)

	var row_y: float = PANEL_PAD
	var xp_row := _build_resource_bar(panel, panel_w, row_y, "XP", C_XP, true)
	row_y += ROW_H + ROW_GAP
	var stamina_row := _build_resource_bar(panel, panel_w, row_y, "", C_STAMINA, false)
	row_y += ROW_H + ROW_GAP

	for i in num_hotbar_slots:
		var slot_x: float = PANEL_PAD + i * (SLOT_SIZE + SLOT_GAP)
		_build_slot(panel, Vector2(slot_x, row_y), i + 1)

	return {
		"xp_bar": xp_row.bar,
		"xp_level_label": xp_row.right_label,
		"stamina_bar": stamina_row.bar,
	}


func _build_resource_bar(panel: Control, panel_w: float, y: float, left_text: String, fill_color: Color, show_right: bool) -> Dictionary:
	# Center this row's (label + bar + label) block within the panel so both
	# resource rows share the exact same bar position/length, regardless of
	# whether the right-hand cell is used.
	var content_w: float = SIDE_COL * 2.0 + ROW_GAP * 2.0 + BAR_WIDTH
	var base_x: float = (panel_w - content_w) / 2.0
	var bar_x: float = base_x + SIDE_COL + ROW_GAP
	var bar := ProgressBar.new()
	bar.position = Vector2(bar_x, y + (ROW_H - BAR_HEIGHT) / 2.0)
	bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.min_value = 0
	bar.max_value = 100
	bar.step = 0.1
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = C_STEEL_DARK.darkened(0.15)
	sb_bg.set_corner_radius_all(3)
	sb_bg.set_border_width_all(1)
	sb_bg.border_color = Color(0.04, 0.04, 0.05)
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill_color
	sb_fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", sb_fill)
	panel.add_child(bar)

	if left_text != "":
		var left_label := Label.new()
		left_label.position = Vector2(base_x, y)
		left_label.size = Vector2(SIDE_COL, ROW_H)
		left_label.text = left_text
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		left_label.add_theme_color_override("font_color", fill_color.lightened(0.25))
		left_label.add_theme_font_size_override("font_size", int(9 * font_scale))
		panel.add_child(left_label)
	else:
		# small diamond "stamina" glyph in place of an icon font
		var glyph := Polygon2D.new()
		var s: float = 6.0
		glyph.polygon = PackedVector2Array([Vector2(s, 0), Vector2(s * 2, s), Vector2(s, s * 2), Vector2(0, s)])
		glyph.position = Vector2(base_x + (SIDE_COL - s * 2) / 2.0, y + (ROW_H - s * 2) / 2.0)
		glyph.color = fill_color
		panel.add_child(glyph)

	var right_label: Label = null
	if show_right:
		right_label = Label.new()
		right_label.position = Vector2(bar_x + BAR_WIDTH + ROW_GAP, y)
		right_label.size = Vector2(SIDE_COL, ROW_H)
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		right_label.add_theme_color_override("font_color", fill_color.lightened(0.3))
		right_label.add_theme_font_size_override("font_size", int(9 * font_scale))
		panel.add_child(right_label)

	return {"bar": bar, "right_label": right_label}


func _build_slot(parent: Control, pos: Vector2, number: int) -> void:
	var root := Control.new()
	root.position = pos
	root.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var glow := Polygon2D.new()
	glow.polygon = _octagon_points(SLOT_SIZE + 4.0, SLOT_CUT)
	glow.position = Vector2(-2, -2)
	glow.color = C_XP_GLOW
	glow.visible = false
	root.add_child(glow)

	var bg := Polygon2D.new()
	bg.polygon = _octagon_points(SLOT_SIZE, SLOT_CUT)
	bg.color = C_STEEL_DARK.lightened(0.05)
	root.add_child(bg)

	var pts := _octagon_points(SLOT_SIZE, SLOT_CUT)
	pts.append(pts[0])
	var border := Line2D.new()
	border.points = pts
	border.width = 2.0
	border.default_color = C_STEEL_BORDER
	root.add_child(border)

	var label := Label.new()
	label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	label.text = str(number)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(12 * font_scale))
	label.add_theme_color_override("font_color", C_TEXT_DIM)
	root.add_child(label)

	_hotbar_slots.append({"glow": glow, "border": border, "label": label})


# ============================================================================
# HELPERS
# ============================================================================

func _octagon_points(size: float, cut_frac: float) -> PackedVector2Array:
	var c: float = size * cut_frac
	return PackedVector2Array([
		Vector2(c, 0), Vector2(size - c, 0), Vector2(size, c), Vector2(size, size - c),
		Vector2(size - c, size), Vector2(c, size), Vector2(0, size - c), Vector2(0, c)
	])


func _make_circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r: float = size / 2.0
	for y in size:
		for x in size:
			var dx: float = x + 0.5 - r
			var dy: float = y + 0.5 - r
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _pct(current: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clamp(100.0 * current / max_value, 0.0, 100.0)


func _format_number(n: int) -> String:
	if not abbreviate_large_numbers or abs(n) < abbreviate_threshold:
		return str(n)
	if abs(n) >= 1000000:
		return "%.1fm" % (n / 1000000.0)
	return "%.1fk" % (n / 1000.0)
