extends SceneTree
func _init():
	call_deferred("r")
func r():
	var Learning = load("res://scripts/learning_ai.gd")
	var ai = Learning.new()
	var f = FileAccess.open("res://data/megiddo_ai_brain.json", FileAccess.READ)
	var ok = ai.import_text(f.get_as_text() if f else "")
	print("import_ok=", ok, " games=", ai.games_played, " chariot_bias=", ai.weights.get("chariot_strike", {}).get("bias", 0))
	# triple paste simulation
	var trip = ai.export_text() + ai.export_text() + ai.export_text()
	var ai2 = Learning.new()
	var ok2 = ai2.import_text(trip)
	print("triple_ok=", ok2, " games=", ai2.games_played)
	quit(0 if ok and ok2 else 1)
