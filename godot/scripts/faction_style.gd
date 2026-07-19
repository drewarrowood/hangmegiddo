class_name FactionStyle
extends RefCounted
## Side palettes: Egypt = lapis/gold/turquoise; Canaan = crimson/bronze/purple.

const EGYPT := {
	"primary": Color(0.12, 0.28, 0.55),
	"secondary": Color(0.18, 0.55, 0.58),
	"accent": Color(0.92, 0.75, 0.22),
	"linen": Color(0.93, 0.9, 0.82),
	"skin": Color(0.82, 0.62, 0.45),
	"leather": Color(0.45, 0.32, 0.18),
	"wood": Color(0.42, 0.28, 0.14),
	"horse": Color(0.38, 0.26, 0.14),
	"ui": Color(0.95, 0.88, 0.55),
	"glow": Color(0.35, 0.65, 0.95),
}

const CANAAN := {
	"primary": Color(0.58, 0.14, 0.18),
	"secondary": Color(0.48, 0.22, 0.42),
	"accent": Color(0.78, 0.52, 0.22),
	"linen": Color(0.72, 0.55, 0.42),
	"skin": Color(0.74, 0.54, 0.4),
	"leather": Color(0.35, 0.22, 0.12),
	"wood": Color(0.38, 0.24, 0.12),
	"horse": Color(0.28, 0.18, 0.12),
	"ui": Color(0.95, 0.55, 0.45),
	"glow": Color(0.9, 0.3, 0.35),
}


static func palette(side: String) -> Dictionary:
	return EGYPT if side == "egypt" else CANAAN


static func gradient_mat(c0: Color, c1: Color, metallic: float = 0.05, rough: float = 0.55) -> StandardMaterial3D:
	var g := Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.fill = GradientTexture2D.FILL_LINEAR
	var m := StandardMaterial3D.new()
	m.albedo_texture = gt
	m.metallic = metallic
	m.roughness = rough
	return m


static func solid_mat(c: Color, metallic: float = 0.0, rough: float = 0.6, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m
