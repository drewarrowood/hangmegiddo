class_name Battlefield
extends Node3D
## Stylized Megiddo plain + fortress hill + Egyptian lighting.

var map_size: float = 180.0
var megiddo_pos: Vector3 = Vector3(0, 0, -55)

@onready var sun: DirectionalLight3D = null


func build(scenario: Dictionary = {}) -> void:
	var map: Dictionary = scenario.get("map", {})
	map_size = float(map.get("size", 180))
	var mp: Array = map.get("megiddo_pos", [0, 0, -55])
	megiddo_pos = Vector3(float(mp[0]), float(mp[1]), float(mp[2]))
	_clear_children()
	_build_sky()
	_build_sun()
	_build_ground()
	_build_hills()
	_build_megiddo()
	_build_props()
	_build_pass_road()


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()


func _build_sky() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	# warm Nile-valley dusk-gold sky
	e.background_color = Color(0.62, 0.78, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.92, 0.75)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_bloom = 0.22
	e.fog_enabled = true
	e.fog_light_color = Color(0.95, 0.85, 0.65)
	e.fog_density = 0.0015
	e.fog_aerial_perspective = 0.65
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.05
	env.environment = e
	add_child(env)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48, 35, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-20, -120, 0)
	add_child(fill)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_size, map_size)
	mesh.mesh = plane
	var g := Gradient.new()
	g.colors = PackedColorArray([
		Color(0.86, 0.72, 0.48),
		Color(0.72, 0.58, 0.36),
		Color(0.8, 0.68, 0.45),
	])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = gt
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 0.92
	mat.uv1_scale = Vector3(8, 8, 8)
	mesh.material_override = mat
	ground.add_child(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(map_size, 0.5, map_size)
	col.shape = box
	col.position.y = -0.25
	ground.add_child(col)
	add_child(ground)

	# checker-ish sand bands for scale
	for i in range(-4, 5):
		var strip := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(map_size * 0.9, 6.0)
		strip.mesh = p
		strip.position = Vector3(0, 0.02, float(i) * 16.0)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.82, 0.7, 0.48, 0.35)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		strip.material_override = sm
		add_child(strip)


func _build_hills() -> void:
	# ridge north of Megiddo + side slopes framing the plain
	var hills := [
		[Vector3(-40, 0, -65), Vector3(28, 10, 22)],
		[Vector3(35, 0, -62), Vector3(24, 9, 20)],
		[Vector3(0, 0, -72), Vector3(40, 12, 18)],
		[Vector3(-55, 0, 10), Vector3(18, 6, 30)],
		[Vector3(58, 0, 5), Vector3(16, 5, 28)],
		[Vector3(-25, 0, 55), Vector3(14, 4, 12)], # near Aruna approach
	]
	for h in hills:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var sc: Vector3 = h[1]
		sphere.radius = 1.0
		sphere.height = 2.0
		mi.mesh = sphere
		mi.scale = sc
		mi.position = h[0] + Vector3(0, sc.y * 0.15, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.5, 0.32)
		mat.roughness = 0.95
		mi.material_override = mat
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.0
		col.shape = sh
		col.scale = sc
		col.position = mi.position
		body.add_child(col)
		add_child(body)


func _build_megiddo() -> void:
	var root := Node3D.new()
	root.name = "MegiddoFortress"
	root.position = megiddo_pos
	add_child(root)

	# mound
	var mound := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 14.0
	cyl.bottom_radius = 18.0
	cyl.height = 4.0
	mound.mesh = cyl
	mound.position.y = 2.0
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.7, 0.58, 0.4)
	mound.material_override = mm
	root.add_child(mound)

	# walls
	var wall_g := Gradient.new()
	wall_g.colors = PackedColorArray([Color(0.92, 0.84, 0.65), Color(0.72, 0.58, 0.4)])
	var wall_gt := GradientTexture2D.new()
	wall_gt.gradient = wall_g
	wall_gt.fill_from = Vector2(0.5, 0)
	wall_gt.fill_to = Vector2(0.5, 1)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = wall_gt
	wall_mat.roughness = 0.7
	for i in range(8):
		var ang := float(i) / 8.0 * TAU
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(7.5, 3.2, 1.4)
		wall.mesh = box
		wall.position = Vector3(cos(ang) * 12.0, 4.5, sin(ang) * 12.0)
		wall.rotation.y = -ang
		wall.material_override = wall_mat
		root.add_child(wall)

	# gate facing south (toward plain)
	var gate := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(5.0, 4.0, 2.0)
	gate.mesh = gbox
	gate.position = Vector3(0, 5.0, 13.5)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.35, 0.2)
	gate.material_override = gm
	root.add_child(gate)

	# Egyptian-style pylons at gate (captured aesthetic — enemy held, still monumental)
	for x in [-4.0, 4.0]:
		var pylon := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(2.2, 6.5, 2.2)
		pylon.mesh = pb
		pylon.position = Vector3(x, 6.2, 14.0)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.9, 0.82, 0.55)
		pm.metallic = 0.1
		pylon.material_override = pm
		root.add_child(pylon)

	# objective marker disc
	var disc := MeshInstance3D.new()
	var dmesh := CylinderMesh.new()
	dmesh.top_radius = 16.0
	dmesh.bottom_radius = 16.0
	dmesh.height = 0.15
	disc.mesh = dmesh
	disc.position = Vector3(0, 0.12, 0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.9, 0.2, 0.15, 0.25)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.emission_enabled = true
	dm.emission = Color(0.9, 0.3, 0.1)
	dm.emission_energy_multiplier = 0.4
	disc.material_override = dm
	root.add_child(disc)

	# static collision for mound top
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 16.0
	sh.height = 4.0
	col.shape = sh
	col.position.y = 2.0
	body.add_child(col)
	root.add_child(body)


func _build_props() -> void:
	# palms / obelisk-like markers (stylized)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1457
	for i in range(18):
		var p := MeshInstance3D.new()
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.2
		trunk.bottom_radius = 0.28
		trunk.height = 3.5
		p.mesh = trunk
		p.position = Vector3(rng.randf_range(-70, 70), 1.75, rng.randf_range(-40, 70))
		# keep clear of center battlefield a bit
		if absf(p.position.x) < 12.0 and absf(p.position.z) < 20.0:
			p.position.x += 20.0 * signf(p.position.x + 0.1)
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.4, 0.28, 0.15)
		p.material_override = tm
		add_child(p)
		var fr := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 1.1
		fr.mesh = s
		fr.position = p.position + Vector3(0, 2.4, 0)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.2, 0.45, 0.22)
		fr.material_override = fm
		add_child(fr)

	# gold-blue banner poles at Egyptian entry
	for x in [-12.0, 12.0]:
		var pole := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.12
		c.bottom_radius = 0.15
		c.height = 5.0
		pole.mesh = c
		pole.position = Vector3(x, 2.5, 62)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.85, 0.7, 0.2)
		pm.metallic = 0.7
		pole.material_override = pm
		add_child(pole)


func _build_pass_road() -> void:
	# Aruna approach scar from south
	var road := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(8.0, 55.0)
	road.mesh = p
	road.position = Vector3(0, 0.04, 40)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.55, 0.42, 0.28)
	rm.roughness = 1.0
	road.material_override = rm
	add_child(road)


func sample_height(_x: float, _z: float) -> float:
	return 0.0
