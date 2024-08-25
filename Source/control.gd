extends Control

@onready var audio_steam_player = $AudioStreamPlayer
@onready var sample_hz = $AudioStreamPlayer.stream.mix_rate

@export_category("Engine")
@export var cylinders: int = 4## amount of cylinders the engine has
@export var strokes: int = 4## amount of strokes the engine has

@export_category("Sound Characteristics")
@export_range(0.0, 1.0) var duty_cycle: float = 0.3 ## Changes how long the enigne pulses are. Lower numbers result in shorter pulses.
@export_range(0.1, 1.0) var full_pulse_wave_percent: float = 0.4 ## Deprecated. The percent of the RPM range where the crossfade becomes purely the pulse wave
@export var wave_quality: int = 10 ## Higher numbers result in poor performance.
@export var starting_volume_percent: float = 0.1 ## Volume of engine sound at idle

var cutoff_frequency: float = 15000

var max_rpm: float = 7000.0
var idle_rpm: float = 700.0
var rpm: float = 0.0
var pulse_hz: float = 0.0
var phase: float = 0.0
var playback: AudioStreamPlayback = null # Actual playback stream, assigned in _ready().
var previous_white_noise: float = 0.0
var previous_engine_noise: float = 0.0

func _fill_buffer() -> void:
	var increment: float = pulse_hz / sample_hz
	
	var buffer: Array = [] # sound buffer for raw engine sound
	var allpass_output: Array = []
	
	var dn1: float = 0 # allpass buffer, WolfSound didn't explain the name so I don't know what it means
	
	var to_fill: int = playback.get_frames_available()
	while to_fill > 0:
		#    saw wave crossfade not currently in use
		#var saw_wave: float = 0.0
		#for i in range(1, wave_quality):
			#saw_wave += pow(-1, i) * (sin(TAU * phase * i) / i) # Create the saw wave with "wave_quality" amount of iterations.
		#
		#saw_wave = saw_wave * (2/PI) * 0.7 # Amplitude correction of the saw wave; 0.7 is a volume adjustment to create a seamless crossfade.
		
		var pulse_wave: float = 0.0
		for i in range(1, wave_quality):
			pulse_wave += (1/i) * sin(PI * i * duty_cycle) * cos(TAU * i * phase) # Create the pulse wave with "wave_quality" amount of iterations.
		
		pulse_wave = pulse_wave * (4/PI) + (2*duty_cycle) - 1 # Amplitude and displacement correction of the pulse wave.
		
		var white_noise: float = randf() # Generate white noise.
		var low_pass_noise: float = (white_noise + previous_white_noise) / 2 # Simple low pass filter of the white noise.
		previous_white_noise = white_noise # White noise buffer used in the low pass filter.
		
		var volume: float = (rpm * ((1 - starting_volume_percent) / max_rpm)) + starting_volume_percent # increase volume with RPM
		var engine_sound: float = max(0, pulse_wave) * white_noise # Apply pulse to the white noise.
		
		var cutoff_percent: float = (rpm - idle_rpm + 700)/(max_rpm - idle_rpm) # 700 is a number where it seems to work, no idea why
		cutoff_frequency = 17000 * cutoff_percent # 17000 is aribitrary value to "turn off" the filter
		
		#    crossfade not currently in use
		#var crossfade_percent: float = min((rpm - idle_rpm)/(max_rpm - idle_rpm) * (1.0/full_pulse_wave_percent), 1.0)
		#var crossfade: float = (saw_wave * (1 - crossfade_percent)) + (engine_sound * crossfade_percent)
		
		buffer.push_back(engine_sound * volume) # sound buffer for post-processing
		
		phase = fmod(phase + increment, 1.0)
		to_fill -= 1
	
	for i in range(buffer.size()): # acts as muffler -- allpass filter broken into multiple variables
		var tan_calc: float = tan(PI * cutoff_frequency / 40939)# buffer.size() / buffer_length ~ sample_rate / duration_in_samples
																# only works at start when the buffer is 4x size
																# 40939 ~ (buffer.size() * 4) / buffer_length
																# no clue ???
		var a1: float = (tan_calc - 1) / (tan_calc + 1)
		allpass_output.push_back(a1 * buffer[i] + dn1)
		dn1 = buffer[i] - a1 * allpass_output[i]
	
	for n in range(allpass_output.size()): # turns allpass filter into lowpass filter
		var final_output: float = buffer[n] + allpass_output[n] # lowpass fase cancellation
		final_output *= 0.5 # reduce amplitude after phase combination
		playback.push_frame(Vector2.ONE * final_output)
		#playback.push_frame(Vector2.ONE * buffer[n]) # output withhout lowpass filter

func _process(_delta) -> void:
	_fill_buffer()

func _ready() -> void:
	set_rpm($HSlider.value)
	# Setting mix rate is only possible before play().
	audio_steam_player.stream.mix_rate = sample_hz
	audio_steam_player.play()
	playback = audio_steam_player.get_stream_playback()
	# `_fill_buffer` must be called *after* setting `playback`,
	# as `fill_buffer` uses the `playback` member variable.
	_fill_buffer()

func set_rpm(new_rpm: float) -> void:
	pulse_hz = new_rpm/60.0 # RPM to hertz conversion.
	pulse_hz *= cylinders / (strokes / 2.0) # Multiply revolutions by combustions per revolution.

func _on_h_slider_value_changed(value) -> void:
	rpm = float(value)
	set_rpm(rpm)
	$Label.text = "rpm: " + str(rpm)
