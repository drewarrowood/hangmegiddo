extends Node
## Ambient Egyptian loop + battle SFX + cry triggers.

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var sfx2: AudioStreamPlayer
var sfx3: AudioStreamPlayer

var _streams: Dictionary = {}
var _music_on: bool = true
var _cry_cd: float = 0.0

const EGYPT_CRIES := [
	"Nekht!", # strength / victory
	"Imi-r!", # forward / come along
	"Ankh!", # life
	"Heka!", # power
	"Seneb!", # health
	"Em-sekhem!", # in power
	"Netjer-aa!", # great god (war cry flavor)
	"Ha'a!", # rejoice / charge flavor
]
const CANAAN_CRIES := [
	"Baʿlu!", # Baal
	"Malku!", # king
	"Ṣabaʾ!", # army/host
	"Qudšu!", # holy
	"Naqam!", # vengeance flavor
	"ʿIzzi!", # my strength
	"Haya!", # live!
	"Rkb-ʿrpt!", # rider of clouds (Baal epithet, short shout)
]


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	music.volume_db = -14.0
	add_child(music)
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -6.0
	add_child(sfx)
	sfx2 = AudioStreamPlayer.new()
	sfx2.volume_db = -8.0
	add_child(sfx2)
	sfx3 = AudioStreamPlayer.new()
	sfx3.volume_db = -10.0
	add_child(sfx3)
	_load_all()
	start_music()


func _process(delta: float) -> void:
	_cry_cd = maxf(0.0, _cry_cd - delta)


func _load_all() -> void:
	for name in [
		"ambient_egypt", "sfx_horse", "sfx_wheels", "sfx_bow",
		"sfx_grunt", "sfx_scream", "sfx_clash", "sfx_ui", "sfx_victory"
	]:
		var path := "res://audio/%s.wav" % name
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var st = load(path)
			if st:
				_streams[name] = st
				if st is AudioStreamWAV:
					# one-shots shouldn't loop; ambient handled in start_music
					pass


func start_music() -> void:
	if not _music_on:
		return
	var st: AudioStream = _streams.get("ambient_egypt")
	if st == null:
		return
	if st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream = st
	if not music.playing:
		music.play()


func toggle_music() -> void:
	_music_on = not _music_on
	if _music_on:
		start_music()
	else:
		music.stop()


func play_sfx(name: String, pitch_var: float = 0.08) -> void:
	var st: AudioStream = _streams.get(name)
	if st == null:
		return
	var p: AudioStreamPlayer = sfx
	if sfx.playing:
		p = sfx2 if not sfx2.playing else sfx3
	p.stream = st
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func play_attack(kind: String) -> void:
	match kind:
		"archer":
			play_sfx("sfx_bow", 0.12)
		"chariot":
			play_sfx("sfx_wheels", 0.1)
			if randf() < 0.55:
				play_sfx("sfx_horse", 0.15)
		_:
			play_sfx("sfx_clash", 0.12)
			if randf() < 0.5:
				play_sfx("sfx_grunt", 0.2)


func play_death() -> void:
	if randf() < 0.55:
		play_sfx("sfx_scream", 0.18)
	else:
		play_sfx("sfx_grunt", 0.2)


func play_victory() -> void:
	play_sfx("sfx_victory", 0.0)


func play_ui() -> void:
	play_sfx("sfx_ui", 0.05)


func random_cry(side: String) -> String:
	if _cry_cd > 0.0 and randf() > 0.35:
		return ""
	_cry_cd = randf_range(0.35, 0.9)
	var list: Array = EGYPT_CRIES if side == "egypt" else CANAAN_CRIES
	return str(list[randi() % list.size()])
