class_name MegiddoHUD
extends CanvasLayer
## Egyptian-styled touch HUD.

signal cmd_attack_move
signal cmd_hold
signal cmd_stop
signal cmd_select_all
signal cmd_pause
signal cmd_resume
signal start_pressed
signal selfplay_toggled
signal brain_apply(text: String)
signal brain_reset
signal new_battle

var title_label: Label
var brief_label: Label
var log_label: RichTextLabel
var strength_label: Label
var select_label: Label
var hold_bar: ProgressBar
var time_label: Label
var victory_panel: PanelContainer
var victory_label: Label
var briefing_panel: PanelContainer
var btn_pause: Button
var btn_selfplay: Button
var brain_panel: PanelContainer
var brain_edit: TextEdit
var ai_status_label: Label
var btn_new_battle: Button

var _log_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	layer = 20
	_build()


func _build() -> void:
	# top banner
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_bottom = 72
	top.offset_left = 0
	top.offset_right = 0
	add_child(top)
	var top_bg := StyleBoxFlat.new()
	top_bg.bg_color = Color(0.12, 0.18, 0.28, 0.92)
	top_bg.border_color = Color(0.85, 0.7, 0.25)
	top_bg.set_border_width_all(2)
	top.add_theme_stylebox_override("panel", top_bg)
	var top_m := MarginContainer.new()
	top_m.add_theme_constant_override("margin_left", 16)
	top_m.add_theme_constant_override("margin_right", 16)
	top_m.add_theme_constant_override("margin_top", 8)
	top_m.add_theme_constant_override("margin_bottom", 8)
	top.add_child(top_m)
	var top_v := VBoxContainer.new()
	top_m.add_child(top_v)
	title_label = Label.new()
	title_label.text = "BATTLE OF MEGIDDO  ·  c. 1457 BCE"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	top_v.add_child(title_label)
	brief_label = Label.new()
	brief_label.text = "Egypt (lapis·gold) vs Canaan (crimson·bronze)  ·  M music"
	brief_label.add_theme_font_size_override("font_size", 14)
	brief_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	top_v.add_child(brief_label)

	# strength
	strength_label = Label.new()
	strength_label.anchor_left = 1.0
	strength_label.anchor_right = 1.0
	strength_label.offset_left = -320
	strength_label.offset_right = -16
	strength_label.offset_top = 80
	strength_label.offset_bottom = 140
	strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strength_label.add_theme_font_size_override("font_size", 15)
	strength_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	add_child(strength_label)

	time_label = Label.new()
	time_label.offset_left = 16
	time_label.offset_top = 80
	time_label.offset_right = 280
	time_label.offset_bottom = 110
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	add_child(time_label)

	# hold bar
	var hold_box := VBoxContainer.new()
	hold_box.anchor_left = 0.5
	hold_box.anchor_right = 0.5
	hold_box.offset_left = -160
	hold_box.offset_right = 160
	hold_box.offset_top = 78
	hold_box.offset_bottom = 120
	add_child(hold_box)
	var hl := Label.new()
	hl.text = "MEGIDDO CONTROL"
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.add_theme_font_size_override("font_size", 12)
	hl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	hold_box.add_child(hl)
	hold_bar = ProgressBar.new()
	hold_bar.max_value = 1.0
	hold_bar.value = 0.0
	hold_bar.show_percentage = false
	hold_bar.custom_minimum_size = Vector2(320, 16)
	hold_box.add_child(hold_bar)

	# bottom command bar
	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -110
	bottom.offset_bottom = 0
	add_child(bottom)
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	bstyle.border_color = Color(0.75, 0.6, 0.2)
	bstyle.set_border_width_all(2)
	bottom.add_theme_stylebox_override("panel", bstyle)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 12)
	bm.add_theme_constant_override("margin_right", 12)
	bm.add_theme_constant_override("margin_top", 10)
	bm.add_theme_constant_override("margin_bottom", 10)
	bottom.add_child(bm)
	var bv := VBoxContainer.new()
	bm.add_child(bv)
	select_label = Label.new()
	select_label.text = "Tap unit to select · Tap ground to march · Tap enemy to attack"
	select_label.add_theme_font_size_override("font_size", 13)
	select_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	bv.add_child(select_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bv.add_child(row)
	_add_cmd(row, "⚔ ATTACK-MOVE", func(): cmd_attack_move.emit())
	_add_cmd(row, "🛡 HOLD", func(): cmd_hold.emit())
	_add_cmd(row, "■ STOP", func(): cmd_stop.emit())
	_add_cmd(row, "◎ ALL", func(): cmd_select_all.emit())
	btn_pause = _add_cmd(row, "❚❚ PAUSE", func(): cmd_pause.emit())
	btn_selfplay = _add_cmd(row, "▶ SELF-PLAY", func(): selfplay_toggled.emit())
	_add_cmd(row, "🧠 BRAIN", func(): _toggle_brain())
	btn_new_battle = _add_cmd(row, "↺ NEW", func(): new_battle.emit())

	# log
	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 0.0
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 12
	log_panel.offset_right = 380
	log_panel.offset_top = -280
	log_panel.offset_bottom = -120
	add_child(log_panel)
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(0.95, 0.9, 0.75, 0.88)
	ls.set_corner_radius_all(4)
	log_panel.add_theme_stylebox_override("panel", ls)
	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 8)
	lm.add_theme_constant_override("margin_right", 8)
	lm.add_theme_constant_override("margin_top", 6)
	lm.add_theme_constant_override("margin_bottom", 6)
	log_panel.add_child(lm)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(350, 140)
	log_label.add_theme_color_override("default_color", Color(0.15, 0.1, 0.05))
	lm.add_child(log_label)

	# briefing overlay
	briefing_panel = PanelContainer.new()
	briefing_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(briefing_panel)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.08, 0.1, 0.14, 0.82)
	briefing_panel.add_theme_stylebox_override("panel", bs)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	briefing_panel.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 360)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.93, 0.86, 0.65)
	cs.border_color = Color(0.55, 0.35, 0.1)
	cs.set_border_width_all(3)
	cs.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 24)
	cm.add_theme_constant_override("margin_right", 24)
	cm.add_theme_constant_override("margin_top", 20)
	cm.add_theme_constant_override("margin_bottom", 20)
	card.add_child(cm)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	cm.add_child(cv)
	var t := Label.new()
	t.text = "YEAR 23 OF THUTMOSE III"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(0.35, 0.15, 0.05))
	cv.add_child(t)
	var t2 := Label.new()
	t2.text = "THE BATTLE OF MEGIDDO"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 26)
	t2.add_theme_color_override("font_color", Color(0.45, 0.2, 0.05))
	cv.add_child(t2)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Pharaoh rejected the easy roads. Through the narrow Aruna pass the army of Egypt pours onto the plain. The kings of Canaan wait before the walls of Megiddo.\n\nCommand the host: chariots, archers, and spearmen. Shatter the coalition and seize the fortress approaches."
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	cv.add_child(body)
	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "Touch: tap select · tap ground move · tap enemy attack · pinch zoom · drag pan\nDesktop: same with mouse · WASD pan · wheel zoom · RMB orbit"
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1))
	cv.add_child(tip)
	var start_btn := Button.new()
	start_btn.text = "BEGIN THE BATTLE"
	start_btn.custom_minimum_size = Vector2(0, 48)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(func():
		briefing_panel.visible = false
		start_pressed.emit()
	)
	cv.add_child(start_btn)

	# victory
	victory_panel = PanelContainer.new()
	victory_panel.visible = false
	victory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(victory_panel)
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color(0.05, 0.06, 0.08, 0.75)
	victory_panel.add_theme_stylebox_override("panel", vs)
	var vc := CenterContainer.new()
	vc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_panel.add_child(vc)
	var vcard := PanelContainer.new()
	vcard.custom_minimum_size = Vector2(480, 200)
	var vcs := StyleBoxFlat.new()
	vcs.bg_color = Color(0.95, 0.88, 0.6)
	vcs.border_color = Color(0.7, 0.5, 0.15)
	vcs.set_border_width_all(3)
	vcard.add_theme_stylebox_override("panel", vcs)
	vc.add_child(vcard)
	var vm := MarginContainer.new()
	vm.add_theme_constant_override("margin_left", 20)
	vm.add_theme_constant_override("margin_right", 20)
	vm.add_theme_constant_override("margin_top", 16)
	vm.add_theme_constant_override("margin_bottom", 16)
	vcard.add_child(vm)
	var vv := VBoxContainer.new()
	vm.add_child(vv)
	victory_label = Label.new()
	victory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.add_theme_font_size_override("font_size", 20)
	victory_label.add_theme_color_override("font_color", Color(0.25, 0.12, 0.05))
	vv.add_child(victory_label)
	var vbtn := Button.new()
	vbtn.text = "NEW BATTLE / CONTINUE"
	vbtn.pressed.connect(func():
		victory_panel.visible = false
		new_battle.emit()
	)
	vv.add_child(vbtn)

	# AI status strip
	ai_status_label = Label.new()
	ai_status_label.anchor_left = 1.0
	ai_status_label.anchor_right = 1.0
	ai_status_label.offset_left = -420
	ai_status_label.offset_right = -16
	ai_status_label.offset_top = 145
	ai_status_label.offset_bottom = 200
	ai_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ai_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_status_label.add_theme_font_size_override("font_size", 12)
	ai_status_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.75))
	ai_status_label.text = "AI brain: idle"
	add_child(ai_status_label)

	# Brain paste panel
	brain_panel = PanelContainer.new()
	brain_panel.visible = false
	brain_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brain_panel.offset_left = 40
	brain_panel.offset_right = -40
	brain_panel.offset_top = 40
	brain_panel.offset_bottom = -40
	brain_panel.z_index = 40
	add_child(brain_panel)
	var bps := StyleBoxFlat.new()
	bps.bg_color = Color(0.08, 0.1, 0.12, 0.95)
	bps.border_color = Color(0.85, 0.7, 0.25)
	bps.set_border_width_all(2)
	brain_panel.add_theme_stylebox_override("panel", bps)
	var bpm := MarginContainer.new()
	bpm.add_theme_constant_override("margin_left", 14)
	bpm.add_theme_constant_override("margin_right", 14)
	bpm.add_theme_constant_override("margin_top", 12)
	bpm.add_theme_constant_override("margin_bottom", 12)
	brain_panel.add_child(bpm)
	var bpv := VBoxContainer.new()
	bpv.add_theme_constant_override("separation", 8)
	bpm.add_child(bpv)
	var bpt := Label.new()
	bpt.text = "AI BRAIN — persist without files (web) or load from disk when available"
	bpt.add_theme_font_size_override("font_size", 16)
	bpt.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	bpv.add_child(bpt)
	var bph := Label.new()
	bph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bph.text = "1) After self-play wars, this box updates with the brain JSON.\n2) Click SELECT ALL then Ctrl+A / Ctrl+C (or Cmd+C) and paste into a note.\n3) Later: paste text here → APPLY PASTED BRAIN.\nDesktop also writes user:// and res://data when possible."
	bph.add_theme_font_size_override("font_size", 13)
	bph.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	bpv.add_child(bph)
	brain_edit = TextEdit.new()
	brain_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brain_edit.custom_minimum_size = Vector2(0, 320)
	brain_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	brain_edit.add_theme_font_size_override("font_size", 12)
	brain_edit.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	brain_edit.add_theme_color_override("background_color", Color(0.12, 0.14, 0.12))
	bpv.add_child(brain_edit)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	bpv.add_child(brow)
	_add_cmd(brow, "SELECT ALL", func(): _select_all_brain())
	_add_cmd(brow, "COPY", func(): _copy_brain())
	_add_cmd(brow, "APPLY PASTED BRAIN", func(): brain_apply.emit(brain_edit.text))
	_add_cmd(brow, "RESET BRAIN", func(): brain_reset.emit())
	_add_cmd(brow, "CLOSE", func(): brain_panel.visible = false)


func _toggle_brain() -> void:
	brain_panel.visible = not brain_panel.visible
	if brain_panel.visible:
		_select_all_brain()


func _select_all_brain() -> void:
	if brain_edit == null:
		return
	brain_edit.grab_focus()
	brain_edit.select_all()


func _copy_brain() -> void:
	if brain_edit == null:
		return
	DisplayServer.clipboard_set(brain_edit.text)
	push_log("Brain copied to clipboard (if browser allows).")


func set_brain_text(text: String) -> void:
	if brain_edit:
		brain_edit.text = text


func set_ai_status(text: String) -> void:
	if ai_status_label:
		ai_status_label.text = text


func set_selfplay_ui(active: bool) -> void:
	if btn_selfplay:
		btn_selfplay.text = "■ STOP AI" if active else "▶ SELF-PLAY"


func _add_cmd(row: HBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 44)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


func set_strength(egypt: float, canaan: float, en: int, cn: int) -> void:
	strength_label.text = "🇪🇬 EGYPT (blue·gold)  %d  (%.0f)\n🩸 CANAAN (crimson)  %d  (%.0f)" % [en, egypt, cn, canaan]


func set_selection(units: Array) -> void:
	if units.is_empty():
		select_label.text = "Nothing selected — tap a blue/gold Egyptian unit"
		return
	var kinds := {}
	for u in units:
		if not is_instance_valid(u):
			continue
		var k: String = u.kind
		kinds[k] = int(kinds.get(k, 0)) + 1
	var parts: PackedStringArray = PackedStringArray()
	for k2 in kinds:
		parts.append("%s×%d" % [k2, kinds[k2]])
	select_label.text = "Selected %d: %s" % [units.size(), ", ".join(parts)]


func push_log(text: String) -> void:
	_log_lines.append("• " + text)
	if _log_lines.size() > 40:
		_log_lines = _log_lines.slice(_log_lines.size() - 40)
	log_label.text = "[color=#2a1a0a]" + "\n".join(_log_lines) + "[/color]"


func set_hold(p: float) -> void:
	hold_bar.value = p


func set_time(seconds: float) -> void:
	var m: int = int(seconds) / 60
	var s: int = int(seconds) % 60
	time_label.text = "Day of battle  %02d:%02d" % [m, s]


func show_victory(side: String, reason: String) -> void:
	victory_panel.visible = true
	if side == "egypt":
		victory_label.text = "VICTORY OF EGYPT\n\n%s\n\nThutmose III holds the field of Megiddo." % reason
	else:
		victory_label.text = "DEFEAT\n\n%s\n\nThe kings of Canaan endure." % reason


func set_paused_ui(paused: bool) -> void:
	if btn_pause:
		btn_pause.text = "▶ RESUME" if paused else "❚❚ PAUSE"
