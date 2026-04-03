class_name EngineSound extends Node3D

@export var layers: Array[EngineSoundLayer]

var min_rpm: float
var max_rpm: float

func _ready() -> void:
	if layers.is_empty():
		push_warning("EngineSound (%s) has no layers defined!" % name)
		return

	# Sort layers by their RPM values (lower RPM first)
	layers.sort_custom(func(a, b): return a.rpm < b.rpm)

	# Find minimum and maximum RPM from the layers for later calculations
	min_rpm = layers[0].rpm
	max_rpm = layers[-1].rpm

	# Create an AudioStreamPlayer3D for each layer and add it as a child
	for layer in layers:
		var player := AudioStreamPlayer3D.new()
		player.name = "Layer %d" % layer.rpm
		player.stream = layer.stream
		player.autoplay = true
		player.volume_db = -80.0
		add_child(player)
		layer.player = player

var _jitter_time: float = 0.0

func set_current_rpm_factor(rpm_factor: float) -> void:
	if layers.is_empty(): return

	# Subtle RPM jitter so the sound is never perfectly static
	_jitter_time += get_process_delta_time() * 5.0
	var jitter = sin(_jitter_time * 3.7) * 0.01 + sin(_jitter_time * 7.1) * 0.008

	var rpm = min_rpm + clampf(rpm_factor + jitter, 0.0, 1.0) * (max_rpm - min_rpm)

	# Find which two layers we sit between
	var low_idx := 0
	for i in range(layers.size() - 1):
		if rpm >= layers[i].rpm:
			low_idx = i

	var high_idx := mini(low_idx + 1, layers.size() - 1)

	var low_rpm: float = layers[low_idx].rpm
	var high_rpm: float = layers[high_idx].rpm

	# Blend factor between the two nearest layers (0 = fully low, 1 = fully high)
	var blend := 0.0
	if high_rpm > low_rpm:
		blend = clampf((rpm - low_rpm) / (high_rpm - low_rpm), 0.0, 1.0)

	for i in range(layers.size()):
		var player: AudioStreamPlayer3D = layers[i].player
		var layer_rpm: float = layers[i].rpm

		# Only the two surrounding layers get volume; silence everything else
		var weight := 0.0
		if i == low_idx and i == high_idx:
			weight = 1.0
		elif i == low_idx:
			weight = 1.0 - blend
		elif i == high_idx:
			weight = blend

		# Convert linear weight to dB (-80 = silent, 0 = full)
		if weight > 0.001:
			player.volume_db = linear_to_db(weight)
		else:
			player.volume_db = -80.0

		# Pitch-shift each layer so its playback matches the current RPM
		player.pitch_scale = rpm / layer_rpm
