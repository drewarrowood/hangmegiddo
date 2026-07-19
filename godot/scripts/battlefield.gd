class_name Battlefield
extends Node3D
## Historical Megiddo layout: Aruna gorge (S) → chariot plain → steep Levantine tell (N).

var map_size: float = 200.0
var megiddo_pos: Vector3 = Vector3(0, 0, -58)
var gate_pos: Vector3 = Vector3(0, 0, -42)
var pass_mouth: Vector3 = Vector3(0, 0, 32)
var plain_z_min: float = -38.0
var plain_z_max: float = 28.0
var plain_x_half: float = 48.0

var sun: DirectionalLight3D = null


func build(scenario: Dictionary = {}) -> void:
	var map: Dictionary = scenario.get("map", {})
	map_size = float(map.get("size", 200))
	megiddo_pos = _v3(map.get("megiddo_pos", [0, 0, -58]))
	gate_pos = _v3(map.get("gate_pos", [0, 0, -42]))
	pass_mouth = _v3(map.get("pass_mouth", [0, 0, 32]))
	plain_z_min = float(map.get("plain_z_min", -38))
	plain_z_max = float(map.get("plain_z_max", 28))
	plain_x_half = float(map.get("plain_x_half", 48))
	_clear_children()
	_build_sky()
	_build_sun()
	_build_ground()
	_build_aruna_gorge()
	_build_side_approaches()
	_build_megiddo_tell()
	_build_egyptian_camp_markers()
	_build_scrub()
	_build_labels()


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()


func is_chariot_ground(pos: Vector3) -> bool:
	## Chariots fight on the open plain, not in the gorge or up the tell.
	if pos.z < plain_z_min + 2.0:
		return false
	if pos.z > plain_z_max + 4.0:
		return false
	if absf(pos.x) > plain_x_half + 6.0:
		return false
	# keep off steep mound
	if pos.distance_to(megiddo_pos) < 16.0:
		return false
	return true


func clamp_move_for_kind(kind: String, pos: Vector3) -> Vector3:
	var p := pos
	p.y = 0.0
	if kind == "chariot":
		p.x = clampf(p.x, -plain_x_half, plain_x_half)
		p.z = clampf(p.z, plain_z_min + 1.0, plain_z_max + 2.0)
		# push off tell
		var d: float = p.distance_to(Vector3(megiddo_pos.x, 0, megiddo_pos.z))
		if d < 18.0:
			var away: Vector3 = (p - Vector3(megiddo_pos.x, 0, megiddo_pos.z)).normalized()
			if away.length() < 0.1:
				away = Vector3(0, 0, 1)
			p = Vector3(megiddo_pos.x, 0, megiddo_pos.z) + away * 18.0
			p.z = maxf(p.z, plain_z_min + 1.0)
	else:
		p.x = clampf(p.x, -70.0, 70.0)
		p.z = clampf(p.z, -72.0, 85.0)
	return p


func _mat_grad(c0: Color, c1: Color, rough: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var g := Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	var m := StandardMaterial3D.new()
	m.albedo_texture = gt
	m.roughness = rough
	m.metallic = metallic
	return m


func _build_sky() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.58, 0.76, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.93, 0.78)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_bloom = 0.18
	e.fog_enabled = true
	e.fog_light_color = Color(0.92, 0.86, 0.7)
	e.fog_density = 0.0014
	e.fog_aerial_perspective = 0.7
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.1
	env.environment = e
	add_child(env)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.85)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-52, 40, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.62, 0.88)
	fill.light_energy = 0.28
	fill.rotation_degrees = Vector3(-18, -130, 0)
	add_child(fill)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_size, map_size)
	mesh.mesh = plane
	# Levant dry plain: pale ochre + olive tint, not pure Sahara
	mesh.material_override = _mat_grad(Color(0.78, 0.68, 0.48), Color(0.62, 0.55, 0.38), 0.94)
	ground.add_child(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(map_size, 0.6, map_size)
	col.shape = box
	col.position.y = -0.3
	ground.add_child(col)
	add_child(ground)

	# greener plain band (fields)
	var fields := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(plain_x_half * 2.0, plain_z_max - plain_z_min)
	fields.mesh = fp
	fields.position = Vector3(0, 0.03, (plain_z_min + plain_z_max) * 0.5)
	var fm := _mat_grad(Color(0.55, 0.58, 0.32, 0.55), Color(0.7, 0.62, 0.4, 0.4), 1.0)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fields.material_override = fm
	add_child(fields)


func _hill(pos: Vector3, scale: Vector3, col0: Color, col1: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	mi.mesh = sph
	mi.scale = scale
	mi.position = pos + Vector3(0, scale.y * 0.2, 0)
	mi.material_override = _mat_grad(col0, col1, 0.95)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	col.shape = sh
	col.scale = scale
	col.position = mi.position
	body.add_child(col)
	add_child(body)


func _build_aruna_gorge() -> void:
	## Narrow corridor from south (deep pass) to pass mouth on the plain.
	var rock0 := Color(0.55, 0.48, 0.38)
	var rock1 := Color(0.38, 0.32, 0.26)
	# Walls left/right of gorge
	for z in range(35, 85, 8):
		var zz := float(z)
		_hill(Vector3(-14, 0, zz), Vector3(10, 9, 7), rock0, rock1)
		_hill(Vector3(14, 0, zz), Vector3(10, 9, 7), rock0, rock1)
		_hill(Vector3(-20, 0, zz + 3), Vector3(8, 7, 6), rock1, rock0)
		_hill(Vector3(20, 0, zz + 3), Vector3(8, 7, 6), rock1, rock0)
	# Mouth flaring open onto plain
	_hill(Vector3(-22, 0, 28), Vector3(12, 8, 8), rock0, rock1)
	_hill(Vector3(22, 0, 28), Vector3(12, 8, 8), rock0, rock1)
	_hill(Vector3(-28, 0, 22), Vector3(10, 6, 7), rock0, Color(0.5, 0.45, 0.35))
	_hill(Vector3(28, 0, 22), Vector3(10, 6, 7), rock0, Color(0.5, 0.45, 0.35))

	# Gorge floor (darker packed earth)
	var road := MeshInstance3D.new()
	var rp := PlaneMesh.new()
	rp.size = Vector2(7.5, 58)
	road.mesh = rp
	road.position = Vector3(0, 0.05, 52)
	road.material_override = _mat_grad(Color(0.42, 0.34, 0.24), Color(0.55, 0.45, 0.32), 1.0)
	add_child(road)
	# fan onto plain
	var fan := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(22, 18)
	fan.mesh = fp
	fan.position = Vector3(0, 0.04, 30)
	fan.material_override = _mat_grad(Color(0.5, 0.4, 0.28), Color(0.68, 0.58, 0.4), 1.0)
	add_child(fan)


func _build_side_approaches() -> void:
	## Hint of the "easy" roads Canaan expected (east/west), not the play corridor.
	var dust := _mat_grad(Color(0.6, 0.5, 0.36, 0.5), Color(0.7, 0.6, 0.42, 0.35), 1.0)
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x_sign in [-1.0, 1.0]:
		var path := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(5, 70)
		path.mesh = p
		path.position = Vector3(x_sign * 55, 0.04, 5)
		path.rotation_degrees = Vector3(0, x_sign * 18, 0)
		path.material_override = dust
		add_child(path)
	# framing hills for plain
	_hill(Vector3(-55, 0, -10), Vector3(14, 7, 20), Color(0.5, 0.45, 0.35), Color(0.4, 0.36, 0.28))
	_hill(Vector3(55, 0, -8), Vector3(14, 7, 20), Color(0.5, 0.45, 0.35), Color(0.4, 0.36, 0.28))
	_hill(Vector3(-48, 0, -40), Vector3(12, 8, 12), Color(0.48, 0.42, 0.34), Color(0.38, 0.33, 0.28))
	_hill(Vector3(48, 0, -42), Vector3(12, 8, 12), Color(0.48, 0.42, 0.34), Color(0.38, 0.33, 0.28))


func _build_megiddo_tell() -> void:
	var root := Node3D.new()
	root.name = "MegiddoTell"
	root.position = megiddo_pos
	add_child(root)

	# Steep artificial mound (tell) — mudbrick/ochre, not Egyptian gold
	var mound := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 13.0
	cyl.bottom_radius = 20.0
	cyl.height = 7.5
	mound.mesh = cyl
	mound.position.y = 3.6
	mound.material_override = _mat_grad(Color(0.62, 0.5, 0.38), Color(0.48, 0.38, 0.28), 0.95)
	root.add_child(mound)

	# stone socle ring
	var socle := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 20.5
	sc.bottom_radius = 21.5
	sc.height = 1.2
	socle.mesh = sc
	socle.position.y = 0.5
	socle.material_override = _mat_grad(Color(0.55, 0.52, 0.48), Color(0.4, 0.38, 0.35), 0.9)
	root.add_child(socle)

	# mudbrick curtain wall on summit
	var brick := _mat_grad(Color(0.72, 0.55, 0.4), Color(0.55, 0.4, 0.3), 0.88)
	for i in range(12):
		var ang := float(i) / 12.0 * TAU + 0.2
		# leave gap for south gate
		if ang > TAU * 0.72 and ang < TAU * 0.88:
			continue
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(6.2, 3.4, 1.5)
		wall.mesh = box
		wall.position = Vector3(cos(ang) * 12.2, 8.2, sin(ang) * 12.2)
		wall.rotation.y = -ang
		wall.material_override = brick
		root.add_child(wall)

	# Levantine gate complex facing south (toward plain) — not Egyptian pylons
	var gate_root := Node3D.new()
	gate_root.position = Vector3(0, 0, 13.5)
	root.add_child(gate_root)
	var tower_m := _mat_grad(Color(0.58, 0.48, 0.38), Color(0.42, 0.34, 0.28), 0.9)
	for x in [-5.5, 5.5]:
		var tower := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(3.2, 6.5, 3.2)
		tower.mesh = tb
		tower.position = Vector3(x, 7.5, 0)
		tower.material_override = tower_m
		gate_root.add_child(tower)
	var gatehouse := MeshInstance3D.new()
	var gh := BoxMesh.new()
	gh.size = Vector3(8.0, 4.5, 4.0)
	gatehouse.mesh = gh
	gatehouse.position = Vector3(0, 7.0, -1.5)
	gatehouse.material_override = brick
	gate_root.add_child(gatehouse)
	# dark gate opening
	var opening := MeshInstance3D.new()
	var ob := BoxMesh.new()
	ob.size = Vector3(3.2, 3.2, 1.2)
	opening.mesh = ob
	opening.position = Vector3(0, 6.2, 1.2)
	opening.material_override = _mat_grad(Color(0.12, 0.1, 0.08), Color(0.25, 0.18, 0.12), 1.0)
	gate_root.add_child(opening)

	# ramp from plain to gate
	var ramp := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(6.0, 0.8, 14.0)
	ramp.mesh = rb
	ramp.position = Vector3(0, 1.2, 20)
	ramp.rotation_degrees = Vector3(-18, 0, 0)
	ramp.material_override = _mat_grad(Color(0.55, 0.48, 0.38), Color(0.45, 0.38, 0.3), 0.95)
	root.add_child(ramp)

	# objective disc at gate approach (plain side)
	var disc := MeshInstance3D.new()
	var dmesh := CylinderMesh.new()
	dmesh.top_radius = 10.0
	dmesh.bottom_radius = 10.0
	dmesh.height = 0.12
	disc.mesh = dmesh
	disc.position = Vector3(0, 0.1, 24)
	var dm := _mat_grad(Color(0.85, 0.25, 0.15, 0.3), Color(0.9, 0.5, 0.15, 0.15), 1.0)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.emission_enabled = true
	dm.emission = Color(0.9, 0.35, 0.12)
	dm.emission_energy_multiplier = 0.35
	disc.material_override = dm
	root.add_child(disc)

	# collision for mound
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 18.0
	sh.height = 7.0
	col.shape = sh
	col.position.y = 3.5
	body.add_child(col)
	root.add_child(body)

	# roof blocks suggesting dense city
	var roof_m := _mat_grad(Color(0.65, 0.5, 0.38), Color(0.5, 0.38, 0.28), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1457
	for i in range(14):
		var roof := MeshInstance3D.new()
		var box2 := BoxMesh.new()
		box2.size = Vector3(rng.randf_range(1.5, 2.8), 0.5, rng.randf_range(1.5, 2.8))
		roof.mesh = box2
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.0, 9.0)
		roof.position = Vector3(cos(a) * r, 9.2, sin(a) * r)
		roof.material_override = roof_m
		root.add_child(roof)


func _build_egyptian_camp_markers() -> void:
	## Egyptian look stays at the pass mouth camp — not on Megiddo walls.
	var gold := _mat_grad(Color(0.85, 0.68, 0.2), Color(0.95, 0.85, 0.4), 0.35, 0.55)
	var blue := _mat_grad(Color(0.12, 0.28, 0.52), Color(0.2, 0.5, 0.55), 0.2, 0.5)
	var base_z := 38.0
	for x in [-10.0, 10.0]:
		var pole := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.12
		c.bottom_radius = 0.15
		c.height = 5.5
		pole.mesh = c
		pole.position = Vector3(x, 2.7, base_z)
		pole.material_override = gold
		add_child(pole)
		var banner := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.08, 1.4, 1.1)
		banner.mesh = b
		banner.position = Vector3(x + 0.4, 4.2, base_z)
		banner.material_override = blue
		add_child(banner)
	# royal tent suggestion
	var tent := MeshInstance3D.new()
	var tp := PrismMesh.new()
	tp.size = Vector3(6, 3.2, 5)
	tent.mesh = tp
	tent.position = Vector3(-16, 1.6, 42)
	tent.material_override = _mat_grad(Color(0.9, 0.88, 0.78), Color(0.75, 0.7, 0.55), 0.8)
	add_child(tent)
	# camp fire glow
	var fire := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.45
	fire.mesh = fs
	fire.position = Vector3(-14, 0.5, 40)
	var fm := _mat_grad(Color(1.0, 0.45, 0.1), Color(1.0, 0.8, 0.2), 0.4, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.5, 0.1)
	fm.emission_energy_multiplier = 1.2
	fire.material_override = fm
	add_child(fire)


func _build_scrub() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1458
	for i in range(28):
		var x := rng.randf_range(-65, 65)
		var z := rng.randf_range(-50, 70)
		# keep pass corridor and plain center clearer
		if absf(x) < 9.0 and z > 25.0:
			continue
		if absf(x) < 12.0 and z > -35.0 and z < 25.0 and rng.randf() < 0.6:
			continue
		var bush := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.6, 1.3)
		bush.mesh = s
		bush.position = Vector3(x, s.radius * 0.45, z)
		bush.material_override = _mat_grad(Color(0.28, 0.4, 0.22), Color(0.4, 0.38, 0.2), 1.0)
		add_child(bush)


func _build_labels() -> void:
	_label3d("MEGIDDO", megiddo_pos + Vector3(0, 14, 0), Color(0.85, 0.7, 0.45))
	_label3d("ARUNA PASS", Vector3(0, 6, 58), Color(0.75, 0.8, 0.9))
	_label3d("PLAIN OF BATTLE", Vector3(0, 2.5, -5), Color(0.7, 0.75, 0.55))
	_label3d("EGYPTIAN CAMP", Vector3(-16, 4.5, 42), Color(0.9, 0.8, 0.4))


func _label3d(text: String, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 48
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0.05, 0.04, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)


func sample_height(_x: float, _z: float) -> float:
	return 0.0
