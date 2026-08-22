extends Node3D
class_name GuidingArrow

@export var fade_duration: float = 0.4
@export var hover_height: float = 2.5
@export var forward_axis: Vector3 = Vector3(-1, 0, 0)
@export var player: Node3D = null

var _mesh: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _fade_tween: Tween = null
var _target_alpha := 0.0

func _ready() -> void:
	_mesh = _find_mesh()
	if _mesh != null:
		var mat := _mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			_material = (mat as StandardMaterial3D).duplicate()
			_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_material.albedo_color.a = 0.0
			_mesh.material_override = _material
	if player == null:
		var players := get_tree().get_nodes_in_group(Definitions.PLAYER_GROUP)
		if not players.is_empty():
			player = players[0]
	if _material == null:
		visible = false

func _process(_delta: float) -> void:
	var active := DeliveryManager.is_delivering() or DeliveryManager.is_returning()
	_set_faded(active)
	if not active or player == null:
		return
	global_position = player.global_position + Vector3.UP * hover_height
	var dir := DeliveryManager.target_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var f := forward_axis.normalized()
	rotation.y = atan2(f.cross(dir).y, f.dot(dir))

func _set_faded(active: bool) -> void:
	var target_alpha := 1.0 if active else 0.0
	if target_alpha == _target_alpha:
		return
	_target_alpha = target_alpha
	if _material == null:
		visible = active
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_material, "albedo_color:a", target_alpha, fade_duration)

func _find_mesh() -> MeshInstance3D:
	var arrow_node := get_node_or_null("arrow")
	if arrow_node != null and arrow_node.get_child_count() > 0:
		var first := arrow_node.get_child(0)
		if first is MeshInstance3D:
			return first
	if arrow_node != null:
		return _first_mesh_instance(arrow_node)
	return _first_mesh_instance(self)

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found != null:
			return found
	return null