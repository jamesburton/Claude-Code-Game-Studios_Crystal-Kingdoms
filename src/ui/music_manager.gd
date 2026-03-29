## Background music manager using procedural audio.
## Generates ambient/melodic loops — no external audio files needed.
class_name MusicManager
extends Node

var _player: AudioStreamPlayer
var _enabled: bool = true
var _volume: float = 0.3

const SAMPLE_RATE := 22050

## Chord progressions for menu and gameplay.
const MENU_CHORDS: Array[Array] = [
	[261.6, 329.6, 392.0],  # C major
	[220.0, 277.2, 329.6],  # A minor
	[246.9, 311.1, 370.0],  # B dim-ish
	[196.0, 246.9, 293.7],  # G major
]

const GAME_CHORDS_SET: Array[Array] = [
	[  # Variation 1: D minor progression
		[293.7, 370.0, 440.0],
		[261.6, 329.6, 392.0],
		[220.0, 277.2, 329.6],
		[246.9, 311.1, 370.0],
	],
	[  # Variation 2: E minor progression
		[329.6, 392.0, 493.9],
		[293.7, 370.0, 440.0],
		[261.6, 329.6, 392.0],
		[349.2, 440.0, 523.3],
	],
	[  # Variation 3: A minor moody
		[220.0, 261.6, 329.6],
		[196.0, 246.9, 293.7],
		[174.6, 220.0, 261.6],
		[196.0, 246.9, 293.7],
	],
]


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = linear_to_db(_volume * 0.4)
	add_child(_player)


func play_menu_music() -> void:
	if not _enabled:
		return
	_player.stream = _generate_ambient(MENU_CHORDS, 16.0)
	_player.play()


func play_game_music() -> void:
	if not _enabled:
		return
	var variation: Array = GAME_CHORDS_SET[randi() % GAME_CHORDS_SET.size()]
	_player.stream = _generate_ambient(variation, 16.0)
	_player.play()


func stop() -> void:
	_player.stop()


func set_volume(vol: float) -> void:
	_volume = vol
	_player.volume_db = linear_to_db(vol * 0.4)


func set_enabled(val: bool) -> void:
	_enabled = val
	if not val:
		stop()


func _generate_ambient(chords: Array[Array], duration: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var chord_len := samples / chords.size()

	for i in range(samples):
		var chord_idx := mini(i / chord_len, chords.size() - 1)
		var chord: Array = chords[chord_idx]
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0

		# Soft pad: mix sine waves with slow attack/release
		for freq: float in chord:
			sample += sin(TAU * freq * t) * 0.15
			sample += sin(TAU * freq * 0.5 * t) * 0.08  # sub octave

		# Gentle arpeggio on top
		var arp_idx := (i / (SAMPLE_RATE / 4)) % chord.size()
		var arp_freq: float = chord[arp_idx] * 2.0
		sample += sin(TAU * arp_freq * t) * 0.06 * (0.5 + 0.5 * sin(t * 3.0))

		# Envelope for chord transitions
		var pos_in_chord := float(i % chord_len) / chord_len
		var env := minf(pos_in_chord * 10.0, 1.0) * minf((1.0 - pos_in_chord) * 10.0, 1.0)
		sample *= env * _volume

		var s16 := clampi(int(sample * 32767), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	stream.data = data
	return stream
