extends Node3D
class_name Backpack

signal snack_added(snack: Snack)
signal snack_removed(snack: Snack)

var snack: Snack = null

func has_snack() -> bool:
	return snack != null

func add_snack(new_snack: Snack) -> bool:
	print(new_snack)
	if has_snack() or new_snack == null:
		return false
	snack = new_snack
	snack_added.emit(snack)
	return true

func remove_snack() -> Snack:
	var removed := snack
	snack = null
	if removed != null:
		snack_removed.emit(removed)
	return removed

static func from_player(player: Node) -> Backpack:
	return player.get_node_or_null("Backpack") as Backpack
