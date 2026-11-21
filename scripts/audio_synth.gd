extends Node
class_name AudioSynth

# Realistic Physical-Noise Procedural Audio Engine + Godot AudioServer DSP Buses
# Uses multi-band filtered noise (1-pole LP/HP/BP) and realistic two-part micro-impacts
# (heel + sole for footsteps; latch click + heavy damped thud for fire doors) — ZERO cheesy sine beeps!

const SAMPLE_RATE = 22050
static var _buses_initialized: bool = false
static var _stream_cache: Dictionary = {}

static func setup_audio_buses() -> void:
	if _buses_initialized:
		return
	_buses_initialized = true
	
	# 1. "Stairwell" Bus: Concrete vertical shaft reverb
	if AudioServer.get_bus_index("Stairwell") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Stairwell")
		AudioServer.set_bus_send(idx, "Master")
		
		var rev = AudioEffectReverb.new()
		rev.room_size = 0.65
		rev.damping = 0.52
		rev.spread = 0.85
		rev.hipass = 0.18
		rev.dry = 0.88
		rev.wet = 0.30
		AudioServer.add_bus_effect(idx, rev)
	
	# 2. "Muffled" Bus: Low-pass filter + dark reverb for behind-the-door sounds
	if AudioServer.get_bus_index("Muffled") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Muffled")
		AudioServer.set_bus_send(idx, "Master")
		
		var lpf = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 920.0
		lpf.resonance = 0.45
		AudioServer.add_bus_effect(idx, lpf)
		
		var rev = AudioEffectReverb.new()
		rev.room_size = 0.50
		rev.damping = 0.75
		rev.dry = 0.82
		rev.wet = 0.25
		AudioServer.add_bus_effect(idx, rev)
	
	# 3. "Scare" Bus: Punchy PS1 overdrive for jumpscares
	if AudioServer.get_bus_index("Scare") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Scare")
		AudioServer.set_bus_send(idx, "Master")
		
		var dist = AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
		dist.drive = 0.38
		AudioServer.add_bus_effect(idx, dist)

static func create_player(parent: Node, stream: AudioStreamWAV, bus: String = "Master", volume_db: float = 0.0) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	parent.add_child(p)
	return p

static func create_player_3d(parent: Node3D, stream: AudioStreamWAV, unit_size: float = 6.0, max_dist: float = 20.0, bus: String = "Stairwell", volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var p = AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit_size
	p.max_distance = max_dist
	p.bus = bus
	p.volume_db = volume_db
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(p)
	return p

static func _get_or_make(key: String, builder: Callable) -> AudioStreamWAV:
	if _stream_cache.has(key):
		return _stream_cache[key]
	var wav = builder.call()
	_stream_cache[key] = wav
	return wav

static func _make_wav(data: PackedByteArray, looped: bool = false) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	wav.data = data
	return wav

static func make_ambient_building_drone() -> AudioStreamWAV:
	return _get_or_make("ambient_drone", func():
		var duration = 3.0
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 111
		var lp1 = 0.0
		var lp2 = 0.0
		for i in range(samples):
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.025)
			lp2 = lerp(lp2, lp1, 0.025)
			data.encode_s16(i * 2, int(clamp(lp2 * 1.4, -1.0, 1.0) * 7500.0))
		return _make_wav(data, true)
	)

static func make_relay_click() -> AudioStreamWAV:
	return _get_or_make("relay_click", func():
		# Crisp mechanical wall-relay switch click (filtered noise transients, no tonal ping)
		var duration = 0.09
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 1337
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.45)
			var hp = raw - lp
			var env = exp(-t * 160.0)
			if t > 0.022:
				env += exp(-(t - 0.022) * 210.0) * 0.65
			var val = clamp((hp * 0.75 + lp * 0.35) * env, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 24000.0))
		return _make_wav(data)
	)

static func make_fluorescent_hum() -> AudioStreamWAV:
	return _get_or_make("fluorescent_hum", func():
		var duration = 1.0
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 42
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var hum = sin(t * TAU * 60.0) * 0.30 + sin(t * TAU * 120.0) * 0.45 + sin(t * TAU * 180.0) * 0.14
			hum += rng.randf_range(-0.015, 0.015)
			data.encode_s16(i * 2, int(clamp(hum * 0.28, -1.0, 1.0) * 12000.0))
		return _make_wav(data, true)
	)

static func make_footstep() -> AudioStreamWAV:
	return _get_or_make("footstep_concrete_v2", func():
		# Crisp, dry human sneaker/shoe step on concrete (short ~95ms, soft heel roll + dry sole grit, zero metallic boom)
		var duration = 0.11
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 909
		var lp1 = 0.0
		var lp2 = 0.0
		var lp3 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.08)   # Soft muted shoe thud
			lp2 = lerp(lp2, raw, 0.34)   # Rubber sole tap
			lp3 = lerp(lp3, raw, 0.72)   # Dry concrete sand/grit friction
			var body = lp2 - lp1
			var grit = lp3 - lp2
			
			# Natural soft heel-to-toe roll envelope
			var heel = exp(-t * 85.0) * min(t / 0.008, 1.0)
			var sole = 0.0
			if t > 0.028:
				var dt = t - 0.028
				sole = exp(-dt * 68.0) * min(dt / 0.010, 1.0) * 0.78
			
			var sig = (lp1 * 0.75 + body * 0.95 + grit * 0.65) * heel + (lp1 * 0.35 + body * 0.85 + grit * 1.1) * sole
			data.encode_s16(i * 2, int(clamp(sig * 0.85, -1.0, 1.0) * 22000.0))
		return _make_wav(data)
	)

static func make_pursuer_single_step() -> AudioStreamWAV:
	return _get_or_make("pursuer_step_human_l", func():
		# Realistic heavy human dress-shoe / leather-boot step on concrete stairs
		# Dry, crisp heel tap + leather scuff, NO giant iron-hammer bass boom!
		var duration = 0.135
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 505
		var lp1 = 0.0
		var lp2 = 0.0
		var lp3 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.075)  # Controlled soft low thump
			lp2 = lerp(lp2, raw, 0.30)   # Hard leather heel tap
			lp3 = lerp(lp3, raw, 0.68)   # Concrete surface scuff
			var heel_body = lp2 - lp1
			var grit = lp3 - lp2
			
			# Distinct heel strike + slight forefoot roll 35ms later
			var heel_env = exp(-t * 62.0) * min(t / 0.006, 1.0)
			var toe_env = 0.0
			if t > 0.036:
				var dt = t - 0.036
				toe_env = exp(-dt * 54.0) * min(dt / 0.009, 1.0) * 0.72
			
			var sig = (lp1 * 0.95 + heel_body * 1.35 + grit * 0.70) * heel_env + (lp1 * 0.45 + heel_body * 0.95 + grit * 1.05) * toe_env
			data.encode_s16(i * 2, int(clamp(sig * 0.90, -1.0, 1.0) * 24500.0))
		return _make_wav(data)
	)

static func make_pursuer_step_alt() -> AudioStreamWAV:
	return _get_or_make("pursuer_step_human_r", func():
		# Subtle right-foot variation so walking up stairs sounds organically human (left-right cadence)
		var duration = 0.13
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 519
		var lp1 = 0.0
		var lp2 = 0.0
		var lp3 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.082)
			lp2 = lerp(lp2, raw, 0.33)
			lp3 = lerp(lp3, raw, 0.71)
			var heel_body = lp2 - lp1
			var grit = lp3 - lp2
			
			var heel_env = exp(-t * 66.0) * min(t / 0.007, 1.0)
			var toe_env = 0.0
			if t > 0.032:
				var dt = t - 0.032
				toe_env = exp(-dt * 58.0) * min(dt / 0.008, 1.0) * 0.75
			
			var sig = (lp1 * 0.88 + heel_body * 1.25 + grit * 0.78) * heel_env + (lp1 * 0.40 + heel_body * 0.90 + grit * 1.15) * toe_env
			data.encode_s16(i * 2, int(clamp(sig * 0.88, -1.0, 1.0) * 24000.0))
		return _make_wav(data)
	)

static func make_door_creak_and_latch() -> AudioStreamWAV:
	return _get_or_make("door_open_close_real", func():
		# Realistic heavy steel fire-door latch click + damped frame thump (NO sci-fi sine whistle!)
		var duration = 0.42
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 818
		var lp_low = 0.0
		var lp_mid = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp_low = lerp(lp_low, raw, 0.045)  # Heavy hollow steel door body thud
			lp_mid = lerp(lp_mid, raw, 0.35)   # Mechanical latch body
			var hi = raw - lp_mid              # Sharp metal latch spring click
			var mid = lp_mid - lp_low
			
			var val = 0.0
			# 1. Mechanical push-bar / latch click at t = 0.0
			var click1 = exp(-t * 140.0)
			val += (hi * 0.8 + mid * 0.7) * click1
			# 2. Second latch snap at t = 0.045s
			if t > 0.045:
				var dt2 = t - 0.045
				val += (hi * 0.6 + mid * 0.85) * exp(-dt2 * 120.0) * 0.75
			# 3. Heavy damped door frame thump at t = 0.11s
			if t > 0.11:
				var dt3 = t - 0.11
				var thud_env = exp(-dt3 * 22.0) * min(dt3 / 0.006, 1.0)
				val += (lp_low * 3.0 + mid * 0.75) * thud_env
			
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 28000.0))
		return _make_wav(data)
	)

static func make_distant_door_slam() -> AudioStreamWAV:
	return _get_or_make("distant_door_slam_real", func():
		# Massive, aggressive iron fire-door SLAM: pure low-passed air pressure boom + metal clatter
		var duration = 0.95
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 707
		var lp1 = 0.0
		var lp2 = 0.0
		var lp3 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.028)        # Deep pressure-wave boom
			lp2 = lerp(lp2, raw, 0.14)         # Heavy steel slab impact
			lp3 = lerp(lp3, raw, 0.48)         # Door frame / latch clatter
			var slab = lp2 - lp1
			var clatter = lp3 - lp2
			
			var boom_env = exp(-t * 7.5) * min(t / 0.004, 1.0)
			var clat_env = exp(-t * 32.0)
			# Tiny frame rebound clack at t = 0.075s
			var rebound = 0.0
			if t > 0.075:
				rebound = exp(-(t - 0.075) * 45.0) * 0.45
			
			var sig = lp1 * 3.6 * boom_env + slab * 1.4 * exp(-t * 15.0) + clatter * 0.9 * (clat_env + rebound)
			data.encode_s16(i * 2, int(clamp(sig, -1.0, 1.0) * 31500.0))
		return _make_wav(data)
	)

static func make_door_force_push() -> AudioStreamWAV:
	return _get_or_make("door_force_push_real", func():
		# Heavy body slamming/pushing against closed fire door + violent metallic latch rattle
		var duration = 0.72
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 848
		var lp_low = 0.0
		var lp_mid = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp_low = lerp(lp_low, raw, 0.035)
			lp_mid = lerp(lp_mid, raw, 0.32)
			var hi = raw - lp_mid
			var mid = lp_mid - lp_low
			
			var thump = (lp_low * 3.2 + mid * 1.0) * exp(-t * 14.0) * min(t / 0.005, 1.0)
			var rattle = 0.0
			for rt in [0.06, 0.14, 0.25, 0.38]:
				if t > rt:
					rattle += (hi * 0.7 + mid * 0.9) * exp(-(t - rt) * 85.0) * 0.55
			data.encode_s16(i * 2, int(clamp(thump + rattle, -1.0, 1.0) * 29500.0))
		return _make_wav(data)
	)

static func make_back_door_tok() -> AudioStreamWAV:
	return _get_or_make("back_door_tok_real", func():
		# Three slow, eerily calm hollow knuckle knocks: "tok... tok... tok..." (filtered noise)
		var duration = 1.45
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 333
		var lp1 = 0.0
		var lp2 = 0.0
		var knock_times = [0.05, 0.54, 1.02]
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.06)
			lp2 = lerp(lp2, raw, 0.26)
			var wood_body = lp2 - lp1
			var val = 0.0
			for kt in knock_times:
				if t >= kt:
					var dt = t - kt
					var env = exp(-dt * 48.0) * min(dt / 0.003, 1.0)
					val += (lp1 * 2.1 + wood_body * 1.45) * env
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 27000.0))
		return _make_wav(data)
	)

static func make_handle_turn() -> AudioStreamWAV:
	return _get_or_make("handle_turn_real", func():
		# Realistic metallic doorknob turning slowly + latch clicking against the strike plate
		var duration = 1.05
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 456
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.35)
			var hi = raw - lp
			var val = 0.0
			# Mechanical click-scrape as handle turns down
			for ct in [0.05, 0.22, 0.40, 0.68]:
				if t > ct:
					var dt = t - ct
					val += (hi * 0.85 + lp * 0.65) * exp(-dt * 95.0) * (0.9 if ct > 0.6 else 0.45)
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 26000.0))
		return _make_wav(data)
	)

static func make_locked_door_rattle() -> AudioStreamWAV:
	return _get_or_make("locked_rattle_real", func():
		# Dry double metallic push-bar clack when trying a locked fire door
		var duration = 0.28
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 612
		var lp_low = 0.0
		var lp_mid = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp_low = lerp(lp_low, raw, 0.08)
			lp_mid = lerp(lp_mid, raw, 0.42)
			var hi = raw - lp_mid
			var mid = lp_mid - lp_low
			var hit_t = t if t < 0.12 else (t - 0.12)
			var env = exp(-hit_t * 70.0) * min(hit_t / 0.003, 1.0)
			var val = clamp((lp_low * 1.4 + mid * 1.1 + hi * 0.7) * env, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 25000.0))
		return _make_wav(data)
	)

static func make_door_bang() -> AudioStreamWAV:
	return _get_or_make("door_bang_real", func():
		# Three heavy fists banging on steel fire door
		var duration = 0.82
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 666
		var lp1 = 0.0
		var lp2 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.035)
			lp2 = lerp(lp2, raw, 0.24)
			var mid = lp2 - lp1
			var val = 0.0
			for bt in [0.02, 0.24, 0.45]:
				if t >= bt:
					var dt = t - bt
					var env = exp(-dt * 18.0) * min(dt / 0.004, 1.0)
					val += (lp1 * 3.1 + mid * 1.2) * env
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 30500.0))
		return _make_wav(data)
	)

static func make_heavy_stair_steps() -> AudioStreamWAV:
	return _get_or_make("heavy_stair_steps_real", func():
		# 5 realistic concrete steps walking away down stairs (filtered noise, no beeps)
		var duration = 1.55
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 929
		var lp1 = 0.0
		var lp2 = 0.0
		var lp3 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.045)
			lp2 = lerp(lp2, raw, 0.22)
			lp3 = lerp(lp3, raw, 0.58)
			var mid = lp2 - lp1
			var grit = lp3 - lp2
			
			var period = 0.30
			var idx = floor(t / period)
			var st = fmod(t, period)
			var fade = clamp(1.0 - idx * 0.14, 0.25, 1.0)
			var env = exp(-st * 36.0) * min(st / 0.005, 1.0) * fade
			var toe = exp(-(st - 0.055) * 42.0) * 0.6 * fade if st > 0.055 else 0.0
			var sig = (lp1 * 2.5 + mid * 1.1 + grit * 0.5) * (env + toe)
			data.encode_s16(i * 2, int(clamp(sig, -1.0, 1.0) * 27000.0))
		return _make_wav(data)
	)

static func make_glass_tap() -> AudioStreamWAV:
	return _get_or_make("glass_tap_real", func():
		var duration = 0.42
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 444
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.55)
			var hi = raw - lp
			var tap_t = t if t < 0.16 else (t - 0.16)
			var env = exp(-tap_t * 95.0)
			var val = clamp((hi * 0.9 + sin(tap_t * TAU * 1450.0) * 0.22) * env, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 23000.0))
		return _make_wav(data)
	)

static func make_bulb_pop() -> AudioStreamWAV:
	return _get_or_make("bulb_pop", func():
		var duration = 0.24
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 212
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var pop = exp(-t * 65.0) * rng.randf_range(-1.0, 1.0)
			data.encode_s16(i * 2, int(clamp(pop, -1.0, 1.0) * 29000.0))
		return _make_wav(data)
	)

static func make_wake_pant() -> AudioStreamWAV:
	return _get_or_make("wake_pant", func():
		var duration = 2.1
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 609
		var lp = 0.0
		var bp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var cycle = fmod(t, 0.7) / 0.7
			var env = sin(cycle * PI) * (1.0 - t / duration * 0.45)
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.15)
			bp = lerp(bp, lp, 0.05)
			var breath = (lp - bp) * 2.4
			data.encode_s16(i * 2, int(clamp(breath * env * 0.65, -1.0, 1.0) * 22000.0))
		return _make_wav(data)
	)

static func make_whisper_breath() -> AudioStreamWAV:
	return _get_or_make("whisper_breath", func():
		var duration = 1.4
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 313
		var lp = 0.0
		var bp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var env = sin((t / duration) * PI)
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.18)
			bp = lerp(bp, lp, 0.06)
			var val = clamp((lp - bp) * 2.2 * env * 0.55, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 21000.0))
		return _make_wav(data)
	)

static func make_jumpscare_sting() -> AudioStreamWAV:
	return _get_or_make("jumpscare_sting", func():
		var duration = 1.05
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 777
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var env = exp(-t * 1.8)
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.08)
			var sub = lp * 2.5
			var saw1 = (fmod(t * 114.0, 1.0) * 2.0 - 1.0) * 0.30
			var saw2 = (fmod(t * 121.5, 1.0) * 2.0 - 1.0) * 0.30
			var stat = raw * 0.50 * exp(-t * 1.4)
			var val = clamp((sub + saw1 + saw2 + stat) * env, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 32000.0))
		return _make_wav(data)
	)

# =============================================================================
# AMBIENT SOUNDSCAPE (Rain outside windows, water drips, pipe settles, heartbeat)
# =============================================================================
static func make_night_rain_window() -> AudioStreamWAV:
	return _get_or_make("ambient_night_rain", func():
		# Soft, continuous muffled night rain & wind outside the stairwell windows (looped)
		var duration = 3.5
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 2048
		var lp_rain = 0.0
		var lp_wind = 0.0
		var hp_rain = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			# Soft rain hiss (band-passed noise)
			lp_rain = lerp(lp_rain, raw, 0.28)
			hp_rain = lerp(hp_rain, lp_rain, 0.08)
			var rain = (lp_rain - hp_rain) * 0.75
			# Slow rolling night wind swell (loop-seamless via TAU)
			lp_wind = lerp(lp_wind, raw, 0.03)
			var swell = 0.65 + 0.35 * sin((t / duration) * TAU)
			# Occasional tiny raindrop patters on glass
			var drop = 0.0
			if rng.randf() < 0.0018:
				drop = rng.randf_range(0.25, 0.55)
			var val = clamp((rain * 0.65 + lp_wind * 1.4 * swell + drop * 0.35) * 0.55, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 12500.0))
		return _make_wav(data, true)
	)

static func make_water_drip() -> AudioStreamWAV:
	return _get_or_make("ambient_water_drip", func():
		# Realistic hollow water droplet hitting wet concrete ("plip!") — quick upward pitch chirp
		var duration = 0.14
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var phase = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			# Natural bubble-pop upward frequency sweep (680Hz -> 1650Hz)
			var freq = 680.0 + (t / duration) * 980.0
			phase += TAU * freq / SAMPLE_RATE
			var env = exp(-t * 42.0) * min(t / 0.005, 1.0)
			var val = sin(phase) * env * 0.7
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 14000.0))
		return _make_wav(data)
	)

static func make_pipe_settle() -> AudioStreamWAV:
	return _get_or_make("ambient_pipe_settle", func():
		# Subtle old-building structural/pipe thermal settle far in the shaft (very organic, low-key)
		var duration = 0.85
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 4096
		var lp1 = 0.0
		var lp2 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.04)
			lp2 = lerp(lp2, raw, 0.16)
			var groan_env = sin((t / duration) * PI)
			var tick = exp(-abs(t - 0.18) * 90.0) * (raw - lp2) * 0.55
			var val = clamp((lp1 * 1.3 * groan_env + tick) * 0.5, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 14500.0))
		return _make_wav(data)
	)

static func make_heartbeat_thump() -> AudioStreamWAV:
	return _get_or_make("player_heartbeat", func():
		# Soft visceral double-beat "lub-dub" when Pursuer is dangerously close
		var duration = 0.72
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 8080
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			lp = lerp(lp, rng.randf_range(-1.0, 1.0), 0.03)
			var beat1 = exp(-t * 22.0) * sin(t * TAU * 48.0) * min(t / 0.015, 1.0)
			var beat2 = 0.0
			if t > 0.21:
				var dt = t - 0.21
				beat2 = exp(-dt * 26.0) * sin(dt * TAU * 44.0) * min(dt / 0.015, 1.0) * 0.72
			var val = clamp((beat1 + beat2) * 0.75 + lp * 0.25 * (abs(beat1) + abs(beat2)), -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 22000.0))
		return _make_wav(data)
	)

static func make_distant_thunder() -> AudioStreamWAV:
	return _get_or_make("ambient_distant_thunder", func():
		# Deep, rolling distant thunder rumble muffled through thick concrete walls
		var duration = 4.2
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 3030
		var lp1 = 0.0
		var lp2 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.022)
			lp2 = lerp(lp2, lp1, 0.028)
			# Natural double-roll thunder envelope (initial swell + secondary distant roll)
			var env = sin(clamp(t / 1.4, 0.0, 1.0) * PI * 0.5) * exp(-max(0.0, t - 0.85) * 0.85)
			var roll = 0.72 + 0.28 * sin(t * 3.8 + sin(t * 1.9))
			var val = clamp(lp2 * 4.2 * env * roll, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 24000.0))
		return _make_wav(data)
	)

static func make_elevator_machinery() -> AudioStreamWAV:
	return _get_or_make("ambient_elevator_machinery", func():
		# Distant old building elevator motor winding down + heavy steel cable groan + relay clunk
		var duration = 3.2
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 6060
		var lp = 0.0
		var phase = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.06)
			# Winding down motor pitch from 88Hz -> 44Hz over 2.4s
			var motor_env = clamp(1.0 - t / 2.5, 0.0, 1.0) * min(t / 0.25, 1.0)
			var freq = lerp(88.0, 44.0, clamp(t / 2.4, 0.0, 1.0))
			phase += TAU * freq / SAMPLE_RATE
			var motor = (sin(phase) * 0.5 + sin(phase * 2.0) * 0.25) * motor_env * 0.45
			# Heavy brake clunk at t = 2.45s
			var clunk = 0.0
			if t > 2.45:
				var dt = t - 2.45
				clunk = lp * 2.6 * exp(-dt * 14.0)
			var val = clamp(motor + lp * 0.65 * motor_env + clunk, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 19000.0))
		return _make_wav(data)
	)

static func make_sprint_breath() -> AudioStreamWAV:
	return _get_or_make("player_sprint_breath", func():
		# Soft, tired single human exhale after running up/down stairs
		var duration = 0.68
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 711
		var lp = 0.0
		var bp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.14)
			bp = lerp(bp, lp, 0.05)
			var env = sin((t / duration) * PI)
			var breath = (lp - bp) * 2.3 * env * 0.55
			data.encode_s16(i * 2, int(clamp(breath, -1.0, 1.0) * 18000.0))
		return _make_wav(data)
	)

static func make_darkness_pressure_hum() -> AudioStreamWAV:
	return _get_or_make("darkness_silence_pressure", func():
		# Ultra-subtle heavy silence / ear-pressure tension tone when standing in pitch black (looped)
		var duration = 2.0
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 9001
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			lp = lerp(lp, rng.randf_range(-1.0, 1.0), 0.02)
			# Very faint low pressure + barely-there high silence ring (seamless loop)
			var sub = sin(t * TAU * 38.0) * 0.35
			var ring = sin(t * TAU * 2100.0) * 0.035
			var val = clamp((sub + lp * 0.8 + ring) * 0.45, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 11000.0))
		return _make_wav(data, true)
	)

static func make_keypad_beep() -> AudioStreamWAV:
	return _get_or_make("keypad_beep", func():
		var duration = 0.075
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var env = exp(-t * 28.0) * min(t / 0.004, 1.0)
			var tone = sin(t * TAU * 1380.0) * 0.65 + sin(t * TAU * 2760.0) * 0.15
			data.encode_s16(i * 2, int(clamp(tone * env, -1.0, 1.0) * 18000.0))
		return _make_wav(data)
	)

static func make_keypad_error() -> AudioStreamWAV:
	return _get_or_make("keypad_error", func():
		var duration = 0.36
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var pulse = 1.0 if (t < 0.14 or t > 0.19) else 0.0
			var buzz = (fmod(t * 210.0, 1.0) * 2.0 - 1.0) * 0.45 * pulse
			data.encode_s16(i * 2, int(clamp(buzz, -1.0, 1.0) * 20000.0))
		return _make_wav(data)
	)

static func make_keypad_unlock() -> AudioStreamWAV:
	return _get_or_make("keypad_unlock", func():
		# Two-tone chime + heavy electromagnetic bolt releasing
		var duration = 0.55
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 2026
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var val = 0.0
			if t < 0.14:
				val += sin(t * TAU * 980.0) * 0.45 * exp(-t * 14.0)
			elif t < 0.30:
				var dt = t - 0.14
				val += sin(dt * TAU * 1480.0) * 0.50 * exp(-dt * 12.0)
			if t > 0.28:
				var dt2 = t - 0.28
				lp = lerp(lp, rng.randf_range(-1.0, 1.0), 0.18)
				val += lp * 2.6 * exp(-dt2 * 24.0)
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 24000.0))
		return _make_wav(data)
	)

static func make_red_light_shock_sting() -> AudioStreamWAV:
	return _get_or_make("red_light_shock_sting", func():
		# Sudden blood-chilling horror sting: heavy electrical surge + dissonant brass/metal shriek + sub-bass slam!
		var duration = 1.15
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 6661
		var lp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.06)
			# Instant slam + eerie decaying dissonant tritone horror chord
			var env = exp(-t * 2.1) * min(t / 0.006, 1.0)
			var slam = lp * 3.4 * exp(-t * 9.0)
			var tritone = (sin(t * TAU * 155.0) * 0.45 + sin(t * TAU * 220.0) * 0.40 + sin(t * TAU * 311.0) * 0.35 + sin(t * TAU * 622.0) * 0.20)
			var surge = raw * 0.65 * exp(-t * 14.0)
			var val = clamp((slam + tritone * 0.72 + surge) * env, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 31500.0))
		return _make_wav(data)
	)

static func make_intercom_ring() -> AudioStreamWAV:
	return _get_or_make("intercom_ring", func():
		# Piercing retro Brazilian building intercom wall-buzzer ring (2 sharp bursts)
		var duration = 1.15
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var active = (t < 0.42) or (t > 0.56 and t < 0.98)
			var val = 0.0
			if active:
				var trill = 0.5 + 0.5 * sin(t * TAU * 26.0)
				var buzz = (sin(t * TAU * 860.0) * 0.5 + sin(t * TAU * 1290.0) * 0.35 + (fmod(t * 430.0, 1.0) * 2.0 - 1.0) * 0.25)
				val = buzz * (0.45 + 0.55 * trill) * 0.65
			data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 24000.0))
		return _make_wav(data)
	)

static func make_intercom_static_voice() -> AudioStreamWAV:
	return _get_or_make("intercom_static_voice", func():
		# Harsh intercom speaker static + eerie garbled low vocal rasping
		var duration = 1.65
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 4041
		var lp = 0.0
		var bp = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp = lerp(lp, raw, 0.35)
			bp = lerp(bp, lp, 0.10)
			var static_crackle = (lp - bp) * 0.85
			# Syllabic creepy rasp ("não... olha... pra trás...")
			var syll = max(0.0, sin(t * TAU * 2.4)) * exp(-abs(t - 0.85) * 1.4)
			var vocal = sin(t * TAU * (115.0 + sin(t * 22.0) * 24.0)) * syll * 0.55
			var env = min(t / 0.04, 1.0) * clamp((duration - t) / 0.12, 0.0, 1.0)
			data.encode_s16(i * 2, int(clamp((static_crackle * 0.55 + vocal) * env, -1.0, 1.0) * 25000.0))
		return _make_wav(data)
	)

static func make_short_circuit_spark() -> AudioStreamWAV:
	return _get_or_make("short_circuit_spark", func():
		# Sharp electrical ballast short-circuit buzz + glass pop (when broken sensor fails in dark)
		var duration = 0.42
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 9898
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			var arc = raw * (0.5 + 0.5 * sin(t * TAU * 120.0)) * exp(-t * 9.0)
			var pop = 0.0
			if t > 0.24:
				pop = raw * exp(-(t - 0.24) * 55.0) * 1.3
			data.encode_s16(i * 2, int(clamp((arc * 0.7 + pop) * 0.9, -1.0, 1.0) * 29000.0))
		return _make_wav(data)
	)

static func make_window_face_thud() -> AudioStreamWAV:
	return _get_or_make("window_face_thud", func():
		# Sudden startling dull thud against wire-glass when Pursuer presses face to the Antecâmara window!
		var duration = 0.28
		var samples = int(SAMPLE_RATE * duration)
		var data = PackedByteArray()
		data.resize(samples * 2)
		var rng = RandomNumberGenerator.new()
		rng.seed = 3141
		var lp1 = 0.0
		var lp2 = 0.0
		for i in range(samples):
			var t = float(i) / SAMPLE_RATE
			var raw = rng.randf_range(-1.0, 1.0)
			lp1 = lerp(lp1, raw, 0.06)
			lp2 = lerp(lp2, raw, 0.35)
			var glass_ring = (lp2 - lp1) * 1.2
			var env = exp(-t * 28.0) * min(t / 0.003, 1.0)
			var val = clamp((lp1 * 2.8 + glass_ring) * env, -1.0, 1.0)
			data.encode_s16(i * 2, int(val * 29000.0))
		return _make_wav(data)
	)
