class_name GameWorld
extends Node3D
## Spawns armies, selection, orders, AI, victory.

signal selection_changed(units: Array)
signal strength_changed(egypt: float, canaan: float)
signal battle_log(text: String)
signal victory(side: String, reason: String)
signal unit_count_changed(egypt_n: int, canaan_n: int)

const UnitSceneScript = preload("res://scripts/unit.gd")

var scenario: Dictionary = {}
var units: Array = [] ## BattleUnit
var selected: Array = [] ## BattleUnit
var player_side: String = "egypt"
var game_over: bool = false
var winner: String = ""
var hold_megiddo_time: float = 0.0
var elapsed: float = 0.0
var paused: bool = false

var _egypt_root: Node3D
var _canaan_root: Node3D
var _rng := RandomNumberGenerator.new()
var megiddo_pos: Vector3 = Vector3(0, 0, -55)
var hold_need: float = 25.0
var collapse_ratio: float = 0.28
var time_limit: float = 900.0
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
	var mp: Array = map.get("megiddo_pos", [0, 0, -55])
	megiddo_pos = Vector3(float(mp[0]), float(mp[1]), float(mp[2]))
	var vic: Dictionary = scen.get("victory", {})
	hold_need = float(vic.get("hold_megiddo_seconds", 25))
	collapse_ratio = float(vic.get("enemy_strength_collapse", 0.28))
	time_limit = float(vic.get("time_limit_seconds", 900))
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
	selected.clear()
	emit_signal("battle_log", "The army of Pharaoh emerges from Aruna onto the plain of Megiddo.")
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
		for i in range(count):
			var u: BattleUnit = UnitSceneScript.new()
			var ang := float(i) * 0.7
			var ring := 1.2 + float(i % 5) * 0.9
			var pos := base + Vector3(cos(ang) * ring, 0.0, sin(ang) * ring)
			pos.y = 0.0
			var nm := uname if (uname != "" and i == 0) else ""
			u.setup(side, kind, pos, nm)
			u.died.connect(_on_unit_died)
			u.cry.connect(_on_unit_cry)
			parent.add_child(u)
			u.place(pos)
			units.append(u)


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
	# formation slotting
	var n: int = selected.size()
	var i := 0
	for u in selected:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var slot := _formation_offset(i, n)
		u.issue_move(pos + slot)
		i += 1
	battle_log.emit("March to field grid.")


func order_attack_move(pos: Vector3) -> void:
	if selected.is_empty():
		return
	var n: int = selected.size()
	var i := 0
	for u in selected:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		u.issue_attack_move(pos + _formation_offset(i, n))
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
	_ai_timer -= d
	if _ai_timer <= 0.0:
		_ai_timer = 0.85 if control_mode == "selfplay" else 1.1
		if control_mode == "selfplay" and learning_ai:
			learning_ai.think_both(self)
		else:
			_run_canaan_ai()
	_auto_acquire_targets(d)
	_check_victory(d)


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
	# centroid of egypt
	var ec := Vector3.ZERO
	for e in egypt_units:
		ec += e.global_position
	ec /= float(egypt_units.size())
	var egypt_near_city := ec.distance_to(megiddo_pos) < 40.0
	for u in canaan_units:
		if u.order == "attack" and u.attack_target and is_instance_valid(u.attack_target) and u.attack_target.is_alive():
			continue
		var foe: BattleUnit = _nearest_enemy(u, 55.0)
		if foe == null:
			continue
		# garrison hold megiddo if marked by proximity
		if u.global_position.distance_to(megiddo_pos) < 18.0 and not egypt_near_city:
			if u.order != "hold":
				u.issue_hold()
			var near: BattleUnit = _nearest_enemy(u, 14.0)
			if near:
				u.issue_attack(near)
			continue
		# chariots aggressive intercept
		if u.kind == "chariot":
			u.issue_attack(foe)
		elif egypt_near_city or u.global_position.distance_to(foe.global_position) < 28.0:
			u.issue_attack(foe)
		else:
			# screen the plain
			var screen := Vector3(u.global_position.x * 0.3, 0, -15.0)
			u.issue_attack_move(screen.lerp(foe.global_position, 0.35))


func _check_victory(delta: float) -> void:
	var es := total_strength("egypt")
	var cs := total_strength("canaan")
	if cs <= 10.0 or cs / _start_canaan_str <= collapse_ratio:
		_win("egypt", "The Canaanite host collapses. Megiddo's field is Pharaoh's.")
		return
	if es <= 10.0:
		_win("canaan", "Egypt's army is shattered on the plain.")
		return
	# hold megiddo: egyptian strength near city
	var egypt_on_city := 0.0
	var canaan_on_city := 0.0
	for u in units:
		if not u.is_alive():
			continue
		if u.global_position.distance_to(megiddo_pos) < 18.0:
			if u.side == "egypt":
				egypt_on_city += u.get_strength()
			else:
				canaan_on_city += u.get_strength()
	if egypt_on_city > canaan_on_city + 40.0 and egypt_on_city > 80.0:
		hold_megiddo_time += delta
	else:
		hold_megiddo_time = maxf(0.0, hold_megiddo_time - delta * 0.5)
	if hold_megiddo_time >= hold_need:
		_win("egypt", "Megiddo's approaches secured. The siege begins under Thutmose.")
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
