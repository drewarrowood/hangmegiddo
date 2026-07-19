class_name MegiddoLearningAI
extends RefCounted
## Linear policy AI for Megiddo self-play. Learns from wins; exports pasteable brain text.

const BRAIN_USER := "user://megiddo_ai_brain.json"
const BRAIN_RES := "res://data/megiddo_ai_brain.json"
const BRAIN_MAGIC := "HANG_MEGIDDO_BRAIN_V1"

const FEATURES := [
	"bias",
	"strength_ratio",
	"own_city",
	"enemy_city",
	"time_frac",
	"chariot_ratio",
	"own_weak",
	"enemy_weak",
	"hold_progress",
]
const ACTIONS := [
	"charge_center",
	"flank_left",
	"flank_right",
	"push_city",
	"hold_line",
	"chariot_strike",
	"archer_harass",
	"retreat_regroup",
	"noop",
]

var weights: Dictionary = {}
var games_played: int = 0
var wins: Dictionary = {"egypt": 0, "canaan": 0}
var losses: Dictionary = {"egypt": 0, "canaan": 0}
var session_games: int = 0
var session_wins: Dictionary = {"egypt": 0, "canaan": 0}
var learning_rate: float = 0.1
var epsilon: float = 0.2
var temperature: float = 1.1
var rng := RandomNumberGenerator.new()
var last_save_ok: bool = false
var last_save_paths: PackedStringArray = PackedStringArray()
var last_export_text: String = ""
var last_winner: String = ""
var weight_norm: float = 0.0

## side -> Array of {action, features}
var _traces: Dictionary = {"egypt": [], "canaan": []}
var selfplay_mode: bool = false


func _init() -> void:
	rng.randomize()
	_ensure_weights()
	load_brain()
	_recompute_norm()
	last_export_text = export_text()


func begin_selfplay() -> void:
	selfplay_mode = true
	_traces = {"egypt": [], "canaan": []}


func reset_session() -> void:
	session_games = 0
	session_wins = {"egypt": 0, "canaan": 0}


func _ensure_weights() -> void:
	for a in ACTIONS:
		if not weights.has(a):
			weights[a] = {}
		for f in FEATURES:
			if not weights[a].has(f):
				var w := 0.0
				if a == "push_city" and f == "enemy_city":
					w = 0.5
				elif a == "charge_center" and f == "strength_ratio":
					w = 0.4
				elif a == "hold_line" and f == "own_weak":
					w = 0.45
				elif a == "chariot_strike" and f == "chariot_ratio":
					w = 0.55
				elif a == "noop" and f == "bias":
					w = -0.3
				elif f == "bias":
					w = 0.05
				weights[a][f] = w


func extract_features(world, side: String) -> Dictionary:
	var enemy := "canaan" if side == "egypt" else "egypt"
	var own: float = maxf(world.total_strength(side), 1.0)
	var en: float = maxf(world.total_strength(enemy), 1.0)
	var city: Vector3 = world.megiddo_pos
	var own_city := 0.0
	var en_city := 0.0
	var own_ch := 0
	var own_n := 0
	for u in world.units:
		if not u.is_alive():
			continue
		if u.side == side:
			own_n += 1
			if u.kind == "chariot":
				own_ch += 1
			if u.global_position.distance_to(city) < 22.0:
				own_city += u.get_strength()
		elif u.side == enemy:
			if u.global_position.distance_to(city) < 22.0:
				en_city += u.get_strength()
	var tl: float = maxf(world.time_limit, 1.0)
	return {
		"bias": 1.0,
		"strength_ratio": clampf(own / en, 0.0, 3.0) / 3.0,
		"own_city": clampf(own_city / 400.0, 0.0, 1.0),
		"enemy_city": clampf(en_city / 400.0, 0.0, 1.0),
		"time_frac": clampf(world.elapsed / tl, 0.0, 1.0),
		"chariot_ratio": clampf(float(own_ch) / float(maxi(own_n, 1)), 0.0, 1.0),
		"own_weak": 1.0 if own < en * 0.75 else 0.0,
		"enemy_weak": 1.0 if en < own * 0.75 else 0.0,
		"hold_progress": world.get_hold_progress() if side == "egypt" else (1.0 - world.get_hold_progress()),
	}


func score_action(action: String, feats: Dictionary) -> float:
	var w: Dictionary = weights.get(action, {})
	var s := 0.0
	for f in FEATURES:
		s += float(w.get(f, 0.0)) * float(feats.get(f, 0.0))
	return s


func choose_action(world, side: String) -> String:
	var feats: Dictionary = extract_features(world, side)
	if rng.randf() < _explore():
		var a: String = ACTIONS[rng.randi_range(0, ACTIONS.size() - 1)]
		_record(side, a, feats)
		return a
	var scores: Array = []
	var max_s := -1e9
	for a2 in ACTIONS:
		var sc: float = score_action(a2, feats)
		scores.append(sc)
		if sc > max_s:
			max_s = sc
	var exps: Array = []
	var sum_e := 0.0
	for sc2 in scores:
		var e: float = exp((float(sc2) - max_s) / temperature)
		exps.append(e)
		sum_e += e
	var r: float = rng.randf() * sum_e
	var cum := 0.0
	var pick: String = ACTIONS[0]
	for i in range(ACTIONS.size()):
		cum += float(exps[i])
		if r <= cum:
			pick = ACTIONS[i]
			break
	_record(side, pick, feats)
	return pick


func _explore() -> float:
	return clampf(epsilon * exp(-float(games_played) / 60.0), 0.05, 0.35)


func _record(side: String, action: String, feats: Dictionary) -> void:
	if not _traces.has(side):
		_traces[side] = []
	_traces[side].append({"action": action, "features": feats.duplicate()})
	if (_traces[side] as Array).size() > 80:
		_traces[side] = (_traces[side] as Array).slice((_traces[side] as Array).size() - 80)


func think(world, side: String) -> String:
	if world == null or world.game_over:
		return "noop"
	var action: String = choose_action(world, side)
	_execute(world, side, action)
	return action


func think_both(world) -> Dictionary:
	return {
		"egypt": think(world, "egypt"),
		"canaan": think(world, "canaan"),
	}


func _execute(world, side: String, action: String) -> void:
	var enemy := "canaan" if side == "egypt" else "egypt"
	var city: Vector3 = world.megiddo_pos
	var own: Array = []
	var foes: Array = []
	for u in world.units:
		if not u.is_alive():
			continue
		if u.side == side:
			own.append(u)
		elif u.side == enemy:
			foes.append(u)
	if own.is_empty():
		return
	var foe_c := _centroid(foes)
	var own_c := _centroid(own)
	match action:
		"charge_center":
			_order_group(own, "all", foe_c if foes.size() > 0 else city, true)
		"flank_left":
			var left := foe_c + Vector3(-22, 0, 6)
			_order_group(own, "chariot", left, true)
			_order_group(own, "spearman", foe_c, true)
			_order_group(own, "archer", own_c.lerp(foe_c, 0.4), false)
		"flank_right":
			var right := foe_c + Vector3(22, 0, 6)
			_order_group(own, "chariot", right, true)
			_order_group(own, "spearman", foe_c, true)
			_order_group(own, "archer", own_c.lerp(foe_c, 0.4), false)
		"push_city":
			_order_group(own, "all", city + Vector3(0, 0, 8), true)
		"hold_line":
			for u in own:
				u.issue_hold()
		"chariot_strike":
			_order_group(own, "chariot", foe_c if foes.size() > 0 else city, true)
			_order_group(own, "spearman", own_c.lerp(foe_c, 0.5), true)
		"archer_harass":
			var stand := foe_c + (own_c - foe_c).normalized() * 12.0 if foes.size() > 0 else own_c
			_order_group(own, "archer", stand, true)
			_order_group(own, "chariot", foe_c, true)
		"retreat_regroup":
			var back: Vector3
			if side == "egypt":
				back = Vector3(0, 0, 45)
			else:
				back = city + Vector3(0, 0, -5)
			_order_group(own, "all", back, false)
		_:
			pass


func _centroid(arr: Array) -> Vector3:
	if arr.is_empty():
		return Vector3.ZERO
	var c := Vector3.ZERO
	for u in arr:
		c += u.global_position
	return c / float(arr.size())


func _order_group(own: Array, filter_kind: String, target: Vector3, attack_move: bool) -> void:
	var i := 0
	var world_ref = null
	if own.size() > 0 and is_instance_valid(own[0]):
		world_ref = own[0].get_parent()
		while world_ref and not (world_ref is GameWorld):
			world_ref = world_ref.get_parent()
	for u in own:
		if filter_kind != "all" and u.kind != filter_kind and not (filter_kind == "spearman" and u.kind == "hero"):
			continue
		var slot := Vector3(float(i % 5 - 2) * 1.5, 0, float(i / 5) * 1.4)
		var dest: Vector3 = target + slot
		if world_ref and world_ref.has_method("_clamp_order"):
			dest = world_ref._clamp_order(u, dest)
		if attack_move:
			u.issue_attack_move(dest)
		else:
			u.issue_move(dest)
		i += 1


func end_selfplay_episode(winner: String, world = null) -> Dictionary:
	if winner == "":
		winner = "egypt"
	var r_e := _reward(winner, "egypt", world)
	var r_c := _reward(winner, "canaan", world)
	_apply(_traces.get("egypt", []), r_e)
	_apply(_traces.get("canaan", []), r_c)
	_recompute_norm()
	games_played += 1
	session_games += 1
	last_winner = winner
	if winner == "egypt":
		wins["egypt"] = int(wins.get("egypt", 0)) + 1
		losses["canaan"] = int(losses.get("canaan", 0)) + 1
		session_wins["egypt"] = int(session_wins.get("egypt", 0)) + 1
	else:
		wins["canaan"] = int(wins.get("canaan", 0)) + 1
		losses["egypt"] = int(losses.get("egypt", 0)) + 1
		session_wins["canaan"] = int(session_wins.get("canaan", 0)) + 1
	_traces = {"egypt": [], "canaan": []}
	selfplay_mode = false
	var saved := save_brain()
	last_export_text = export_text()
	return {
		"winner": winner,
		"reward_egypt": r_e,
		"reward_canaan": r_c,
		"games": games_played,
		"session_games": session_games,
		"session_egypt": int(session_wins.get("egypt", 0)),
		"session_canaan": int(session_wins.get("canaan", 0)),
		"saved": saved,
		"export": last_export_text,
		"weight_norm": weight_norm,
		"epsilon": _explore(),
	}


func _reward(winner: String, side: String, world) -> float:
	var r: float = 1.0 if winner == side else -1.0
	if world != null:
		var own: float = world.total_strength(side)
		var en: float = world.total_strength("canaan" if side == "egypt" else "egypt")
		r += clampf((own - en) / 2000.0, -0.4, 0.4)
		if side == "egypt":
			r += world.get_hold_progress() * 0.2
	return r


func _apply(trace: Array, reward: float) -> void:
	var n: int = maxi(trace.size(), 1)
	var i := 0
	for step in trace:
		var decay: float = 0.5 + 0.5 * (float(i) / float(n))
		var action: String = str(step.get("action", "noop"))
		var feats: Dictionary = step.get("features", {})
		if not weights.has(action):
			weights[action] = {}
		for f in FEATURES:
			var fv: float = float(feats.get(f, 0.0))
			var old: float = float(weights[action].get(f, 0.0))
			weights[action][f] = clampf(old + learning_rate * reward * decay * fv, -4.0, 4.0)
		i += 1


func _recompute_norm() -> void:
	var s := 0.0
	for a in weights:
		for f in weights[a]:
			var v: float = float(weights[a][f])
			s += v * v
	weight_norm = sqrt(s)


func export_text() -> String:
	## Single pasteable blob — Ctrl-A friendly, no file required.
	var doc := {
		"magic": BRAIN_MAGIC,
		"version": 1,
		"games_played": games_played,
		"wins": wins,
		"losses": losses,
		"learning_rate": learning_rate,
		"epsilon": epsilon,
		"weight_norm": weight_norm,
		"session_games": session_games,
		"session_wins": session_wins,
		"last_winner": last_winner,
		"weights": weights,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	var json := JSON.stringify(doc)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("===== " + BRAIN_MAGIC + " =====")
	lines.append("# Hang Megiddo learning brain — select ALL, copy, paste elsewhere to persist.")
	lines.append("# games=%d |w|=%.3f ε=%.3f egypt_wins=%d canaan_wins=%d" % [
		games_played, weight_norm, _explore(),
		int(wins.get("egypt", 0)), int(wins.get("canaan", 0))
	])
	lines.append(json)
	lines.append("===== END " + BRAIN_MAGIC + " =====")
	return "\n".join(lines)


func import_text(raw: String) -> bool:
	var t := raw.strip_edges()
	if t.is_empty():
		return false
	var doc: Dictionary = {}
	# Prefer first complete JSON object (handles triple-paste / glued END===== headers)
	var extracted := _extract_first_json_object(t)
	var raw_try: Variant = null
	if extracted != "":
		raw_try = JSON.parse_string(extracted)
	if typeof(raw_try) != TYPE_DICTIONARY:
		# strip markers / comments and join
		var lines := t.split("\n")
		var json_parts: PackedStringArray = PackedStringArray()
		for line in lines:
			var s := str(line).strip_edges()
			if s.begins_with("=====") or s.begins_with("#") or s.is_empty():
				continue
			json_parts.append(s)
		raw_try = JSON.parse_string("".join(json_parts))
	if typeof(raw_try) != TYPE_DICTIONARY:
		raw_try = JSON.parse_string(t)
	if typeof(raw_try) != TYPE_DICTIONARY:
		return false
	doc = raw_try
	if str(doc.get("magic", "")) != "" and str(doc.get("magic", "")) != BRAIN_MAGIC:
		if not doc.has("weights"):
			return false
	games_played = int(doc.get("games_played", 0))
	if doc.has("wins"):
		wins = doc["wins"]
	if doc.has("losses"):
		losses = doc["losses"]
	if doc.has("session_wins"):
		session_wins = doc["session_wins"]
	if doc.has("session_games"):
		session_games = int(doc["session_games"])
	if doc.has("last_winner"):
		last_winner = str(doc["last_winner"])
	learning_rate = float(doc.get("learning_rate", learning_rate))
	epsilon = float(doc.get("epsilon", epsilon))
	if doc.has("weights") and typeof(doc["weights"]) == TYPE_DICTIONARY:
		weights = doc["weights"]
	_ensure_weights()
	_recompute_norm()
	last_export_text = export_text()
	save_brain()
	return true


func _extract_first_json_object(text: String) -> String:
	var start := text.find("{")
	if start < 0:
		return ""
	var depth := 0
	var in_str := false
	var esc := false
	for i in range(start, text.length()):
		var ch := text[i]
		if in_str:
			if esc:
				esc = false
			elif ch == "\\":
				esc = true
			elif ch == "\"":
				in_str = false
			continue
		if ch == "\"":
			in_str = true
		elif ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return text.substr(start, i - start + 1)
	return ""


func save_brain() -> bool:
	_recompute_norm()
	last_export_text = export_text()
	var doc := {
		"magic": BRAIN_MAGIC,
		"version": 1,
		"games_played": games_played,
		"wins": wins,
		"losses": losses,
		"learning_rate": learning_rate,
		"epsilon": epsilon,
		"weight_norm": weight_norm,
		"weights": weights,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	var text := JSON.stringify(doc, "\t")
	last_save_paths = PackedStringArray()
	var any := false
	var paths: Array = [BRAIN_USER, BRAIN_RES]
	var abs_p := ProjectSettings.globalize_path(BRAIN_RES)
	if abs_p != "" and abs_p != BRAIN_RES:
		paths.append(abs_p)
	for path in paths:
		var f := FileAccess.open(str(path), FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			last_save_paths.append(str(path))
			any = true
	last_save_ok = any
	return any


func load_brain() -> bool:
	for path in [BRAIN_USER, BRAIN_RES, ProjectSettings.globalize_path(BRAIN_RES)]:
		if str(path) == "" or not FileAccess.file_exists(str(path)):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var doc: Dictionary = raw
		games_played = int(doc.get("games_played", 0))
		if doc.has("wins"):
			wins = doc["wins"]
		if doc.has("losses"):
			losses = doc["losses"]
		learning_rate = float(doc.get("learning_rate", learning_rate))
		epsilon = float(doc.get("epsilon", epsilon))
		if doc.has("weights"):
			weights = doc["weights"]
		_ensure_weights()
		_recompute_norm()
		return true
	return false


func status_text() -> String:
	return "AI g=%d ε=%.2f |w|=%.2f  session %d (E%d C%d)  last=%s  files=%s" % [
		games_played, _explore(), weight_norm, session_games,
		int(session_wins.get("egypt", 0)), int(session_wins.get("canaan", 0)),
		last_winner if last_winner != "" else "—",
		"ok" if last_save_ok else "paste-only",
	]


func reset_brain() -> void:
	weights.clear()
	games_played = 0
	wins = {"egypt": 0, "canaan": 0}
	losses = {"egypt": 0, "canaan": 0}
	reset_session()
	_traces = {"egypt": [], "canaan": []}
	_ensure_weights()
	_recompute_norm()
	save_brain()
	last_export_text = export_text()
