extends Control

@onready var inv: Inventory = preload("res://inventory/playerinventory.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()


var is_open = false

func _ready():
	inv.inventory_changed.connect(update_slots)
	update_slots()
	close()

func update_slots():
	for i in range(min(inv.item.size(), slots.size())):
		slots[i].update(inv.item[i])

func _process(delta):
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
		else:
			open()

func open():
	self.visible = true
	is_open = true

func close():
	visible = false
	is_open = false
