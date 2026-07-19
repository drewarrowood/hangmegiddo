class_name BattleUnit
extends CharacterBody3D
## Detailed Egyptian/Canaanite units with limb animation, gradients, cries.

signal died(unit: BattleUnit)
signal cry(unit: BattleUnit, text: String)

var side: String = "egypt"
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
var order: String = "idle"
var move_target: Vector3 = Vector3.ZERO
var attack_target: BattleUnit = null
var _attack_timer: float = 0.0
var _anim_t: float = 0.0
var _alive: bool = true
var _spawn_pos: Vector3 = Vector3.ZERO
var _vel_smooth: Vector3 = Vector3.ZERO
var _moving: bool = false

var _visual: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _wheel_l: Node3D
var _wheel_r: Node3D
var _select_ring: MeshInstance3D
var _hp_bar: MeshInstance3D
var _cry_label: Label3D
var _cry_timer: float = 0.0
var _variant: float = 0.0

const UnitDefsScript = preload("res://scripts/unit_defs.gd")
const FactionStyleScript = preload("res://scripts/faction_style.gd")


func setup(p_side: String, p_kind: String, pos: Vector3, p_name: String = "") -> void:
	side = p_side
	kind = p_kind
	_variant = randf()
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
	_spawn_pos = pos
	_anim_t = randf() * TAU
	_build_visual()
	collision_layer = 2
	collision_mask = 1 | 2
	floor_stop_on_slope = true


func place(pos: Vector3) -> void:
	_spawn_pos = pos
	if is_inside_tree():
		global_position = pos
	else:
		position = pos


func _enter_tree() -> void:
	global_position = _spawn_pos


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scale
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _build_visual() -> void:
	var pal: Dictionary = FactionStyleScript.palette(side)
	# per-unit hue jitter
	var j := (_variant - 0.5) * 0.08
	var primary: Color = (pal["primary"] as Color).lightened(j)
	var secondary: Color = (pal["secondary"] as Color).darkened(j * 0.5)
	var accent: Color = pal["accent"]
	var skin: Color = (pal["skin"] as Color).lightened(j * 0.5)
	var linen: Color = pal["linen"]
	var wood: Color = pal["wood"]
	var horse_c: Color = pal["horse"]

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	if kind == "chariot":
		_build_chariot(primary, secondary, accent, skin, wood, horse_c)
	else:
		_build_soldier(primary, secondary, accent, skin, linen, wood, kind == "archer", kind == "hero")

	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	col_shape.shape = sphere
	col_shape.position.y = radius
	add_child(col_shape)

	_select_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.12
	torus.outer_radius = radius + 0.42
	_select_ring.mesh = torus
	_select_ring.position.y = 0.06
	var rm := FactionStyleScript.solid_mat(Color(accent.r, accent.g, accent.b, 0.9), 0.3, 0.35, 0.8)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_select_ring.material_override = rm
	_select_ring.visible = false
	add_child(_select_ring)

	_hp_bar = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(1.15, 0.07, 0.07)
	_hp_bar.mesh = bar
	_hp_bar.position.y = 2.45 if kind != "chariot" else 2.05
	_hp_bar.material_override = FactionStyleScript.gradient_mat(Color(0.7, 0.12, 0.1), Color(0.25, 0.85, 0.35))
	add_child(_hp_bar)

	_cry_label = Label3D.new()
	_cry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cry_label.font_size = 42
	_cry_label.modulate = accent
	_cry_label.outline_modulate = Color(0.05, 0.04, 0.02)
	_cry_label.outline_size = 8
	_cry_label.position = Vector3(0, 2.8 if kind != "chariot" else 2.4, 0)
	_cry_label.visible = false
	_cry_label.no_depth_test = true
	add_child(_cry_label)


func _build_soldier(primary: Color, secondary: Color, accent: Color, skin: Color, linen: Color, wood: Color, is_archer: bool, is_hero: bool) -> void:
	var skin_m := FactionStyleScript.gradient_mat(skin.darkened(0.08), skin.lightened(0.1), 0.0, 0.7)
	var cloth_m := FactionStyleScript.gradient_mat(primary, secondary, 0.05, 0.55)
	var linen_m := FactionStyleScript.gradient_mat(linen.darkened(0.05), linen, 0.0, 0.75)
	var metal_m := FactionStyleScript.gradient_mat(accent.darkened(0.15), accent.lightened(0.2), 0.75, 0.28)
	var wood_m := FactionStyleScript.solid_mat(wood, 0.0, 0.85)

	_leg_l = Node3D.new()
	_leg_r = Node3D.new()
	_arm_l = Node3D.new()
	_arm_r = Node3D.new()
	_visual.add_child(_leg_l)
	_visual.add_child(_leg_r)
	_visual.add_child(_arm_l)
	_visual.add_child(_arm_r)
	_leg_l.position = Vector3(-0.12, 0.55, 0)
	_leg_r.position = Vector3(0.12, 0.55, 0)
	_arm_l.position = Vector3(-0.36, 1.15, 0)
	_arm_r.position = Vector3(0.36, 1.15, 0)

	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.11
	leg_mesh.height = 0.58
	_part(_leg_l, leg_mesh, Vector3(0, -0.2, 0), skin_m)
	_part(_leg_r, leg_mesh, Vector3(0, -0.2, 0), skin_m)
	# sandals
	var sandal := BoxMesh.new()
	sandal.size = Vector3(0.16, 0.06, 0.28)
	_part(_leg_l, sandal, Vector3(0, -0.52, 0.04), wood_m)
	_part(_leg_r, sandal, Vector3(0, -0.52, 0.04), wood_m)

	# kilt with gradient stripes feel
	var kilt := CylinderMesh.new()
	kilt.top_radius = 0.26
	kilt.bottom_radius = 0.36
	kilt.height = 0.32
	_part(_visual, kilt, Vector3(0, 0.72, 0), linen_m if not is_hero else cloth_m)
	var sash := BoxMesh.new()
	sash.size = Vector3(0.5, 0.08, 0.12)
	_part(_visual, sash, Vector3(0, 0.88, 0.12), metal_m)

	var torso := BoxMesh.new()
	torso.size = Vector3(0.52, 0.52, 0.3)
	_part(_visual, torso, Vector3(0, 1.12, 0), cloth_m)
	# pectoral / collar
	var collar := TorusMesh.new()
	collar.inner_radius = 0.16
	collar.outer_radius = 0.24
	_part(_visual, collar, Vector3(0, 1.38, 0.02), metal_m, Vector3(90, 0, 0))

	var arm := CapsuleMesh.new()
	arm.radius = 0.085
	arm.height = 0.48
	_part(_arm_l, arm, Vector3(0, -0.18, 0), skin_m)
	_part(_arm_r, arm, Vector3(0, -0.18, 0), skin_m)

	var head := SphereMesh.new()
	head.radius = 0.17
	_part(_visual, head, Vector3(0, 1.58, 0), skin_m)
	# nemes headdress / hair
	var headdress := BoxMesh.new()
	headdress.size = Vector3(0.4, 0.18, 0.42)
	_part(_visual, headdress, Vector3(0, 1.72, -0.02), metal_m if is_hero else FactionStyleScript.gradient_mat(primary.darkened(0.1), accent, 0.2, 0.45))
	var lappet := BoxMesh.new()
	lappet.size = Vector3(0.12, 0.35, 0.08)
	_part(_visual, lappet, Vector3(-0.2, 1.55, 0.05), metal_m if is_hero else cloth_m)
	_part(_visual, lappet, Vector3(0.2, 1.55, 0.05), metal_m if is_hero else cloth_m)
	if is_hero:
		var uraeus := SphereMesh.new()
		uraeus.radius = 0.06
		_part(_visual, uraeus, Vector3(0, 1.88, 0.12), metal_m)
		var plume := BoxMesh.new()
		plume.size = Vector3(0.1, 0.4, 0.1)
		_part(_visual, plume, Vector3(0, 2.0, -0.05), FactionStyleScript.solid_mat(secondary, 0.1, 0.5, 0.2))

	if is_archer:
		var bow := TorusMesh.new()
		bow.inner_radius = 0.38
		bow.outer_radius = 0.46
		_part(_arm_r, bow, Vector3(0.1, -0.15, 0.2), wood_m, Vector3(0, 90, 20))
		var quiver := BoxMesh.new()
		quiver.size = Vector3(0.12, 0.45, 0.12)
		_part(_visual, quiver, Vector3(-0.28, 1.15, -0.2), wood_m)
	else:
		var spear := CylinderMesh.new()
		spear.top_radius = 0.03
		spear.bottom_radius = 0.03
		spear.height = 1.7
		_part(_arm_r, spear, Vector3(0.05, 0.2, 0.25), wood_m, Vector3(20, 0, 0))
		var tip := SphereMesh.new()
		tip.radius = 0.055
		_part(_arm_r, tip, Vector3(0.05, 1.05, 0.55), metal_m)
		var shield := BoxMesh.new()
		shield.size = Vector3(0.08, 0.6, 0.42)
		_part(_arm_l, shield, Vector3(-0.12, -0.1, 0.2), FactionStyleScript.gradient_mat(primary, accent, 0.35, 0.4))


func _build_chariot(primary: Color, secondary: Color, accent: Color, skin: Color, wood: Color, horse_c: Color) -> void:
	var paint := FactionStyleScript.gradient_mat(primary, secondary, 0.15, 0.5)
	var gold := FactionStyleScript.gradient_mat(accent.darkened(0.1), accent.lightened(0.25), 0.8, 0.25)
	var wood_m := FactionStyleScript.gradient_mat(wood.darkened(0.1), wood.lightened(0.15), 0.0, 0.85)
	var horse_m := FactionStyleScript.gradient_mat(horse_c.darkened(0.1), horse_c.lightened(0.12), 0.0, 0.75)
	var skin_m := FactionStyleScript.solid_mat(skin, 0.0, 0.7)

	var deck := BoxMesh.new()
	deck.size = Vector3(1.35, 0.16, 2.05)
	_part(_visual, deck, Vector3(0, 0.58, 0), paint)
	# ornate side panels
	var side_m := BoxMesh.new()
	side_m.size = Vector3(0.1, 0.58, 1.75)
	_part(_visual, side_m, Vector3(-0.58, 0.9, 0.05), paint)
	_part(_visual, side_m, Vector3(0.58, 0.9, 0.05), paint)
	var rail := BoxMesh.new()
	rail.size = Vector3(1.25, 0.08, 0.08)
	_part(_visual, rail, Vector3(0, 1.18, 0.85), gold)
	var front := BoxMesh.new()
	front.size = Vector3(1.25, 0.55, 0.12)
	_part(_visual, front, Vector3(0, 0.9, 0.9), FactionStyleScript.gradient_mat(secondary, accent, 0.25, 0.4))
	# hieroglyph-ish studs
	for x in [-0.35, 0.0, 0.35]:
		var stud := SphereMesh.new()
		stud.radius = 0.05
		_part(_visual, stud, Vector3(x, 0.95, 0.97), gold)

	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.055
	pole.height = 1.9
	_part(_visual, pole, Vector3(0, 0.58, 1.55), wood_m, Vector3(90, 0, 0))

	_wheel_l = Node3D.new()
	_wheel_r = Node3D.new()
	_wheel_l.position = Vector3(-0.78, 0.55, 0.1)
	_wheel_r.position = Vector3(0.78, 0.55, 0.1)
	_visual.add_child(_wheel_l)
	_visual.add_child(_wheel_r)
	for wnode in [_wheel_l, _wheel_r]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.58
		wheel.bottom_radius = 0.58
		wheel.height = 0.12
		_part(wnode, wheel, Vector3.ZERO, wood_m, Vector3(0, 0, 90))
		var hub := SphereMesh.new()
		hub.radius = 0.13
		_part(wnode, hub, Vector3.ZERO, gold)
		# spokes
		for i in range(6):
			var sp := BoxMesh.new()
			sp.size = Vector3(0.05, 0.95, 0.05)
			var ang := float(i) / 6.0 * TAU
			_part(wnode, sp, Vector3(0, 0, 0), wood_m, Vector3(0, 0, rad_to_deg(ang)))

	# horse
	var hbody := CapsuleMesh.new()
	hbody.radius = 0.3
	hbody.height = 1.15
	_part(_visual, hbody, Vector3(0, 0.75, 2.05), horse_m, Vector3(90, 0, 0))
	var hneck := CapsuleMesh.new()
	hneck.radius = 0.13
	hneck.height = 0.6
	_part(_visual, hneck, Vector3(0, 1.15, 2.6), horse_m, Vector3(40, 0, 0))
	var hhead := SphereMesh.new()
	hhead.radius = 0.17
	_part(_visual, hhead, Vector3(0, 1.35, 2.95), horse_m)
	var mane := BoxMesh.new()
	mane.size = Vector3(0.08, 0.35, 0.4)
	_part(_visual, mane, Vector3(0, 1.35, 2.55), FactionStyleScript.solid_mat(horse_c.darkened(0.25)))
	# legs
	for x in [-0.15, 0.15]:
		for z in [1.7, 2.35]:
			var hl := CapsuleMesh.new()
			hl.radius = 0.07
			hl.height = 0.55
			_part(_visual, hl, Vector3(x, 0.35, z), horse_m)

	# driver
	var dleg := _capsule(0.09, 0.35)
	_part(_visual, dleg, Vector3(-0.12, 1.0, -0.15), skin_m)
	_part(_visual, dleg, Vector3(0.12, 1.0, -0.15), skin_m)
	var torso := BoxMesh.new()
	torso.size = Vector3(0.42, 0.38, 0.28)
	_part(_visual, torso, Vector3(0, 1.35, -0.2), paint)
	var head := SphereMesh.new()
	head.radius = 0.13
	_part(_visual, head, Vector3(0, 1.68, -0.2), skin_m)
	var helm := BoxMesh.new()
	helm.size = Vector3(0.28, 0.12, 0.3)
	_part(_visual, helm, Vector3(0, 1.8, -0.2), gold)
	var spear := CylinderMesh.new()
	spear.top_radius = 0.03
	spear.bottom_radius = 0.03
	spear.height = 1.5
	_part(_visual, spear, Vector3(0.35, 1.55, -0.15), wood_m)


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func set_selected(on: bool) -> void:
	selected = on
	if _select_ring:
		_select_ring.visible = on


func show_cry(text: String) -> void:
	if text == "" or _cry_label == null:
		return
	_cry_label.text = text
	_cry_label.visible = true
	_cry_timer = 1.1
	cry.emit(self, text)


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


func _die() -> void:
	_alive = false
	order = "idle"
	set_selected(false)
	if Engine.has_singleton("AudioManager") or true:
		var am = _audio()
		if am:
			am.play_death()
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.25, 0.08, 0.25), 0.5)
	tw.parallel().tween_property(self, "global_position:y", global_position.y - 0.4, 0.5)
	tw.tween_callback(queue_free)


func _audio():
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("AudioManager")


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _cry_timer > 0.0:
		_cry_timer -= delta
		if _cry_timer <= 0.0 and _cry_label:
			_cry_label.visible = false

	var desired := Vector3.ZERO
	match order:
		"move", "attack_move":
			desired = _steer_to(move_target)
			if global_position.distance_to(move_target) < 1.1:
				if order == "move":
					order = "idle"
					desired = Vector3.ZERO
		"attack":
			if attack_target == null or not is_instance_valid(attack_target) or not attack_target.is_alive():
				order = "idle"
				attack_target = null
			else:
				var d: float = global_position.distance_to(attack_target.global_position)
				if d > attack_range * 0.9:
					desired = _steer_to(attack_target.global_position)
				else:
					desired = Vector3.ZERO
					_try_attack(attack_target)
		"hold", "idle":
			desired = Vector3.ZERO

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
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

	_moving = Vector2(velocity.x, velocity.z).length() > 0.4
	_anim_t += delta * (10.0 if _moving else 3.0)
	_animate_limbs(delta)

	var face := _vel_smooth
	if order == "attack" and attack_target and is_instance_valid(attack_target):
		face = attack_target.global_position - global_position
	face.y = 0.0
	if face.length() > 0.15:
		look_at(global_position + face.normalized(), Vector3.UP)
		rotation.x = 0.0
		rotation.z = 0.0


func _animate_limbs(_delta: float) -> void:
	if kind == "chariot":
		if _wheel_l:
			_wheel_l.rotate_x(_delta * (12.0 if _moving else 0.5))
		if _wheel_r:
			_wheel_r.rotate_x(_delta * (12.0 if _moving else 0.5))
		if _visual:
			_visual.position.y = absf(sin(_anim_t * 1.6)) * (0.06 if _moving else 0.02)
		return
	var swing := sin(_anim_t) * (0.7 if _moving else 0.08)
	if _leg_l:
		_leg_l.rotation.x = swing
	if _leg_r:
		_leg_r.rotation.x = -swing
	if _arm_l:
		_arm_l.rotation.x = -swing * 0.65
	if _arm_r:
		_arm_r.rotation.x = swing * 0.65
	if _visual:
		_visual.position.y = absf(sin(_anim_t * 2.0)) * (0.04 if _moving else 0.015)


func _steer_to(target: Vector3) -> Vector3:
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
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "position:z", -0.28, 0.07)
		tw.tween_property(_visual, "position:z", 0.0, 0.12)
	var am = _audio()
	if am:
		am.play_attack(kind)
		var cry_t: String = am.random_cry(side)
		if cry_t != "":
			show_cry(cry_t)
	target.take_damage(damage * randf_range(0.85, 1.15), self)


func get_strength() -> float:
	return hp if _alive else 0.0
