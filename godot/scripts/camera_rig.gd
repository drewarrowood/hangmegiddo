class_name CameraRig
extends Node3D
## Fluid RTS camera: orbit, pan, pinch-zoom. Touch + mouse.

signal ground_clicked(pos: Vector3, shift: bool)
signal unit_clicked(unit: BattleUnit, shift: bool)
signal empty_drag_end()

@export var move_speed: float = 28.0
@export var zoom_min: float = 18.0
@export var zoom_max: float = 90.0
@export var pitch_min: float = -70.0
@export var pitch_max: float = -25.0

var _cam: Camera3D
var _pivot_height: float = 0.0
var _distance: float = 48.0
var _yaw: float = 0.0
var _pitch: float = -48.0
var _target_pos: Vector3 = Vector3(0, 0, 20)
var _smooth_pos: Vector3 = Vector3(0, 0, 20)
var _smooth_dist: float = 48.0

# touch state
var _touches: Dictionary = {} ## index -> position
var _dragging_pan: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _orbiting: bool = false
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 0.0
var _ground_plane := Plane(Vector3.UP, 0.0)
var _was_tap: bool = false
var _tap_pos: Vector2 = Vector2.ZERO
var _tap_time: float = 0.0

var unit_layer_mask: int = 2


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 42.0
	_cam.near = 0.3
	_cam.far = 400.0
	add_child(_cam)
	_smooth_pos = _target_pos
	_smooth_dist = _distance
	_apply_camera(1.0)


func focus_on(world_pos: Vector3) -> void:
	_target_pos = world_pos


func _process(delta: float) -> void:
	_handle_keyboard(delta)
	_smooth_pos = _smooth_pos.lerp(_target_pos, clampf(delta * 6.0, 0.0, 1.0))
	_smooth_dist = lerpf(_smooth_dist, _distance, clampf(delta * 8.0, 0.0, 1.0))
	_apply_camera(delta)
	if _tap_time > 0.0:
		_tap_time -= delta


func _apply_camera(_delta: float) -> void:
	var pitch_r := deg_to_rad(_pitch)
	var yaw_r := deg_to_rad(_yaw)
	var offset := Vector3(
		cos(pitch_r) * sin(yaw_r),
		-sin(pitch_r),
		cos(pitch_r) * cos(yaw_r)
	) * _smooth_dist
	_cam.global_position = _smooth_pos + Vector3(0, _pivot_height, 0) + offset
	_cam.look_at(_smooth_pos + Vector3(0, 1.0, 0), Vector3.UP)


func _handle_keyboard(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if v != Vector3.ZERO:
		v = v.normalized()
		var forward := Vector3(sin(deg_to_rad(_yaw)), 0, cos(deg_to_rad(_yaw)))
		var right := Vector3(forward.z, 0, -forward.x)
		_target_pos += (right * v.x + forward * -v.z) * move_speed * delta
		_clamp_target()


func _clamp_target() -> void:
	_target_pos.x = clampf(_target_pos.x, -70.0, 70.0)
	_target_pos.z = clampf(_target_pos.z, -70.0, 75.0)
	_target_pos.y = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 3.5, zoom_min, zoom_max)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 3.5, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_orbiting = true
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_orbiting = false
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_pointer_down(mb.position, 0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_on_pointer_up(mb.position, 0)

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			_yaw -= mm.relative.x * 0.25
			_pitch = clampf(_pitch - mm.relative.y * 0.2, pitch_min, pitch_max)
		elif _dragging_pan and _touches.size() <= 1:
			_pan_from_screen_delta(mm.relative)

	# Touch
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_on_pointer_down(st.position, st.index)
			elif _touches.size() == 2:
				_dragging_pan = false
				var pts: Array = _touches.values()
				_pinch_start_dist = pts[0].distance_to(pts[1])
				_pinch_start_zoom = _distance
		else:
			if _touches.size() == 1 and _touches.has(st.index):
				_on_pointer_up(st.position, st.index)
			_touches.erase(st.index)
			if _touches.size() < 2:
				_pinch_start_dist = 0.0

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts2: Array = _touches.values()
			var d: float = pts2[0].distance_to(pts2[1])
			if _pinch_start_dist > 1.0:
				var ratio: float = _pinch_start_dist / maxf(d, 1.0)
				_distance = clampf(_pinch_start_zoom * ratio, zoom_min, zoom_max)
			# two-finger orbit lightly
			_yaw -= sd.relative.x * 0.12
			_pitch = clampf(_pitch - sd.relative.y * 0.1, pitch_min, pitch_max)
		elif _dragging_pan:
			_pan_from_screen_delta(sd.relative)


func _pan_from_screen_delta(rel: Vector2) -> void:
	var scale: float = _smooth_dist * 0.0025
	var forward := Vector3(sin(deg_to_rad(_yaw)), 0, cos(deg_to_rad(_yaw)))
	var right := Vector3(forward.z, 0, -forward.x)
	_target_pos += (-right * rel.x + forward * rel.y) * scale
	_clamp_target()


func _on_pointer_down(screen_pos: Vector2, _idx: int) -> void:
	_drag_start = screen_pos
	_dragging_pan = true
	_was_tap = true
	_tap_pos = screen_pos


func _on_pointer_up(screen_pos: Vector2, _idx: int) -> void:
	var moved: float = screen_pos.distance_to(_drag_start)
	_dragging_pan = false
	if moved < 14.0 and _was_tap:
		_handle_tap(screen_pos)
	_was_tap = false


func _handle_tap(screen_pos: Vector2) -> void:
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var result := _raycast(screen_pos)
	if result.is_empty():
		return
	var collider = result.get("collider")
	if collider is BattleUnit:
		unit_clicked.emit(collider as BattleUnit, shift)
		return
	# climb parents
	var n: Node = collider
	while n:
		if n is BattleUnit:
			unit_clicked.emit(n as BattleUnit, shift)
			return
		n = n.get_parent()
	var pos: Vector3 = result.get("position", Vector3.ZERO)
	pos.y = 0.0
	ground_clicked.emit(pos, shift)


func _raycast(screen_pos: Vector2) -> Dictionary:
	if _cam == null:
		return {}
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var to := from + dir * 500.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 2 | 4
	return space.intersect_ray(q)


func get_camera() -> Camera3D:
	return _cam
