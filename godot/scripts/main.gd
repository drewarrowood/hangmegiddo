extends Node3D
## Battle of Megiddo — 3D touch RTS entry.

const BattlefieldScript = preload("res://scripts/battlefield.gd")
const CameraRigScript = preload("res://scripts/camera_rig.gd")
const GameWorldScript = preload("res://scripts/game_world.gd")
const HUDScript = preload("res://scripts/hud.gd")

var battlefield: Battlefield
var camera_rig: CameraRig
var world: GameWorld
var hud: MegiddoHUD
var scenario: Dictionary = {}
var _attack_move_mode: bool = false
var _started: bool = false


func _ready() -> void:
	_load_scenario()
	battlefield = BattlefieldScript.new()
	battlefield.name = "Battlefield"
	add_child(battlefield)
	battlefield.build(scenario)

	world = GameWorldScript.new()
	world.name = "GameWorld"
	add_child(world)
	world.setup(scenario)
	world.paused = true

	camera_rig = CameraRigScript.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	var spawn: Array = scenario.get("map", {}).get("egypt_spawn", [0, 0, 50])
	camera_rig.focus_on(Vector3(float(spawn[0]), 0, float(spawn[2])))
	camera_rig.ground_clicked.connect(_on_ground_clicked)
	camera_rig.unit_clicked.connect(_on_unit_clicked)

	hud = HUDScript.new()
	add_child(hud)
	hud.start_pressed.connect(_on_start)
	hud.cmd_attack_move.connect(func(): _attack_move_mode = true; hud.push_log("Attack-move: tap ground to advance."))
	hud.cmd_hold.connect(func(): world.order_hold())
	hud.cmd_stop.connect(func(): world.order_stop())
	hud.cmd_select_all.connect(func(): world.select_all_player())
	hud.cmd_pause.connect(_toggle_pause)
	world.selection_changed.connect(hud.set_selection)
	world.strength_changed.connect(_on_strength)
	world.unit_count_changed.connect(_on_counts)
	world.battle_log.connect(hud.push_log)
	world.victory.connect(_on_victory)

	# initial strength UI
	_egypt_n = world.count_side("egypt")
	_canaan_n = world.count_side("canaan")
	hud.set_strength(world.total_strength("egypt"), world.total_strength("canaan"), _egypt_n, _canaan_n)
	hud.push_log("Megiddo awaits. Read the tablet, then begin.")


var _egypt_n: int = 0
var _canaan_n: int = 0
var _eg_str: float = 0.0
var _cn_str: float = 0.0


func _load_scenario() -> void:
	var path := "res://data/scenario_megiddo.json"
	if FileAccess.file_exists(path):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(raw) == TYPE_DICTIONARY:
			scenario = raw
			return
	scenario = {"player_side": "egypt", "map": {}, "egypt": {"units": []}, "canaan": {"units": []}}


func _on_start() -> void:
	_started = true
	world.paused = false
	hud.push_log("Trumpets of the royal division sound. Advance!")


func _toggle_pause() -> void:
	if not _started or world.game_over:
		return
	world.paused = not world.paused
	hud.set_paused_ui(world.paused)
	hud.push_log("Paused." if world.paused else "Resumed.")


func _on_ground_clicked(pos: Vector3, _shift: bool) -> void:
	if not _started or world.game_over or world.paused:
		return
	if world.selected.is_empty():
		hud.push_log("Select Egyptian troops first.")
		return
	if _attack_move_mode:
		world.order_attack_move(pos)
		_attack_move_mode = false
	else:
		world.order_move(pos)


func _on_unit_clicked(unit: BattleUnit, shift: bool) -> void:
	if not _started or world.game_over or world.paused:
		return
	world.select_unit(unit, shift)


func _on_strength(e: float, c: float) -> void:
	_eg_str = e
	_cn_str = c
	hud.set_strength(e, c, _egypt_n, _canaan_n)


func _on_counts(en: int, cn: int) -> void:
	_egypt_n = en
	_canaan_n = cn
	hud.set_strength(_eg_str, _cn_str, en, cn)


func _on_victory(side: String, reason: String) -> void:
	hud.show_victory(side, reason)
	hud.push_log(reason)


func _process(_delta: float) -> void:
	if world == null or hud == null:
		return
	hud.set_time(world.elapsed)
	hud.set_hold(world.get_hold_progress())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode == KEY_A and _started:
			_attack_move_mode = true
			hud.push_log("Attack-move armed.")
		elif event.keycode == KEY_H and _started:
			world.order_hold()
		elif event.keycode == KEY_F1 and _started:
			world.select_all_player()
