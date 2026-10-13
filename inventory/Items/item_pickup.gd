extends StaticBody3D

@export var item: InventoryItem

func pick_up(player: Node) -> void:
	if player.inventory.add_item(item):
		queue_free()
