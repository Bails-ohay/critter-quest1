extends CharacterBody3D

const SPEED = 4.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const STAMINA_REGEN_RATE := 10.0          # normal (out of combat) stamina regen per second
const STAMINA_COMBAT_REGEN_RATE := 3.5    # stamina regen per second while in combat
const SPRINT_SPEED_MULTIPLIER := 1.8
const SPRINT_STAMINA_DRAIN := 5.0         # stamina per second while sprinting
const COMBAT_TIMEOUT := 5.0               # seconds after last damage taken/dealt before leaving combat

signal health_changed(current: float, max_amount: float)
signal mana_changed(current: float, max_amount: float)
signal stamina_changed(current: float, max_amount: float)
signal armor_changed(current: float)
signal xp_changed(current: int, to_next: int, level: int)

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot

var stone := 0

# --- Base stats: the character's "natural" values before any gear ---
@export var base_max_health := 100.0
@export var base_max_mana := 100.0
@export var base_mana_regen := 10.0       # normal (out of combat) mana regen per second
@export var mana_combat_regen_rate := 3.5 # mana regen per second while in combat
@export var base_max_stamina := 100.0
@export var base_armor := 0.0             # hidden stat — no HUD element, used for damage mitigation

# --- XP / leveling (WoW-like power curve, small tunable numbers) ---
@export var xp_base := 50.0
@export var xp_curve_exponent := 1.5

# --- Derived (current) stats: base + whatever's currently equipped ---
var max_health := 100.0
var health := 100.0
var max_mana := 100.0
var mana := 100.0
var mana_regen_rate := 10.0
var max_stamina := 100.0
var stamina := 100.0
var armor := 0.0

var level := 1
var xp := 0
var xp_to_next_level := 0

var is_sprinting := false   # tracked here so _process() can see it too
var in_combat := false
var combat_timer := 0.0

# One dictionary per stat, each mapping item_id -> bonus from that item.
var stat_modifiers := {
	"max_health": {},
	"max_mana": {},
	"mana_regen": {},
	"max_stamina": {},
	"armor": {},
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_recalculate_stats()
	health = max_health
	mana = max_mana
	stamina = max_stamina
	xp_to_next_level = _xp_required_for_level(level)
	%HUD.setup(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(20))

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen_center := get_viewport().get_visible_rect().size / 2
		var from: Vector3 = camera.project_ray_origin(screen_center)
		var to: Vector3 = from + camera.project_ray_normal(screen_center) * 100
		var query := PhysicsRayQueryParameters3D.create(from, to)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			var hit_object = result.collider
			if hit_object.has_method("harvest"):
				var amount = hit_object.harvest()
				stone += amount
				print("Stone: ", stone)
			elif hit_object.has_method("take_damage"):
				hit_object.take_damage(5)
				_enter_combat()   # landing a hit counts as "causing damage"
			else:
				print("Clicked on: ", hit_object.name)
		else:
			print("Clicked on nothing")

	# TEMP TEST KEYS — remove once you're happy things work.
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			take_damage(15.0)
		elif event.keycode == KEY_J:
			apply_item_stats("test_gear", {"max_health": 20.0, "armor": 10.0})
		elif event.keycode == KEY_K:
			remove_item_stats("test_gear")
		elif event.keycode == KEY_X:
			add_xp(25)
		elif event.keycode == KEY_T:
			try_spend_stamina(10.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	is_sprinting = Input.is_action_pressed("sprint") and direction != Vector3.ZERO and stamina > 0.0
	var current_speed: float = SPRINT_SPEED_MULTIPLIER * SPEED if is_sprinting else SPEED

	if is_sprinting:
		stamina = max(stamina - SPRINT_STAMINA_DRAIN * delta, 0.0)
		stamina_changed.emit(stamina, max_stamina)

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _process(delta: float) -> void:
	if in_combat:
		combat_timer -= delta
		if combat_timer <= 0.0:
			in_combat = false

	var current_stamina_regen: float = STAMINA_COMBAT_REGEN_RATE if in_combat else STAMINA_REGEN_RATE
	if stamina < max_stamina and not is_sprinting:
		stamina = min(stamina + current_stamina_regen * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)

	var current_mana_regen: float = mana_combat_regen_rate if in_combat else mana_regen_rate
	if mana < max_mana:
		mana = min(mana + current_mana_regen * delta, max_mana)
		mana_changed.emit(mana, max_mana)

func _enter_combat() -> void:
	in_combat = true
	combat_timer = COMBAT_TIMEOUT

func take_damage(amount: float) -> void:
	var reduction: float = clamp(armor, 0.0, 100.0) / 100.0
	var mitigated: float = amount * (1.0 - reduction)
	health = clamp(health - mitigated, 0.0, max_health)
	health_changed.emit(health, max_health)
	if mitigated > 0.0:
		_enter_combat()   # only losing health counts — healing never touches this
	if health <= 0.0:
		_die()

func heal(amount: float) -> void:
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	# Deliberately does NOT call _enter_combat() — healing spells will use this later.

func _die() -> void:
	print("Player died!")
	# Placeholder — hook up a respawn / game-over flow here later.

func try_spend_mana(amount: float) -> bool:
	if mana >= amount:
		mana -= amount
		mana_changed.emit(mana, max_mana)
		return true
	return false

func try_spend_stamina(amount: float) -> bool:
	if stamina >= amount:
		stamina -= amount
		stamina_changed.emit(stamina, max_stamina)
		return true
	return false

func increase_max_health(amount: float) -> void:
	base_max_health += amount
	health += amount
	_recalculate_stats()

func increase_max_mana(amount: float) -> void:
	base_max_mana += amount
	mana += amount
	_recalculate_stats()

func increase_max_stamina(amount: float) -> void:
	base_max_stamina += amount
	stamina += amount
	_recalculate_stats()

func increase_armor(amount: float) -> void:
	base_armor += amount
	_recalculate_stats()

func apply_item_stats(item_id: String, bonuses: Dictionary) -> void:
	for stat_name in bonuses:
		if stat_modifiers.has(stat_name):
			stat_modifiers[stat_name][item_id] = bonuses[stat_name]
		else:
			push_warning("Unknown stat '%s' on item '%s' — ignored." % [stat_name, item_id])
	_recalculate_stats()

func remove_item_stats(item_id: String) -> void:
	for stat_name in stat_modifiers:
		stat_modifiers[stat_name].erase(item_id)
	_recalculate_stats()

func _recalculate_stats() -> void:
	max_health = base_max_health + _sum_modifiers("max_health")
	health = min(health, max_health)
	health_changed.emit(health, max_health)

	max_mana = base_max_mana + _sum_modifiers("max_mana")
	mana = min(mana, max_mana)
	mana_changed.emit(mana, max_mana)

	mana_regen_rate = base_mana_regen + _sum_modifiers("mana_regen")

	max_stamina = base_max_stamina + _sum_modifiers("max_stamina")
	stamina = min(stamina, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

	armor = base_armor + _sum_modifiers("armor")
	armor_changed.emit(armor)

func _sum_modifiers(stat_name: String) -> float:
	var total := 0.0
	for bonus in stat_modifiers[stat_name].values():
		total += bonus
	return total

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = _xp_required_for_level(level)
		_on_level_up()
	xp_changed.emit(xp, xp_to_next_level, level)

func _xp_required_for_level(lvl: int) -> int:
	return int(round(xp_base * pow(lvl, xp_curve_exponent)))

func _on_level_up() -> void:
	print("Level up! Now level ", level)
	# Placeholder — this is where you'd grant stat points later, e.g.:
	# increase_max_health(10.0)
