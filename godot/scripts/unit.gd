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


func _mat(col: Color, metallic: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = rough
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_visual(def: Dictionary) -> void:
	var col: Color = def["color_egypt"] if side == "egypt" else def["color_canaan"]
	var skin := Color(0.78, 0.58, 0.42) if side == "egypt" else Color(0.72, 0.52, 0.38)
	var linen := col.lightened(0.15)
	var metal := Color(0.9, 0.75, 0.25) if side == "egypt" else Color(0.65, 0.45, 0.28)
	_body_mat = _mat(col)

	var root := Node3D.new()
	root.name = "Visual"
	_mesh = MeshInstance3D.new() # anchor for bob / lunge (empty)
	_mesh.mesh = BoxMesh.new()
	(_mesh.mesh as BoxMesh).size = Vector3(0.01, 0.01, 0.01)
	_mesh.visible = false
	add_child(root)
	add_child(_mesh)

	if kind == "chariot":
		_build_chariot(root, col, skin, metal)
	elif kind == "archer":
		_build_soldier(root, skin, linen, metal, true)
	elif kind == "hero":
		_build_soldier(root, skin, linen.lightened(0.1), metal, false, true)
	else:
		_build_soldier(root, skin, linen, metal, false, false)

	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	col_shape.shape = sphere
	col_shape.position.y = radius
	add_child(col_shape)

	_select_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.15
	torus.outer_radius = radius + 0.4
	_select_ring.mesh = torus
	_select_ring.position.y = 0.08
	var rm := _mat(Color(1.0, 0.9, 0.3, 0.85), 0.0, 0.4)
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
	_hp_bar.position.y = 2.35 if kind != "chariot" else 1.9
	_hp_bar.material_override = _mat(Color(0.2, 0.85, 0.3))
	add_child(_hp_bar)


func _build_soldier(root: Node3D, skin: Color, cloth: Color, metal: Color, is_archer: bool, is_hero: bool = false) -> void:
	var sm := _mat(skin)
	var cm := _mat(cloth)
	var mm := _mat(metal, 0.7, 0.35)
	# legs
	var leg := CapsuleMesh.new()
	leg.radius = 0.12
	leg.height = 0.55
	_part(root, leg, Vector3(-0.12, 0.4, 0), sm)
	_part(root, leg, Vector3(0.12, 0.4, 0), sm)
	# kilt / torso
	var torso := BoxMesh.new()
	torso.size = Vector3(0.55, 0.55, 0.32)
	_part(root, torso, Vector3(0, 0.95, 0), cm)
	var kilt := CylinderMesh.new()
	kilt.top_radius = 0.28
	kilt.bottom_radius = 0.34
	kilt.height = 0.28
	_part(root, kilt, Vector3(0, 0.62, 0), cm)
	# arms
	var arm := CapsuleMesh.new()
	arm.radius = 0.09
	arm.height = 0.45
	_part(root, arm, Vector3(-0.38, 0.95, 0), sm, Vector3(0, 0, 12))
	_part(root, arm, Vector3(0.38, 0.95, 0), sm, Vector3(0, 0, -12))
	# head
	var head := SphereMesh.new()
	head.radius = 0.18
	_part(root, head, Vector3(0, 1.45, 0), sm)
	# nemes / hair
	var helm := BoxMesh.new()
	helm.size = Vector3(0.38, 0.16, 0.4)
	_part(root, helm, Vector3(0, 1.58, -0.02), mm if is_hero else _mat(cloth.darkened(0.15)))
	if is_hero:
		var crest := BoxMesh.new()
		crest.size = Vector3(0.12, 0.35, 0.12)
		_part(root, crest, Vector3(0, 1.85, 0), mm)
	# weapon
	if is_archer:
		var bow := TorusMesh.new()
		bow.inner_radius = 0.35
		bow.outer_radius = 0.42
		_part(root, bow, Vector3(0.45, 1.05, 0.1), _mat(Color(0.35, 0.22, 0.12)), Vector3(0, 90, 0))
	else:
		var spear := CylinderMesh.new()
		spear.top_radius = 0.035
		spear.bottom_radius = 0.035
		spear.height = 1.6
		_part(root, spear, Vector3(0.42, 1.15, 0.15), _mat(Color(0.4, 0.28, 0.15)), Vector3(15, 0, 0))
		var tip := SphereMesh.new()
		tip.radius = 0.06
		_part(root, tip, Vector3(0.42, 1.95, 0.35), mm)
	# shield (spearman)
	if not is_archer:
		var shield := BoxMesh.new()
		shield.size = Vector3(0.08, 0.55, 0.4)
		_part(root, shield, Vector3(-0.45, 1.0, 0.15), mm)


func _build_chariot(root: Node3D, faction: Color, skin: Color, metal: Color) -> void:
	var wood := _mat(Color(0.4, 0.25, 0.12), 0.05, 0.85)
	var paint := _mat(faction.lightened(0.1), 0.1, 0.55)
	var mm := _mat(metal, 0.75, 0.3)
	var sm := _mat(skin)
	# platform
	var deck := BoxMesh.new()
	deck.size = Vector3(1.3, 0.18, 2.0)
	_part(root, deck, Vector3(0, 0.55, 0), paint)
	# sides
	var side_m := BoxMesh.new()
	side_m.size = Vector3(0.1, 0.55, 1.7)
	_part(root, side_m, Vector3(-0.55, 0.85, 0.05), paint)
	_part(root, side_m, Vector3(0.55, 0.85, 0.05), paint)
	var front := BoxMesh.new()
	front.size = Vector3(1.2, 0.5, 0.12)
	_part(root, front, Vector3(0, 0.85, 0.85), paint)
	# pole
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.06
	pole.height = 1.8
	_part(root, pole, Vector3(0, 0.55, 1.5), wood, Vector3(90, 0, 0))
	# wheels
	for x in [-0.75, 0.75]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.55
		wheel.bottom_radius = 0.55
		wheel.height = 0.12
		_part(root, wheel, Vector3(x, 0.55, 0.15), wood, Vector3(0, 0, 90))
		var hub := SphereMesh.new()
		hub.radius = 0.12
		_part(root, hub, Vector3(x, 0.55, 0.15), mm)
	# horse (simplified body + head)
	var hbody := CapsuleMesh.new()
	hbody.radius = 0.28
	hbody.height = 1.1
	_part(root, hbody, Vector3(0, 0.7, 2.0), _mat(Color(0.35, 0.22, 0.12)), Vector3(90, 0, 0))
	var hneck := CapsuleMesh.new()
	hneck.radius = 0.12
	hneck.height = 0.55
	_part(root, hneck, Vector3(0, 1.05, 2.55), _mat(Color(0.35, 0.22, 0.12)), Vector3(35, 0, 0))
	var hhead := SphereMesh.new()
	hhead.radius = 0.16
	_part(root, hhead, Vector3(0, 1.25, 2.85), _mat(Color(0.35, 0.22, 0.12)))
	# driver
	var legs := CapsuleMesh.new()
	legs.radius = 0.1
	legs.height = 0.4
	_part(root, legs, Vector3(-0.12, 0.95, -0.1), sm)
	_part(root, legs, Vector3(0.12, 0.95, -0.1), sm)
	var torso := BoxMesh.new()
	torso.size = Vector3(0.45, 0.4, 0.28)
	_part(root, torso, Vector3(0, 1.25, -0.15), paint)
	var head := SphereMesh.new()
	head.radius = 0.14
	_part(root, head, Vector3(0, 1.6, -0.15), sm)
	# spear upright
	var spear := CylinderMesh.new()
	spear.top_radius = 0.03
	spear.bottom_radius = 0.03
	spear.height = 1.4
	_part(root, spear, Vector3(0.35, 1.5, -0.2), wood)


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

	# idle bob on visual root
	var vis := get_node_or_null("Visual") as Node3D
	if vis:
		vis.position.y = absf(sin(_bob_t * (1.5 if kind == "chariot" else 1.0))) * (0.05 if kind == "chariot" else 0.03)


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
	var vis := get_node_or_null("Visual") as Node3D
	if vis:
		var tw := create_tween()
		tw.tween_property(vis, "position:z", -0.22, 0.08)
		tw.tween_property(vis, "position:z", 0.0, 0.12)
	target.take_damage(damage * randf_range(0.85, 1.15), self)


func get_strength() -> float:
	return hp if _alive else 0.0
