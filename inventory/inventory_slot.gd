extends Panel

@onready var sprite: Sprite2D = $Sprite2D

func update(item: InventoryItem) -> void:
	if item == null:
		sprite.visible = false
	else:
		sprite.texture = item.texture
		sprite.visible = true
