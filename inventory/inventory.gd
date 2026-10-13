extends Resource

class_name Inventory

signal inventory_changed()

@export var item: Array[InventoryItem]

func add_item(new_item: InventoryItem) -> bool:
	for i in item.size():
		if item[i] == null:
			item[i] = new_item
			inventory_changed.emit()
			return true
	return false
