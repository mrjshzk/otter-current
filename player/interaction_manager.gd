extends Area3D
class_name InteractionManager

const FALLBACK_KEY_ICON := preload("res://assets/textures/input_prompts/keyboard_e.png")

@export var interact_action: GUIDEAction

@onready var player: Player = get_parent()

var _interactables: Array[CollisionObject3D] = []
var _current_target: CollisionObject3D = null
var _last_text := ""
var _key_icon: Texture2D = null

func _ready() -> void:
	monitorable = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(Definitions.INTERACTION_PHYSICS_LAYER, true)

	body_entered.connect(_add_interactable)
	area_entered.connect(_add_interactable)
	body_exited.connect(_remove_interactable)
	area_exited.connect(_remove_interactable)

	interact_action.completed.connect(on_interact_pressed)

	DialogueManager.dialogue_started.connect(func(_resource: DialogueResource) -> void:
		_set_target_highlight(_current_target, false)
		_set_target_prompt_visible(_current_target, false)
	)
	DialogueManager.dialogue_ended.connect(func(_resource: DialogueResource) -> void:
		_refresh_prompt()
	)

	_load_key_icon()

func _physics_process(_delta: float) -> void:
	_update_target()

func _add_interactable(object: CollisionObject3D) -> void:
	if not _interactables.has(object):
		_interactables.append(object)

func _remove_interactable(object: CollisionObject3D) -> void:
	_interactables.erase(object)

func _nearest_interactable() -> CollisionObject3D:
	var stale: Array[CollisionObject3D] = []
	for object in _interactables:
		if not is_instance_valid(object):
			stale.append(object)
	for object in stale:
		_interactables.erase(object)
	var nearest: CollisionObject3D = null
	var best_distance := INF
	for object in _interactables:
		var distance := global_position.distance_squared_to(object.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = object
	return nearest

func _update_target() -> void:
	var nearest := _nearest_interactable()
	if nearest == _current_target:
		if is_instance_valid(nearest):
			var text := _prompt_text(nearest)
			if text != _last_text:
				_last_text = text
				if text.is_empty():
					_set_target_prompt_visible(nearest, false)
				else:
					_set_target_prompt(nearest, text, _key_icon)
		return
	_set_target_highlight(_current_target, false)
	_set_target_prompt_visible(_current_target, false)
	_current_target = nearest
	_refresh_prompt()

func _prompt_text(target) -> String:
	if target != null and is_instance_valid(target) and target.has_method("get_interaction_prompt"):
		return target.get_interaction_prompt(player)
	return ""

func _refresh_prompt() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		_last_text = ""
		return
	var text := _prompt_text(_current_target)
	_last_text = text
	if text.is_empty():
		_set_target_highlight(_current_target, false)
		_set_target_prompt_visible(_current_target, false)
		return
	_set_target_highlight(_current_target, true)
	_set_target_prompt(_current_target, text, _key_icon)

func _set_target_prompt(target, text: String, icon: Texture2D) -> void:
	if target != null and is_instance_valid(target) and target.has_method("set_prompt"):
		target.set_prompt(text, icon)

func _set_target_prompt_visible(target, v: bool) -> void:
	if target != null and is_instance_valid(target) and target.has_method("set_prompt_visible"):
		target.set_prompt_visible(v)

## The parameter is untyped on purpose: freed instances must reach the
## is_instance_valid guard instead of failing the typed call boundary.
func _set_target_highlight(target, enabled: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("set_highlighted"):
		target.set_highlighted(enabled)

func on_interact_pressed() -> void:
	var current_object := _nearest_interactable()
	if current_object == null:
		return

	if current_object.has_method("on_interact"):
		current_object.on_interact(player)

## Builds the key icon from the current GUIDE binding. Async because GUIDE
## renders icons off-thread and caches them. Falls back to a static icon.
func _load_key_icon() -> void:
	# wait a frame so the player has enabled the mapping context
	await get_tree().process_frame
	if interact_action == null:
		_key_icon = FALLBACK_KEY_ICON
		return
	var formatter := GUIDEInputFormatter.for_active_contexts(64)
	var bbcode := await formatter.action_as_richtext_async(interact_action)
	var path := bbcode.trim_prefix("[img]").trim_suffix("[/img]")
	if path.is_empty() or not ResourceLoader.exists(path):
		_key_icon = FALLBACK_KEY_ICON
		return
	_key_icon = load(path) as Texture2D
	if _key_icon == null:
		_key_icon = FALLBACK_KEY_ICON
	if is_instance_valid(_current_target) and not _last_text.is_empty():
		_refresh_prompt()
