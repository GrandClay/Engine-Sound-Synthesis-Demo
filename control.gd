extends Control

var rpm: float = 0.0

@export_category("Engine")

@export var cylinders: int = 4
@export var strokes: int = 4

@export_category("Sound Characteristics")
@export_range(0.0, 1.0) var duty_cycle: float = 0.35

@onready var audio_steam_player = $AudioStreamPlayer
@onready var sample_hz = $AudioStreamPlayer.stream.mix_rate

var pulse_hz: float = rpm/60.0
var phase: float = 0.0
var playback: AudioStreamPlayback = null # Actual playback stream, assigned in _ready().
var previous_white_noise: float = 0.0

func _fill_buffer():
	var increment: float = pulse_hz / sample_hz

	var to_fill = playback.get_frames_available()
	while to_fill > 0:
		var pulse_wave: float = 0.0
		for i in range(1, 10):
			pulse_wave += (1/i) * sin(PI * i * duty_cycle) * cos(TAU * i * phase) # summation of pulse wave
		
		pulse_wave = pulse_wave * (4/PI) + (2*duty_cycle) - 1 # amplitude and displacement correction
		
		var white_noise: float = randf() # generate white noise
		var low_pass_noise: float = (white_noise + previous_white_noise) / 2 # make average pitch of white noise lowwer
		previous_white_noise = white_noise 
		
		var engine_sound: float = max(0, pulse_wave) * low_pass_noise # apply pulse to the white noise
		
		playback.push_frame(Vector2.ONE * engine_sound) # Audio frames are stereo.
		phase = fmod(phase + increment, 1.0)
		to_fill -= 1

	#while to_fill > 0:
		#var pulse_wave = 0
		#for i in range(20):
			#pulse_wave += (sin(TAU * (2 * i - 1) * phase)) / (2 * i - 1) # square wave
		#
		##wave += sin(TAU * phase)
		#var white_noise = randf()
		#var low_pass_noise = (white_noise + previous_white_noise) / 2
		#previous_white_noise = white_noise
		#
		#var engine_sound = max(pulse_wave, 0) * low_pass_noise
		#
		#playback.push_frame(Vector2.ONE * engine_sound) # Audio frames are stereo.
		#phase = fmod(phase + increment, 1.0)
		#to_fill -= 1


func _process(_delta):
	_fill_buffer()

func _ready():
	$HSlider.value = 700
	# Setting mix rate is only possible before play().
	audio_steam_player.stream.mix_rate = sample_hz
	audio_steam_player.play()
	playback = audio_steam_player.get_stream_playback()
	# `_fill_buffer` must be called *after* setting `playback`,
	# as `fill_buffer` uses the `playback` member variable.
	_fill_buffer()

func _on_h_slider_value_changed(value):
	rpm = float(value)
	pulse_hz = rpm/60.0 # RPM to hertz conversion
	pulse_hz *= cylinders / (strokes / 2.0) # multiply revolutions by combustions per revolution
	$Label.text = "rpm: " + str(rpm)
