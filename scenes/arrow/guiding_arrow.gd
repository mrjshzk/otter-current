extends Node3D
class_name GuidingArrow

@export var fade_duration: float = 0.4
@export var hover_height: float = 25
@export var pixel_size: float = 0.2
@export var bob_amplitude: float = 0.5
@export var bob_speed: float = 2.0

var _sprite: Sprite3D = null
var _fade_tween: Tween = null
var _target_alpha := 0.0

func _ready() -> void:
	for child in get_children():
		if child is Sprite3D:
			_sprite = child
			break
	if _sprite != null:
		_sprite.pixel_size = pixel_size
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/marker.gdshader")
		mat.set_shader_parameter("albedo_texture", _sprite.texture)
		_sprite.material_override = mat
		_sprite.modulate.a = 0.0

func _process(_delta: float) -> void:
	var active := DeliveryManager.is_delivering() or DeliveryManager.is_returning()
	_set_faded(active)
	if not active:
		return
	var target := DeliveryManager.target_position()
	var bob := sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_amplitude
	global_position = target + Vector3.UP * (hover_height + bob)

func _set_faded(active: bool) -> void:
	var target_alpha := 1.0 if active else 0.0
	if target_alpha == _target_alpha:
		return
	_target_alpha = target_alpha
	if _sprite == null:
		visible = active
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_sprite, "modulate:a", target_alpha, fade_duration)
