extends CanvasLayer

@onready var gothic_hud = $GothicHUD

func setup(player) -> void:
	gothic_hud.set_health(int(player.health), int(player.max_health))
	gothic_hud.set_mana(int(player.mana), int(player.max_mana))
	gothic_hud.set_stamina(player.stamina, player.max_stamina)
	gothic_hud.set_xp(player.xp, player.xp_to_next_level, player.level)

	player.health_changed.connect(_on_health_changed)
	player.mana_changed.connect(_on_mana_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.xp_changed.connect(_on_xp_changed)

func _on_health_changed(current: float, max_amount: float) -> void:
	gothic_hud.set_health(int(current), int(max_amount))

func _on_mana_changed(current: float, max_amount: float) -> void:
	gothic_hud.set_mana(int(current), int(max_amount))

func _on_stamina_changed(current: float, max_amount: float) -> void:
	gothic_hud.set_stamina(current, max_amount)

func _on_xp_changed(current: int, to_next: int, lvl: int) -> void:
	gothic_hud.set_xp(current, to_next, lvl)
