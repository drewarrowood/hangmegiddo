class_name GameWorld
extends Node3D
## Spawns armies, selection, orders, AI, victory.

signal selection_changed(units: Array)
signal strength_changed(egypt: float, canaan: float)
signal battle_log(text: String)
signal victory(side: String, reason: String)
signal unit_count_changed(egypt_n: int, canaan_n: int)
signal phase_changed(phase: String, detail: String)

const UnitSceneScript = preload("res://scripts/unit.gd")

const PHASE_EMERGE := "emerge"
const PHASE_DEPLOY := "deploy"
const PHASE_BATTLE := "battle"

var scenario: Dictionary = {}
var units: Array = [] ## BattleUnit
var selected: Array = [] ## BattleUnit
var player_side: String = "egypt"
var game_over: bool = false
var winner: String = ""
var hold_megiddo_time: float = 0.0
var elapsed: float = 0.0
var paused: bool = false
var phase: String = PHASE_EMERGE
var phase_time: float = 0.0
var battlefield = null ## Battlefield

var _egypt_root: Node3D
var _canaan_root: Node3D
var _rng := RandomNumberGenerator.new()
var megiddo_pos: Vector3 = Vector3(0, 0, -58)
var pass_mouth: Vector3 = Vector3(0, 0, 32)
var hold_need: float = 28.0
var collapse_ratio: float = 0.28
var time_limit: float = 900.0
var emerge_seconds: float = 28.0
var deploy_seconds: float = 12.0
var _start_canaan_str: float = 1.0
var _start_egypt_str: float = 1.0
var _ai_timer: float = 0.0
## "human" = player egypt, AI canaan · "selfplay" = both learning AI
var control_mode: String = "human"
var learning_ai = null
var time_scale: float = 1.0


func setup(scen: Dictionary) -> void:
	scenario = scen
	player_side = str(scen.get("player_side", "egypt"))
	var map: Dictionary = scen.get("map", {})
	var mp: Array = map.get("megiddo_pos", [0, 0, -58])
	megiddo_pos = Vector3(float(mp[0]), float(mp[1]), float(mp[2]))
	var pm: Array = map.get("pass_mouth", [0, 0, 32])
	pass_mouth = Vector3(float(pm[0]), float(pm[1]), float(pm[2]))
	var vic: Dictionary = scen.get("victory", {})
	hold_need = float(vic.get("hold_megiddo_seconds", 28))
	collapse_ratio = float(vic.get("enemy_strength_collapse", 0.28))
	time_limit = float(vic.get("time_limit_seconds", 900))
	var ph: Dictionary = scen.get("phases", {})
	emerge_seconds = float(ph.get("emerge_seconds", 28))
	deploy_seconds = float(ph.get("deploy_seconds", 12))
	_rng.randomize()
	_clear_armies()
	_egypt_root = Node3D.new()
	_egypt_root.name = "Egypt"
	add_child(_egypt_root)
	_canaan_root = Node3D.new()
	_canaan_root.name = "Canaan"
	add_child(_canaan_root)
	_spawn_side("egypt", scen.get("egypt", {}))
	_spawn_side("canaan", scen.get("canaan", {}))
	_start_canaan_str = maxf(total_strength("canaan"), 1.0)
	_start_egypt_str = maxf(total_strength("egypt"), 1.0)
	game_over = false
	winner = ""
	hold_megiddo_time = 0.0
	elapsed = 0.0
	phase_time = 0.0
	phase = PHASE_EMERGE
	selected.clear()
	_begin_emerge_orders()
	battle_log.emit("Year 23: His Majesty forces the Aruna road. Column in the gorge—plain ahead.")
	phase_changed.emit(phase, "Emerging from Aruna pass")
	_emit_strength()


func _clear_armies() -> void:
	for u in units:
		if is_instance_valid(u):
			u.queue_free()
	units.clear()
	selected.clear()
	if _egypt_root and is_instance_valid(_egypt_root):
		_egypt_root.queue_free()
	if _canaan_root and is_instance_valid(_canaan_root):
		_canaan_root.queue_free()
	_egypt_root = null
	_canaan_root = null


func restart_battle() -> void:
	setup(scenario)
	if control_mode == "selfplay" and learning_ai:
		learning_ai.begin_selfplay()


func _spawn_side(side: String, data: Dictionary) -> void:
	var parent: Node3D = _egypt_root if side == "egypt" else _canaan_root
	for group in data.get("units", []):
		var kind: String = str(group.get("kind", "spearman"))
		var count: int = int(group.get("count", 1))
		var off: Array = group.get("offset", [0, 0])
		var base := Vector3(float(off[0]), 0.0, float(off[1]))
		var uname: String = str(group.get("name", ""))
		var form: String = str(group.get("formation", "block"))
		for i in range(count):
			var u: BattleUnit = UnitSceneScript.new()
			var pos := base + _spawn_slot(i, count, form, side)
			pos.y = 0.0
			var nm := uname if (uname != "" and i == 0) else ""
			u.setup(side, kind, pos, nm)
			u.died.connect(_on_unit_died)
			u.cry.connect(_on_unit_cry)
			parent.add_child(u)
			u.place(pos)
			units.append(u)


func _spawn_slot(i: int, n: int, form: String, side: String) -> Vector3:
	match form:
		"column":
			# single-file up the gorge (northward = -Z toward plain from deep south)
			return Vector3((float(i % 2) - 0.5) * 1.4, 0.0, float(i) * 1.35)
		"line":
			return Vector3((float(i) - float(n) * 0.5) * 2.0, 0.0, float(i % 2) * 1.2)
		_:
			var cols := int(ceili(sqrt(float(maxi(n, 1)))))
			var row: int = i / maxi(cols, 1)
			var col: int = i % maxi(cols, 1)
			var face := -1.0 if side == "canaan" else 1.0
			return Vector3((float(col) - float(cols) * 0.5) * 1.7, 0.0, float(row) * 1.6 * face)


func _begin_emerge_orders() -> void:
	## Egypt marches out of the gorge onto the pass mouth / plain.
	for u in units:
		if not u.is_alive() or u.side != "egypt":
			continue
		var dest := pass_mouth + Vector3(randf_range(-10, 10), 0, randf_range(-4, 8))
		if u.kind == "chariot":
			dest.z = mini(dest.z, pass_mouth.z + 2.0)
			dest = _clamp_order(u, dest)
		u.issue_attack_move(dest)
	# Canaan holds the plain lines (already deployed historically)
	for u2 in units:
		if u2.is_alive() and u2.side == "canaan" and u2.global_position.distance_to(megiddo_pos) > 20.0:
			u2.issue_hold()


func _clamp_order(u: BattleUnit, pos: Vector3) -> Vector3:
	if battlefield and battlefield.has_method("clamp_move_for_kind"):
		return battlefield.clamp_move_for_kind(u.kind, pos)
	return pos


func _on_unit_died(u: BattleUnit) -> void:
	if selected.has(u):
		selected.erase(u)
		selection_changed.emit(selected.duplicate())
	units.erase(u)
	_emit_strength()
	if u.side == "canaan":
		battle_log.emit("Canaanite %s broken." % u.display_name)
	else:
		battle_log.emit("Egyptian %s fallen!" % u.display_name)


func _on_unit_cry(u: BattleUnit, text: String) -> void:
	if text == "":
		return
	if randf() < 0.35:
		var lang := "Egyptian" if u.side == "egypt" else "Canaanite"
		battle_log.emit("%s %s: «%s»" % [lang, u.display_name, text])


func _emit_strength() -> void:
	strength_changed.emit(total_strength("egypt"), total_strength("canaan"))
	unit_count_changed.emit(count_side("egypt"), count_side("canaan"))


func total_strength(side: String) -> float:
	var s := 0.0
	for u in units:
		if u.side == side and u.is_alive():
			s += u.get_strength()
	return s


func count_side(side: String) -> int:
	var n := 0
	for u in units:
		if u.side == side and u.is_alive():
			n += 1
	return n


func clear_selection() -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected.clear()
	selection_changed.emit(selected.duplicate())


func select_unit(u: BattleUnit, additive: bool = false) -> void:
	if u == null or not u.is_alive():
		return
	if u.side != player_side:
		# enemy: set as attack target for current selection
		if selected.size() > 0:
			for s in selected:
				if is_instance_valid(s) and s.is_alive():
					s.issue_attack(u)
			battle_log.emit("Attack ordered: %s" % u.display_name)
		return
	if not additive:
		clear_selection()
	if not selected.has(u):
		selected.append(u)
		u.set_selected(true)
	selection_changed.emit(selected.duplicate())


func select_all_player() -> void:
	clear_selection()
	for u in units:
		if u.side == player_side and u.is_alive():
			selected.append(u)
			u.set_selected(true)
	selection_changed.emit(selected.duplicate())


func order_move(pos: Vector3) -> void:
	if selected.is_empty():
		return
	var n: int = selected.size()
	var i := 0
	for u in selected:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var slot := _formation_offset(i, n)
		var dest := _clamp_order(u, pos + slot)
		u.issue_move(dest)
		i += 1
	battle_log.emit("March ordered.")


func order_attack_move(pos: Vector3) -> void:
	if selected.is_empty():
		return
	var n: int = selected.size()
	var i := 0
	for u in selected:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var dest := _clamp_order(u, pos + _formation_offset(i, n))
		u.issue_attack_move(dest)
		i += 1
	battle_log.emit("Advance and engage.")


func order_hold() -> void:
	for u in selected:
		if is_instance_valid(u) and u.is_alive():
			u.issue_hold()
	battle_log.emit("Hold the line.")


func order_stop() -> void:
	for u in selected:
		if is_instance_valid(u) and u.is_alive():
			u.issue_hold()


func _formation_offset(i: int, n: int) -> Vector3:
	var cols := int(ceili(sqrt(float(n))))
	var row: int = i / maxi(cols, 1)
	var col: int = i % maxi(cols, 1)
	return Vector3((float(col) - float(cols) * 0.5) * 1.6, 0.0, float(row) * 1.6)


func _process(delta: float) -> void:
	if paused or game_over:
		return
	var d: float = delta * time_scale
	elapsed += d
	phase_time += d
	_update_phase()
	_ai_timer -= d
	if _ai_timer <= 0.0:
		_ai_timer = 0.85 if control_mode == "selfplay" else 1.1
		if phase == PHASE_EMERGE and control_mode != "selfplay":
			# Canaan holds; Egypt scripted emerge
			pass
		elif control_mode == "selfplay" and learning_ai:
			learning_ai.think_both(self)
		else:
			_run_canaan_ai()
	if phase != PHASE_EMERGE or control_mode == "selfplay":
		_auto_acquire_targets(d)
	_check_victory(d)


func _update_phase() -> void:
	if phase == PHASE_EMERGE and phase_time >= emerge_seconds:
		phase = PHASE_DEPLOY
		phase_time = 0.0
		battle_log.emit("The host debouches onto the plain. Form the wings—Megiddo lies north.")
		phase_changed.emit(phase, "Deploy on the plain")
		_deploy_egypt_wings()
	elif phase == PHASE_DEPLOY and phase_time >= deploy_seconds:
		phase = PHASE_BATTLE
		phase_time = 0.0
		battle_log.emit("Battle is joined on the plain before Megiddo.")
		phase_changed.emit(phase, "Battle")


func _deploy_egypt_wings() -> void:
	## After emerging: chariots to wings, infantry center (historical feel).
	for u in units:
		if not u.is_alive() or u.side != "egypt":
			continue
		if u.order == "attack" and u.attack_target:
			continue
		var dest: Vector3
		match u.kind:
			"chariot":
				var side_x := -22.0 if u.global_position.x < 0.0 else 22.0
				dest = Vector3(side_x, 0, pass_mouth.z - 12.0)
			"archer":
				dest = Vector3(clampf(u.global_position.x, -8, 8), 0, pass_mouth.z - 6.0)
			"hero":
				dest = Vector3(0, 0, pass_mouth.z - 10.0)
			_:
				dest = Vector3(clampf(u.global_position.x * 0.5, -14, 14), 0, pass_mouth.z - 14.0)
		u.issue_move(_clamp_order(u, dest))


func _auto_acquire_targets(_delta: float) -> void:
	# attack-move and idle units near enemies engage
	for u in units:
		if not u.is_alive():
			continue
		if u.order == "attack" and u.attack_target and is_instance_valid(u.attack_target):
			continue
		if u.order in ["move"]:
			continue
		if u.order == "hold":
			var foe_h := _nearest_enemy(u, u.attack_range + 1.0)
			if foe_h:
				u.issue_attack(foe_h)
			continue
		if u.order in ["idle", "attack_move"]:
			var foe := _nearest_enemy(u, 16.0 if u.kind == "archer" else 10.0)
			if foe:
				u.issue_attack(foe)


func _nearest_enemy(u: BattleUnit, radius: float) -> BattleUnit:
	var best: BattleUnit = null
	var best_d := radius
	for o in units:
		if not o.is_alive() or o.side == u.side:
			continue
		var d: float = u.global_position.distance_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func _run_canaan_ai() -> void:
	var canaan_units: Array = []
	var egypt_units: Array = []
	for u in units:
		if not u.is_alive():
			continue
		if u.side == "canaan":
			canaan_units.append(u)
		else:
			egypt_units.append(u)
	if canaan_units.is_empty() or egypt_units.is_empty():
		return
	var ec := Vector3.ZERO
	for e in egypt_units:
		ec += e.global_position
	ec /= float(egypt_units.size())
	var egypt_on_plain := ec.z < 25.0
	var egypt_near_city := ec.distance_to(megiddo_pos) < 36.0
	for u in canaan_units:
		if u.order == "attack" and u.attack_target and is_instance_valid(u.attack_target) and u.attack_target.is_alive():
			continue
		var foe: BattleUnit = _nearest_enemy(u, 55.0)
		if foe == null:
			continue
		# Garrison holds the mound/gate
		if u.global_position.distance_to(megiddo_pos) < 22.0 and not egypt_near_city:
			u.issue_hold()
			var near: BattleUnit = _nearest_enemy(u, 14.0)
			if near:
				u.issue_attack(near)
			continue
		# During emerge, main line waits (expected the other roads)
		if phase == PHASE_EMERGE and not egypt_on_plain:
			u.issue_hold()
			continue
		if u.kind == "chariot":
			var dest := _clamp_order(u, foe.global_position)
			u.issue_attack_move(dest)
		elif egypt_near_city or u.global_position.distance_to(foe.global_position) < 26.0:
			u.issue_attack(foe)
		else:
			var screen := Vector3(u.global_position.x * 0.4, 0, -14.0)
			u.issue_attack_move(_clamp_order(u, screen.lerp(foe.global_position, 0.4)))


func _check_victory(delta: float) -> void:
	var es := total_strength("egypt")
	var cs := total_strength("canaan")
	if cs <= 10.0 or cs / _start_canaan_str <= collapse_ratio:
		_win("egypt", "The Canaanite host collapses. Megiddo's field is Pharaoh's.")
		return
	if es <= 10.0:
		_win("canaan", "Egypt's army is shattered on the plain.")
		return
	# Hold the gate approaches (south of the tell), not the summit alone
	var gate := megiddo_pos + Vector3(0, 0, 18)
	var egypt_on_city := 0.0
	var canaan_on_city := 0.0
	for u in units:
		if not u.is_alive():
			continue
		if u.global_position.distance_to(gate) < 16.0 or u.global_position.distance_to(megiddo_pos) < 20.0:
			if u.side == "egypt":
				egypt_on_city += u.get_strength()
			else:
				canaan_on_city += u.get_strength()
	if egypt_on_city > canaan_on_city + 40.0 and egypt_on_city > 80.0:
		hold_megiddo_time += delta
	else:
		hold_megiddo_time = maxf(0.0, hold_megiddo_time - delta * 0.5)
	if hold_megiddo_time >= hold_need:
		_win("egypt", "The gate of Megiddo is sealed. The siege begins under Thutmose.")
		return
	if elapsed >= time_limit:
		if es >= cs:
			_win("egypt", "Night falls — Egypt holds the field.")
		else:
			_win("canaan", "Night falls — the coalition still bars the gate.")


func _win(side: String, reason: String) -> void:
	if game_over:
		return
	game_over = true
	winner = side
	paused = true
	victory.emit(side, reason)
	battle_log.emit(reason)


func get_hold_progress() -> float:
	return clampf(hold_megiddo_time / hold_need, 0.0, 1.0)
