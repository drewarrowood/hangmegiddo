class_name UnitDefs
extends RefCounted
## Egyptian / Canaanite unit templates for Megiddo.

const KINDS := {
	"spearman": {
		"label": "Spearmen",
		"hp": 100.0,
		"damage": 12.0,
		"range": 2.2,
		"attack_cd": 0.85,
		"speed": 6.5,
		"radius": 0.55,
		"mass": 1.0,
		# faction colors applied via FactionStyle gradients
		"color_egypt": Color(0.12, 0.32, 0.58),
		"color_canaan": Color(0.58, 0.16, 0.2),
		"scale": Vector3(0.9, 1.4, 0.9),
	},
	"archer": {
		"label": "Archers",
		"hp": 70.0,
		"damage": 9.0,
		"range": 14.0,
		"attack_cd": 1.1,
		"speed": 6.0,
		"radius": 0.5,
		"mass": 0.8,
		"color_egypt": Color(0.15, 0.48, 0.52),
		"color_canaan": Color(0.52, 0.28, 0.4),
		"scale": Vector3(0.8, 1.35, 0.8),
	},
	"chariot": {
		"label": "Chariots",
		"hp": 160.0,
		"damage": 22.0,
		"range": 2.8,
		"attack_cd": 0.7,
		"speed": 12.5,
		"radius": 1.1,
		"mass": 2.2,
		"color_egypt": Color(0.9, 0.72, 0.2),
		"color_canaan": Color(0.72, 0.35, 0.18),
		"scale": Vector3(1.6, 0.9, 2.2),
	},
	"hero": {
		"label": "Royal command",
		"hp": 280.0,
		"damage": 28.0,
		"range": 2.5,
		"attack_cd": 0.65,
		"speed": 8.5,
		"radius": 0.7,
		"mass": 1.4,
		"color_egypt": Color(0.95, 0.82, 0.28),
		"color_canaan": Color(0.8, 0.18, 0.35),
		"scale": Vector3(1.1, 1.7, 1.1),
	},
}


static func get_def(kind: String) -> Dictionary:
	if KINDS.has(kind):
		return KINDS[kind]
	return KINDS["spearman"]
