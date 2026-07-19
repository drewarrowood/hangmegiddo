extends Node3D
## Battle of Megiddo — 3D touch RTS + self-play learning.

const BattlefieldScript = preload("res://scripts/battlefield.gd")
const CameraRigScript = preload("res://scripts/camera_rig.gd")
const GameWorldScript = preload("res://scripts/game_world.gd")
const HUDScript = preload("res://scripts/hud.gd")
const LearningAIScript = preload("res://scripts/learning_ai.gd")

var battlefield: Battlefield
var camera_rig: CameraRig
var world: GameWorld
var hud: MegiddoHUD
var ai: MegiddoLearningAI
var scenario: Dictionary = {}
var _attack_move_mode: bool = false
var _started: bool = false
var _selfplay: bool = false
var _selfplay_auto: bool = false
var _pending_restart: bool = false
var _restart_cooldown: float = 0.0
var _egypt_n: int = 0
var _canaan_n: int = 0
var _eg_str: float = 0.0
var _cn_str: float = 0.0


func _ready() -> void:
	_load_scenario()
	ai = LearningAIScript.new()

	battlefield = BattlefieldScript.new()
	battlefield.name = "Battlefield"
	add_child(battlefield)
	battlefield.build(scenario)

	world = GameWorldScript.new()
	world.name = "GameWorld"
	add_child(world)
	world.learning_ai = ai
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
	hud.selfplay_toggled.connect(_on_selfplay_toggle)
	hud.brain_apply.connect(_on_brain_apply)
	hud.brain_reset.connect(_on_brain_reset)
	hud.new_battle.connect(_on_new_battle)
	world.selection_changed.connect(hud.set_selection)
	world.strength_changed.connect(_on_strength)
	world.unit_count_changed.connect(_on_counts)
	world.battle_log.connect(hud.push_log)
	world.victory.connect(_on_victory)

	_egypt_n = world.count_side("egypt")
	_canaan_n = world.count_side("canaan")
	hud.set_strength(world.total_strength("egypt"), world.total_strength("canaan"), _egypt_n, _canaan_n)
	hud.set_brain_text(ai.export_text())
	hud.set_ai_status(ai.status_text())
	hud.push_log("Megiddo awaits. Self-play trains AI; open BRAIN to Ctrl-A copy/paste weights.")
	if ai.games_played > 0:
		hud.push_log("Loaded AI brain: %s" % ai.status_text())


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
	if _selfplay:
		world.control_mode = "selfplay"
		world.time_scale = 2.2
		ai.begin_selfplay()
		hud.push_log("SELF-PLAY — both hosts commanded by learning AI.")
	else:
		world.control_mode = "human"
		world.time_scale = 1.0
		hud.push_log("Trumpets of the royal division sound. Advance!")
	hud.set_selfplay_ui(_selfplay)
	hud.set_ai_status(ai.status_text())


func _on_selfplay_toggle() -> void:
	if _selfplay:
		_stop_selfplay()
	else:
		_start_selfplay()


func _start_selfplay() -> void:
	_selfplay = true
	_selfplay_auto = true
	ai.reset_session()
	ai.begin_selfplay()
	world.control_mode = "selfplay"
	world.time_scale = 2.2
	if not _started:
		if hud.briefing_panel:
			hud.briefing_panel.visible = false
		_on_start()
	else:
		if world.game_over:
			_restart_keep_selfplay()
		else:
			world.paused = false
	hud.set_selfplay_ui(true)
	hud.push_log("SELF-PLAY ON — weights learn each war; BRAIN box updates for paste.")
	hud.set_ai_status(ai.status_text())
	hud.set_brain_text(ai.export_text())


func _stop_selfplay() -> void:
	_selfplay = false
	_selfplay_auto = false
	_pending_restart = false
	world.control_mode = "human"
	world.time_scale = 1.0
	world.paused = true
	ai.save_brain()
	hud.set_selfplay_ui(false)
	hud.set_brain_text(ai.export_text())
	hud.set_ai_status(ai.status_text())
	hud.push_log("SELF-PLAY STOPPED — %s" % ai.status_text())
	if ai.last_save_ok:
		hud.push_log("Brain file save: %s" % ", ".join(ai.last_save_paths))
	else:
		hud.push_log("No file write (web?) — use BRAIN panel: Select All → copy → paste later.")


func _restart_keep_selfplay() -> void:
	world.restart_battle()
	world.control_mode = "selfplay"
	world.time_scale = 2.2
	world.paused = false
	_started = true
	if hud.victory_panel:
		hud.victory_panel.visible = false
	_egypt_n = world.count_side("egypt")
	_canaan_n = world.count_side("canaan")
	hud.set_strength(world.total_strength("egypt"), world.total_strength("canaan"), _egypt_n, _canaan_n)
	hud.push_log("—— Self-play war %d ——" % (ai.session_games + 1))
	hud.set_ai_status(ai.status_text())


func _on_new_battle() -> void:
	if _selfplay:
		_restart_keep_selfplay()
		return
	world.restart_battle()
	world.control_mode = "human"
	world.time_scale = 1.0
	world.paused = false
	_started = true
	if hud.victory_panel:
		hud.victory_panel.visible = false
	if hud.briefing_panel:
		hud.briefing_panel.visible = false
	_egypt_n = world.count_side("egypt")
	_canaan_n = world.count_side("canaan")
	hud.set_strength(world.total_strength("egypt"), world.total_strength("canaan"), _egypt_n, _canaan_n)
	hud.push_log("New battle — armies reformed on the plain.")


func _on_brain_apply(text: String) -> void:
	if ai.import_text(text):
		hud.set_brain_text(ai.export_text())
		hud.set_ai_status(ai.status_text())
		hud.push_log("Brain imported. %s" % ai.status_text())
	else:
		hud.push_log("Brain import FAILED — paste a full HANG_MEGIDDO_BRAIN_V1 block.")


func _on_brain_reset() -> void:
	ai.reset_brain()
	hud.set_brain_text(ai.export_text())
	hud.set_ai_status(ai.status_text())
	hud.push_log("AI brain reset to priors.")


func _toggle_pause() -> void:
	if not _started or world.game_over:
		return
	world.paused = not world.paused
	hud.set_paused_ui(world.paused)
	hud.push_log("Paused." if world.paused else "Resumed.")


func _on_ground_clicked(pos: Vector3, _shift: bool) -> void:
	if not _started or world.game_over or world.paused or _selfplay:
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
	if not _started or world.game_over or world.paused or _selfplay:
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
	if _selfplay and ai:
		var summary: Dictionary = ai.end_selfplay_episode(side, world)
		hud.set_brain_text(str(summary.get("export", ai.export_text())))
		hud.set_ai_status(ai.status_text())
		hud.push_log("SELF-PLAY END: %s — %s" % [side.to_upper(), reason])
		hud.push_log("LEARN E%+.2f C%+.2f |w|=%.2f session E%d–C%d" % [
			float(summary.get("reward_egypt", 0)),
			float(summary.get("reward_canaan", 0)),
			float(summary.get("weight_norm", 0)),
			int(summary.get("session_egypt", 0)),
			int(summary.get("session_canaan", 0)),
		])
		if bool(summary.get("saved", false)):
			hud.push_log("Weights saved to: %s" % ", ".join(ai.last_save_paths))
		else:
			hud.push_log("File save unavailable — open BRAIN, Select All, copy text to keep progress.")
		# Show compact victory then auto-continue
		if hud.victory_panel:
			hud.victory_panel.visible = true
		hud.victory_label.text = "SELF-PLAY · %s wins\n%s\n%s\nBrain updated — paste from BRAIN panel anytime." % [
			side.to_upper(), reason, ai.status_text()
		]
		if _selfplay_auto:
			_pending_restart = true
			_restart_cooldown = 1.25
		return
	hud.show_victory(side, reason)
	hud.push_log(reason)


func _process(delta: float) -> void:
	if world == null or hud == null:
		return
	hud.set_time(world.elapsed)
	hud.set_hold(world.get_hold_progress())
	if _selfplay:
		hud.set_ai_status(ai.status_text() + "\nday-sec %.0f  mode SELF-PLAY ×%.1f" % [world.elapsed, world.time_scale])
	if _pending_restart:
		_restart_cooldown -= delta
		if _restart_cooldown <= 0.0:
			_pending_restart = false
			if _selfplay and _selfplay_auto:
				_restart_keep_selfplay()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud and hud.brain_panel and hud.brain_panel.visible:
			hud.brain_panel.visible = false
			return
		_toggle_pause()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode == KEY_A and _started and not _selfplay:
			_attack_move_mode = true
			hud.push_log("Attack-move armed.")
		elif event.keycode == KEY_H and _started and not _selfplay:
			world.order_hold()
		elif event.keycode == KEY_F1 and _started and not _selfplay:
			world.select_all_player()
		elif event.keycode == KEY_P:
			_on_selfplay_toggle()
		elif event.keycode == KEY_B:
			if hud:
				hud._toggle_brain()
