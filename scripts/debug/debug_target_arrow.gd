extends DebugDraw3D

const ARROW_HEIGHT := 5.0
const ARROW_COLOR := Color(1.0, 0.85, 0.1)
const LINE_WIDTH := 3.0

func _process(_delta: float) -> void:
	var island: Island = null
	if DeliveryManager.is_delivering():
		island = DeliveryManager.target_island
	elif DeliveryManager.is_returning():
		island = DeliveryManager.home_island
	if island == null or not is_instance_valid(island):
		return
	var origin := island.global_position
	var above := origin + Vector3.UP * ARROW_HEIGHT
	draw_arrow_line(above, origin, ARROW_COLOR, LINE_WIDTH)
	draw_circle(origin, Quaternion.IDENTITY, island.collision_radius, ARROW_COLOR, 1.0)