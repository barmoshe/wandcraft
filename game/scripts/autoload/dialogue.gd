extends Node
## Dialogue: the voices (research/voices-plan.md): the Duck and LINT speak real words, rendered offline
## with Kokoro-82M (tools/voices.sh) into game/assets/voice/<id>.wav. Story.say puts lines on
## Events.say; this queues them and plays one at a time, and the HUD shows each as it starts
## (line_started), so the text doubles as subtitles. A line without a file (or with VOICE off)
## is shown for its reading time instead. The music dips under speech through Audio.voice_db
## (bus volume works in the web build's sample mode; bus effects don't).

signal line_started(who: String, text: String, id: String, dur: float)

const DIR := "res://assets/voice/"
const STALE := 6.0      # a line waiting longer than this is dropped, not played late
const GAP := 0.35       # a breath between lines
const DIP_DB := -6.0    # the music under speech
const MAX_QUEUE := 6    # 0.21: a resident's whole beat fits

var _queue: Array = []
var _busy := 0.0
var _player: AudioStreamPlayer
var _dip := 0.0
var current := {}        # the line playing or showing: {who, text, id}
var last_started := ""   # 0.22: the id of the last line that began (a resident's beat counts once heard)
signal line_cut          # 0.22: the line showing was cut short (a walk-away, a new screen)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Voice")
		AudioServer.set_bus_send(i, "Master")
	_player = AudioStreamPlayer.new()
	_player.bus = "Voice"
	add_child(_player)
	Events.say.connect(enqueue)


static func path(id: String) -> String:
	return DIR + Story.file_id(id) + ".wav"


static func stream(id: String) -> AudioStream:
	var p := path(id)
	return load(p) if ResourceLoader.exists(p) else null


## How long a line stays up with no audio (0.21, speech bubbles): the typewriter at 30
## characters a second, then time to read it at 15 (at least 1.5 s), and half a second more.
static func read_time(text: String) -> float:
	var n := text.length()
	return n / 30.0 + maxf(1.5, n / 15.0) + 0.5


func enqueue(who: String, text: String, id: String) -> void:
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append({"who": who, "text": text, "id": id, "t": _now()})


## Forgets waiting lines whose id starts with `prefix`, and cuts the current one short if it
## is one of them (you walked away from a resident mid-talk).
func drop_prefix(prefix: String) -> void:
	_queue = _queue.filter(func(l: Dictionary) -> bool: return not String(l["id"]).begins_with(prefix))
	if String(current.get("id", "")).begins_with(prefix):
		if _player:
			_player.stop()
		_busy = minf(_busy, GAP)
		current = {}
		line_cut.emit()


## The exchange a line belongs to: its id without the last part ("res.grep.arc.0").
static func group(id: String) -> String:
	var cut := id.rfind(".")
	return id.substr(0, cut) if cut > 0 else id


## Stops the voice and forgets what was waiting (a new screen, a new run).
func clear() -> void:
	_queue.clear()
	if _player:
		_player.stop()
	_busy = 0.0
	if not current.is_empty():
		line_cut.emit()
	current = {}


## Plays a line now, over whatever was playing (the story panels). Returns how long it runs.
func play_now(id: String, who := "", text := "") -> float:
	clear()
	return _start({"who": who, "text": text, "id": id})


func busy() -> bool:
	return _busy > 0.0 or not _queue.is_empty()


func _can_play() -> bool:
	return Game.voice and Game.sound and Game.quiet == 0


func _start(l: Dictionary) -> float:
	var dur := read_time(l["text"])
	var st: AudioStream = stream(l["id"]) if _can_play() else null
	if st:
		_player.stream = st
		_player.pitch_scale = randf_range(0.99, 1.01)
		_player.play()
		dur = st.get_length() + 0.1
	current = l
	last_started = String(l.get("id", ""))
	_busy = dur + GAP
	# 0.21: the rest of an exchange waits on this line, so it doesn't go stale behind it
	var g := group(String(l["id"]))
	if g != "":
		for q in _queue:
			if group(String(q["id"])) == g:
				q["t"] = _now() + dur
	line_started.emit(l["who"], l["text"], l["id"], dur)
	return dur


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(dt: float) -> void:
	_busy = maxf(0.0, _busy - dt)
	if _busy <= 0.0:
		current = {}
		while not _queue.is_empty():
			var l: Dictionary = _queue.pop_front()
			if _now() - float(l["t"]) <= STALE:
				_start(l)
				break
	# the music makes room while a line plays: 6 dB down, back over about 150 ms
	var want := DIP_DB if _player and _player.playing else 0.0
	_dip = move_toward(_dip, want, dt * 40.0)
	var au := get_node_or_null("/root/Audio")
	if au and "voice_db" in au:
		au.voice_db = _dip
