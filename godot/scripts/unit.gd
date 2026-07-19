class_name BattleUnit
extends CharacterBody3D
## Fluid RTS unit: steering, combat, selection, Egyptian/Canaanite look.

signal died(unit: BattleUnit)

var side: String = "egypt" ## egypt | canaan
var kind: String = "spearman"
var display_name: String = ""
var max_hp: float = 100.0
var hp: float = 100.0
var damage: float = 10.0
var attack_range: float = 2.0
var attack_cd: float = 1.0
var move_speed: float = 6.0
var radius: float = 0.5
var mass: float = 1.0

var selected: bool = false
var order: String = "idle" ## idle | move | attack | attack_move | hold
var move_target: Vector3 = Vector3.ZERO
var attack_target: BattleUnit = null
var _attack_timer: float = 0.0
var _bob_t: float = 0.0
var _alive: bool = true

var _mesh: MeshInstance3D
var _select_ring: MeshInstance3D
var _hp_bar: MeshInstance3D
var _body_mat: StandardMaterial3D
var _vel_smooth: Vector3 = Vector3.ZERO

const UnitDefsScript = preload("res://scripts/unit_defs.gd")


func setup(p_side: String, p_kind: String, pos: Vector3, p_name: String = "") -> void:
	side = p_side
	kind = p_kind
	var def: Dictionary = UnitDefsScript.get_def(kind)
	display_name = p_name if p_name != "" else str(def.get("label", kind))
	max_hp = float(def["hp"])
	hp = max_hp
	damage = float(def["damage"])
	attack_range = float(def["range"])
	attack_cd = float(def["attack_cd"])
	move_speed = float(def["speed"])
	radius = float(def["radius"])
	mass = float(def["mass"])
	# position set after enter tree (see place())
	_spawn_pos = pos
	_build_visual(def)
	collision_layer = 2
	collision_mask = 1 | 2
	floor_stop_on_slope = true
	_bob_t = randf() * TAU


var _spawn_pos: Vector3 = Vector3.ZERO


func place(pos: Vector3) -> void:
	_spawn_pos = pos
	if is_inside_tree():
		global_position = pos
	else:
		position = pos


func _enter_tree() -> void:
	if _spawn_pos != Vector3.ZERO or true:
		global_position = _spawn_pos


func _build_visual(def: Dictionary) -> void:
	var col: Color = def["color_egypt"] if side == "egypt" else def["color_canaan"]
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = col
	_body_mat.roughness = 0.55
	_body_mat.metallic = 0.15 if kind in ["chariot", "hero"] else 0.0
	if kind == "hero":
		_body_mat.emission_enabled = true
		_body_mat.emission = col * 0.35
		_body_mat.emission_energy_multiplier = 0.6

	var mesh_inst := MeshInstance3D.new()
	_mesh = mesh_inst
	var sc: Vector3 = def["scale"]
	if kind == "chariot":
		var box := BoxMesh.new()
		box.size = sc
		mesh_inst.mesh = box
		# wheels
		for x in [-0.7, 0.7]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.45
			cyl.bottom_radius = 0.45
			cyl.height = 0.15
			w.mesh = cyl
			w.rotation_degrees = Vector3(0, 0, 90)
			w.position = Vector3(x, -0.15, 0.5)
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.25, 0.18, 0.1)
			w.material_override = wm
			mesh_inst.add_child(w)
	else:
		var cap := CapsuleMesh.new()
		cap.radius = 0.28 * sc.x
		cap.height = sc.y
		mesh_inst.mesh = cap
		mesh_inst.position.y = sc.y * 0.5
	mesh_inst.material_override = _body_mat
	add_child(mesh_inst)

	# gold band for egypt / bronze for canaan
	var crest := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(0.35, 0.12, 0.35)
	crest.mesh = cmesh
	crest.position.y = (def["scale"] as Vector3).y + 0.15
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.75, 0.2) if side == "egypt" else Color(0.6, 0.4, 0.25)
	cm.metallic = 0.8
	cm.roughness = 0.3
	crest.material_override = cm
	add_child(crest)

	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	col_shape.shape = sphere
	col_shape.position.y = radius
	add_child(col_shape)

	_select_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.15
	torus.outer_radius = radius + 0.35
	_select_ring.mesh = torus
	_select_ring.position.y = 0.08
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.9, 0.3, 0.85)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.85, 0.2)
	rm.emission_energy_multiplier = 1.2
	_select_ring.material_override = rm
	_select_ring.visible = false
	add_child(_select_ring)

	_hp_bar = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(1.2, 0.08, 0.08)
	_hp_bar.mesh = bar
	_hp_bar.position.y = (def["scale"] as Vector3).y + 0.55
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.2, 0.85, 0.3)
	_hp_bar.material_override = bm
	add_child(_hp_bar)


func set_selected(on: bool) -> void:
	selected = on
	if _select_ring:
		_select_ring.visible = on


func issue_move(target: Vector3) -> void:
	if not _alive:
		return
	order = "move"
	move_target = target
	attack_target = null


func issue_attack(target: BattleUnit) -> void:
	if not _alive or target == null or not target.is_alive():
		return
	order = "attack"
	attack_target = target


func issue_attack_move(target: Vector3) -> void:
	if not _alive:
		return
	order = "attack_move"
	move_target = target
	attack_target = null


func issue_hold() -> void:
	order = "hold"
	attack_target = null
	velocity = Vector3.ZERO


func is_alive() -> bool:
	return _alive and hp > 0.0


func take_damage(amount: float, _from: BattleUnit = null) -> void:
	if not _alive:
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0.0:
		_die()


func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	var t: float = clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar.scale.x = maxf(t, 0.05)
	var m: StandardMaterial3D = _hp_bar.material_override as StandardMaterial3D
	if m:
		m.albedo_color = Color(0.85, 0.15, 0.1).lerp(Color(0.2, 0.85, 0.3), t)


func _die() -> void:
	_alive = false
	order = "idle"
	set_selected(false)
	died.emit(self)
	# fade collapse
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.2, 0.05, 0.2), 0.45)
	tw.parallel().tween_property(self, "global_position:y", global_position.y - 0.5, 0.45)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_bob_t += delta * (8.0 if kind == "chariot" else 5.0)

	var desired := Vector3.ZERO
	match order:
		"move", "attack_move":
			desired = _steer_to(move_target, delta)
			if global_position.distance_to(move_target) < 1.1:
				if order == "move":
					order = "idle"
					desired = Vector3.ZERO
				else:
					# attack-move: stop near point but keep looking for enemies via manager
					pass
		"attack":
			if attack_target == null or not is_instance_valid(attack_target) or not attack_target.is_alive():
				order = "idle"
				attack_target = null
			else:
				var d: float = global_position.distance_to(attack_target.global_position)
				if d > attack_range * 0.9:
					desired = _steer_to(attack_target.global_position, delta)
				else:
					desired = Vector3.ZERO
					_try_attack(attack_target)
		"hold", "idle":
			desired = Vector3.ZERO

	# gravity
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	# Soft separation from nearby units
	var sep := Vector3.ZERO
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		var n := c.get_normal()
		n.y = 0.0
		sep += n
	if sep.length() > 0.01:
		desired += sep.normalized() * move_speed * 0.35

	_vel_smooth = _vel_smooth.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
	velocity.x = _vel_smooth.x
	velocity.z = _vel_smooth.z
	move_and_slide()
	# Keep army on the plain (Megiddo is stylized flat field)
	global_position.y = 0.0
	velocity.y = 0.0

	# face movement / target
	var face := _vel_smooth
	if order == "attack" and attack_target and is_instance_valid(attack_target):
		face = attack_target.global_position - global_position
	face.y = 0.0
	if face.length() > 0.15:
		var tform := global_transform
		var look := tform.origin + face.normalized()
		look_at(look, Vector3.UP)
		# prevent mesh flip issues
		rotation.x = 0.0
		rotation.z = 0.0

	# idle bob
	if _mesh and kind != "chariot":
		_mesh.position.y = absf(sin(_bob_t)) * 0.04 + (UnitDefsScript.get_def(kind)["scale"] as Vector3).y * 0.5
	elif _mesh and kind == "chariot":
		_mesh.position.y = absf(sin(_bob_t * 1.4)) * 0.06


func _steer_to(target: Vector3, _delta: float) -> Vector3:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.2:
		return Vector3.ZERO
	var speed := move_speed
	if dist < 3.0:
		speed *= dist / 3.0
	return to.normalized() * speed


func _try_attack(target: BattleUnit) -> void:
	if _attack_timer > 0.0:
		return
	if not target.is_alive():
		return
	if global_position.distance_to(target.global_position) > attack_range + 0.35:
		return
	_attack_timer = attack_cd
	# slight lunge
	if _mesh:
		var tw := create_tween()
		tw.tween_property(_mesh, "position:z", _mesh.position.z - 0.25, 0.08)
		tw.tween_property(_mesh, "position:z", 0.0, 0.12)
	target.take_damage(damage * randf_range(0.85, 1.15), self)


func get_strength() -> float:
	return hp if _alive else 0.0
