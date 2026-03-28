## Simple sound effects manager for Crystal Kingdoms.
## Uses procedural audio (sine wave beeps) — no external audio files needed.
class_name SoundManager
extends Node

var _players: Array[AudioStreamPlayer] = []
var _enabled: bool = true

const SAMPLE_RATE := 22050
const MAX_PLAYERS := 4


func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


## Play a sound effect by name.
func play(sfx_name: String) -> void:
	if not _enabled:
		return
	match sfx_name:
		"cursor_spawn":
			_play_tone(880.0, 0.08, 0.3)
		"capture_empty":
			_play_tone(523.0, 0.12, 0.5)
		"contagion":
			_play_tone(330.0, 0.06, 0.3)
		"capture_contagion":
			_play_two_tone(660.0, 880.0, 0.15, 0.6)
		"destroy":
			_play_tone(220.0, 0.15, 0.4)
		"chain_step":
			_play_tone(440.0, 0.04, 0.2)
		"match_end":
			_play_two_tone(523.0, 784.0, 0.3, 0.7)


func set_enabled(val: bool) -> void:
	_enabled = val


func _play_tone(freq: float, duration: float, volume: float) -> void:
	var player := _get_free_player()
	if player == null:
		return
	player.stream = _generate_tone(freq, duration, volume)
	player.play()


func _play_two_tone(freq1: float, freq2: float, duration: float, volume: float) -> void:
	var player := _get_free_player()
	if player == null:
		return
	player.stream = _generate_two_tone(freq1, freq2, duration, volume)
	player.play()


func _get_free_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			return p
	return _players[0]  # Fallback: reuse first


func _generate_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)  # 16-bit mono

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / samples)  # Linear fade out
		var sample := sin(TAU * freq * t) * volume * envelope
		var s16 := clampi(int(sample * 32767), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream


func _generate_two_tone(freq1: float, freq2: float, duration: float, volume: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var half := samples / 2
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / samples)
		var freq := freq1 if i < half else freq2
		var sample := sin(TAU * freq * t) * volume * envelope
		var s16 := clampi(int(sample * 32767), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
