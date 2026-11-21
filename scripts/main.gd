extends Node3D

# BREU - Physical 10-Story Stairwell, Haunting Purification, Progressive Pursuer & 3D Jumpscares (Option A)

const TOP_FLOOR: int = 10
const SEGMENT_HEIGHT: float = StairwellSegment.FLOOR_HEIGHT

# All real physical floors stacked vertically: floors[10] at Y=0, floors[9] at Y=-4.8, ..., floors[0] at Y=-48.0
var floors: Dictionary = {}
var player: PlayerController
var ps1_shader_mat: ShaderMaterial

# UI (Ultra-minimal; Option A: ZERO text on death!)
var ui_hint_label: Label
var ui_interact_prompt: Label
var ui_blackout_rect: ColorRect
var ui_victory_label: Label

# Global Audio
var sfx_ambient_drone: AudioStreamPlayer
var sfx_bulb_pop: AudioStreamPlayer
var sfx_jumpscare_sting: AudioStreamPlayer
var sfx_wake_pant: AudioStreamPlayer
var sfx_whisper_neck: AudioStreamPlayer

# 3D Scare Prop (used for "O Puxão no Breu" close-up grab)
var scare_entity_node: Node3D

# Physical 3D Pursuer State Machine (Slow, Audio-Driven, Climbs Floor-by-Floor!)
enum PursuerState { INACTIVE, CLIMBING_TO_PLAYER, CHECKING_DOOR_WINDOW, FORCING_DOOR, LEAVING_UPWARD }
var pursuer_state: int = PursuerState.INACTIVE
var pursuer_node: Node3D
var pursuer_head: Node3D
var pursuer_arm_l: Node3D
var pursuer_arm_r: Node3D
var pursuer_leg_l: Node3D
var pursuer_leg_r: Node3D
var sfx_pursuer_step: AudioStreamPlayer3D
var pursuer_step_stream_l: AudioStreamWAV
var pursuer_step_stream_r: AudioStreamWAV
var pursuer_step_toggle: bool = false

var pursuer_waypoints: Array[Vector3] = []
var pursuer_step_timer: float = 0.0
var pursuer_state_timer: float = 0.0
var pursuer_target_floor: int = -1
var pursuer_event_cooldown: float = 22.0
var pursuer_has_triggered_this_run: bool = false
var lowest_floor_reached: int = TOP_FLOOR

var is_dying_or_resetting: bool = false

func _ready() -> void:
	randomize()
	AudioSynth.setup_audio_buses()
	_setup_environment()
	_build_physical_10_story_building()
	_setup_top_floor_security_gate()
	_setup_player()
	_setup_pursuer_and_scare_entities()
	_setup_post_process_and_ui()
	_setup_global_audio()
	
	_start_new_run(false)

func _setup_environment() -> void:
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.004, 0.007)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.018, 0.022, 0.028)
	env.ambient_light_energy = 0.22
	env.fog_enabled = true
	env.fog_light_color = Color(0.008, 0.010, 0.014)
	env.fog_density = 0.055
	we.environment = env
	add_child(we)

func _build_physical_10_story_building() -> void:
	# Physically stack Floor 10 (Y = 0.0) down to Floor 0 / Térreo (Y = -48.0)
	for f in range(TOP_FLOOR, -1, -1):
		var seg = StairwellSegment.new()
		seg.is_top_floor = (f == TOP_FLOOR)
		seg.is_ground_floor = (f == 0)
		seg.position = Vector3(0.0, -float(TOP_FLOOR - f) * SEGMENT_HEIGHT, 0.0)
		seg.haunting_ignored_kill.connect(_on_haunting_ignored_kill)
		seg.back_door_kill.connect(_on_back_door_kill)
		seg.ground_floor_escaped.connect(_on_ground_floor_escaped)
		seg.floor_went_dark_after_visit.connect(_on_floor_went_dark_after_visit)
		seg.request_upper_floor_anomaly.connect(_on_request_upper_floor_anomaly)
		add_child(seg)
		floors[f] = seg

func _setup_top_floor_security_gate() -> void:
	# Iron security gate ONLY on the 10th floor (where the stairwell begins at the top!)
	var gate = Node3D.new()
	gate.position = Vector3(1.12, 0.0, -0.35)
	add_child(gate)
	
	var gate_body = StaticBody3D.new()
	var gcol = CollisionShape3D.new()
	var gbox = BoxShape3D.new()
	gbox.size = Vector3(2.0, 2.5, 0.15)
	gcol.shape = gbox
	gcol.position = Vector3(0.0, 1.25, 0.0)
	gate_body.add_child(gcol)
	gate.add_child(gate_body)
	
	var iron_mat = StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.16, 0.17, 0.18)
	iron_mat.metallic = 0.75
	iron_mat.roughness = 0.45
	
	for hy in [0.1, 1.2, 2.3]:
		var hbar = MeshInstance3D.new()
		var hbm = BoxMesh.new()
		hbm.size = Vector3(1.94, 0.05, 0.05)
		hbar.mesh = hbm
		hbar.position = Vector3(0.0, hy, 0.0)
		hbar.material_override = iron_mat
		gate.add_child(hbar)
	
	for i in range(9):
		var vx = -0.88 + float(i) * 0.22
		var vbar = MeshInstance3D.new()
		var vbm = CylinderMesh.new()
		vbm.top_radius = 0.016
		vbm.bottom_radius = 0.016
		vbm.height = 2.3
		vbar.mesh = vbm
		vbar.position = Vector3(vx, 1.2, 0.0)
		vbar.material_override = iron_mat
		gate.add_child(vbar)

func _setup_player() -> void:
	player = PlayerController.new()
	add_child(player)

func _setup_pursuer_and_scare_entities() -> void:
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.01, 0.01, 0.012)
	p_mat.roughness = 0.95
	
	var fmat = StandardMaterial3D.new()
	fmat.albedo_texture = ProceduralTextures.get_peeking_face_texture()
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# 1. Physical 3D Pursuer
	pursuer_node = Node3D.new()
	pursuer_node.visible = false
	add_child(pursuer_node)
	
	var parts = StairwellSegment.build_articulated_dark_figure(pursuer_node, p_mat)
	pursuer_head = parts["head"]
	pursuer_arm_l = parts["arm_l"]
	pursuer_arm_r = parts["arm_r"]
	pursuer_leg_l = parts["leg_l"]
	pursuer_leg_r = parts["leg_r"]
	
	var p_face = MeshInstance3D.new()
	var pf_quad = QuadMesh.new()
	pf_quad.size = Vector2(0.24, 0.30)
	p_face.mesh = pf_quad
	p_face.position = Vector3(0.0, 0.0, 0.135)
	p_face.material_override = fmat
	pursuer_head.add_child(p_face)
	
	# Realistic distance-attenuated footsteps (quiet when 2 floors below, growing louder as he climbs closer, fading as he leaves!)
	pursuer_step_stream_l = AudioSynth.make_pursuer_single_step()
	pursuer_step_stream_r = AudioSynth.make_pursuer_step_alt()
	sfx_pursuer_step = AudioSynth.create_player_3d(pursuer_node, pursuer_step_stream_l, 2.8, 28.0, "Stairwell", 0.0)
	sfx_pursuer_step.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	
	# 2. Dedicated Close-Up Scare Entity for "O Puxão no Breu" jumpscare
	scare_entity_node = Node3D.new()
	scare_entity_node.visible = false
	add_child(scare_entity_node)
	
	var s_parts = StairwellSegment.build_articulated_dark_figure(scare_entity_node, p_mat)
	var s_face = MeshInstance3D.new()
	s_face.mesh = pf_quad
	s_face.position = Vector3(0.0, 0.0, 0.14)
	s_face.material_override = fmat
	s_parts["head"].add_child(s_face)

func _setup_post_process_and_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var shader_rect = ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ps1_shader_mat = ShaderMaterial.new()
	ps1_shader_mat.shader = load("res://shaders/ps1_post.gdshader")
	shader_rect.material = ps1_shader_mat
	canvas.add_child(shader_rect)
	
	ui_hint_label = Label.new()
	ui_hint_label.position = Vector2(22, 16)
	ui_hint_label.add_theme_font_size_override("font_size", 16)
	ui_hint_label.add_theme_color_override("font_color", Color(0.60, 0.65, 0.62, 0.55))
	ui_hint_label.text = "BREU  |  [WASD] Andar  [SHIFT] Correr  [CTRL] Agachar  [E] Porta  |  [F1] Anomalia  [F2] Perseguidor"
	canvas.add_child(ui_hint_label)
	
	ui_interact_prompt = Label.new()
	ui_interact_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ui_interact_prompt.position = Vector2(-240, -82)
	ui_interact_prompt.size = Vector2(480, 42)
	ui_interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_interact_prompt.add_theme_font_size_override("font_size", 21)
	ui_interact_prompt.add_theme_color_override("font_color", Color(0.92, 0.90, 0.78, 0.92))
	ui_interact_prompt.text = ""
	canvas.add_child(ui_interact_prompt)
	
	# Pure pitch-black blackout overlay for hard cuts (Option A: ZERO death text!)
	ui_blackout_rect = ColorRect.new()
	ui_blackout_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_blackout_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	ui_blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_blackout_rect)
	
	ui_victory_label = Label.new()
	ui_victory_label.set_anchors_preset(Control.PRESET_CENTER)
	ui_victory_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_victory_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_victory_label.add_theme_font_size_override("font_size", 28)
	ui_victory_label.modulate = Color(0.45, 0.95, 0.55, 0.0)
	ui_victory_label.text = "TÉRREO ALCANÇADO\nVocê saiu do BREU."
	ui_blackout_rect.add_child(ui_victory_label)

func _setup_global_audio() -> void:
	sfx_ambient_drone = AudioSynth.create_player(self, AudioSynth.make_ambient_building_drone(), "Master", -12.0)
	sfx_ambient_drone.play()
	sfx_bulb_pop = AudioSynth.create_player(self, AudioSynth.make_bulb_pop(), "Stairwell", 2.0)
	sfx_jumpscare_sting = AudioSynth.create_player(self, AudioSynth.make_jumpscare_sting(), "Scare", 1.5)
	sfx_wake_pant = AudioSynth.create_player(self, AudioSynth.make_wake_pant(), "Master", -1.5)
	sfx_whisper_neck = AudioSynth.create_player(self, AudioSynth.make_whisper_breath(), "Master", 2.0)

func _start_new_run(play_wake_breath: bool) -> void:
	is_dying_or_resetting = false
	pursuer_state = PursuerState.INACTIVE
	pursuer_node.visible = false
	scare_entity_node.visible = false
	pursuer_has_triggered_this_run = false
	pursuer_event_cooldown = randf_range(16.0, 26.0)
	lowest_floor_reached = TOP_FLOOR
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.0)
	
	# Shuffled anomaly deck guarantees you encounter diverse hauntings (posters, shadow, vulto, window, upper stalker, doors) instead of repeats!
	var deck = [
		StairwellSegment.AnomalyType.HAUNTED_DECOR_POSTERS,
		StairwellSegment.AnomalyType.STATIC_DARK_FIGURE,
		StairwellSegment.AnomalyType.INVISIBLE_CAST_SHADOW,
		StairwellSegment.AnomalyType.HAUNTED_POSTER_WINDOW,
		StairwellSegment.AnomalyType.UPPER_FLOOR_STALKER,
		StairwellSegment.AnomalyType.HANDS_ON_DOOR,
		StairwellSegment.AnomalyType.DOOR_WINDOW_WATCHER
	]
	deck.shuffle()
	var deck_idx = 0
	
	# Randomize which fire doors are unlocked this run (fairness rule: never more than 2 locked in a row)
	var consecutive_locked = 0
	for f in range(TOP_FLOOR, -1, -1):
		var seg = floors[f] as StairwellSegment
		var anom = StairwellSegment.AnomalyType.NONE
		var unlocked = false
		
		if f == TOP_FLOOR:
			anom = StairwellSegment.AnomalyType.NONE
			unlocked = true
		elif f == 0:
			anom = StairwellSegment.AnomalyType.NONE
			unlocked = true
		else:
			# ~65% chance of haunting on floors 9..1 drawn from shuffled unique deck
			if randf() < 0.65 and deck_idx < deck.size():
				anom = deck[deck_idx]
				deck_idx += 1
			
			if consecutive_locked >= 2:
				unlocked = true
				consecutive_locked = 0
			else:
				unlocked = (randf() < 0.55)
				if unlocked:
					consecutive_locked = 0
				else:
					consecutive_locked += 1
		
		seg.setup_floor(f, anom, unlocked, (f == TOP_FLOOR))
	
	# Reset player to 10th floor landing
	player.controls_locked = false
	player.global_position = Vector3(-0.35, 0.06, 1.2)
	player.rotation = Vector3(0.0, deg_to_rad(15.0), 0.0)
	player.head_pivot.rotation = Vector3.ZERO
	player.scare_flash_light.visible = false
	player.scare_flash_light.light_energy = 0.0
	
	ui_blackout_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	ui_victory_label.modulate.a = 0.0
	
	if play_wake_breath and sfx_wake_pant:
		sfx_wake_pant.play()

func _pick_random_anomaly(floor_num: int, exclude_anom: int) -> int:
	var pool = [
		StairwellSegment.AnomalyType.DOOR_WINDOW_WATCHER,
		StairwellSegment.AnomalyType.STATIC_DARK_FIGURE,
		StairwellSegment.AnomalyType.HANDS_ON_DOOR,
		StairwellSegment.AnomalyType.INVISIBLE_CAST_SHADOW,
		StairwellSegment.AnomalyType.HAUNTED_POSTER_WINDOW,
		StairwellSegment.AnomalyType.HAUNTED_DECOR_POSTERS
	]
	if floor_num < TOP_FLOOR:
		pool.append(StairwellSegment.AnomalyType.UPPER_FLOOR_STALKER)
	pool.erase(exclude_anom)
	return pool[randi() % pool.size()]

func _get_player_floor_index() -> int:
	if not player:
		return TOP_FLOOR
	var raw = TOP_FLOOR - int(floor((-player.global_position.y + 0.55) / SEGMENT_HEIGHT))
	return clamp(raw, 0, TOP_FLOOR)

func _get_nearest_door_segment() -> StairwellSegment:
	var f = _get_player_floor_index()
	for check_f in [f, f + 1, f - 1]:
		if floors.has(check_f):
			var seg = floors[check_f] as StairwellSegment
			if seg.can_interact_with_fire_door(player.global_position):
				return seg
	return null

func _unhandled_input(event: InputEvent) -> void:
	if is_dying_or_resetting or not player or player.controls_locked:
		return
	
	var pressed_interact = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed_interact = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		pressed_interact = true
	
	if pressed_interact:
		var seg = _get_nearest_door_segment()
		if seg:
			# Passing player.is_crouching prevents opening/closing the door while crouched!
			seg.toggle_fire_door(player.is_crouching)
	
	# [F1] Debug: Cycle all 7 anomalies on the floor the player is currently standing on
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		var f = _get_player_floor_index()
		if f > 0 and floors.has(f):
			var seg = floors[f] as StairwellSegment
			var next_a = (seg.anomaly_type + 1) % 8
			seg.set_anomaly_runtime(next_a)
	
	# [F2] Debug: Trigger the Progressive Pursuer Event from 2 floors below immediately!
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		if pursuer_state == PursuerState.INACTIVE:
			_trigger_progressive_pursuer_event()

func _on_floor_went_dark_after_visit(floor_num: int) -> void:
	# Player visited a floor, retreated UP, and waited for its lights to turn OFF!
	if floor_num <= 0 or floor_num >= TOP_FLOOR:
		return
	var p_floor = _get_player_floor_index()
	# Only purify/re-roll when the player has actually retreated ABOVE this floor!
	if p_floor > floor_num:
		var seg = floors[floor_num] as StairwellSegment
		if seg.anomaly_type != StairwellSegment.AnomalyType.NONE:
			# 70% chance the floor is PURIFIED; 30% chance it SWAPS to a different haunting!
			if randf() < 0.70:
				seg.set_anomaly_runtime(StairwellSegment.AnomalyType.NONE)
			else:
				seg.set_anomaly_runtime(_pick_random_anomaly(floor_num, seg.anomaly_type))

func _on_request_upper_floor_anomaly(target_upper_floor: int) -> void:
	if floors.has(target_upper_floor):
		var seg_up = floors[target_upper_floor] as StairwellSegment
		seg_up.trigger_main_sensor(7.5, false)
		seg_up.start_upper_stalker_descent()

func _physics_process(delta: float) -> void:
	if is_dying_or_resetting or not player:
		return
	
	_update_interact_prompt()
	_update_pursuer_event_spawner(delta)
	_update_pursuer_state_machine(delta)

func _update_interact_prompt() -> void:
	var seg = _get_nearest_door_segment()
	if not seg:
		ui_interact_prompt.text = ""
		return
	
	var holding = Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if seg.is_ground_floor:
		ui_interact_prompt.text = "[E] SAIR DO PRÉDIO (TÉRREO)"
	elif seg.is_door_being_forced and seg.player_inside_antecamara:
		ui_interact_prompt.text = "SEGURANDO A PORTA!" if holding else "SEGURE [E] PARA TRAVAR A PORTA!"
	elif player.is_crouching and seg.player_inside_antecamara and not seg.is_fire_door_open:
		ui_interact_prompt.text = "TRAVANDO A PORTA [E]" if holding else "Agachado — Segure [E] para travar | Levante [CTRL] para abrir"
	elif player.is_crouching:
		ui_interact_prompt.text = "Levante [CTRL] para abrir a porta"
	elif seg.is_fire_door_open:
		ui_interact_prompt.text = "[E] Fechar Porta"
	elif seg.player_inside_antecamara:
		ui_interact_prompt.text = "[E] Abrir Porta"
	else:
		ui_interact_prompt.text = "[E] Porta Corta-Fogo"

# =============================================================================
# PROGRESSIVE AUDIO-DRIVEN PURSUER SYSTEM
# =============================================================================
func _update_pursuer_event_spawner(delta: float) -> void:
	var p_floor = _get_player_floor_index()
	if p_floor < lowest_floor_reached:
		lowest_floor_reached = p_floor
	
	if pursuer_state != PursuerState.INACTIVE:
		return
	
	# Only trigger organically when player is descending in the middle floors (8..3)
	if p_floor <= 8 and p_floor >= 3 and not (floors[p_floor] as StairwellSegment).player_inside_antecamara:
		pursuer_event_cooldown -= delta
		if pursuer_event_cooldown <= 0.0:
			# Rare dread event (~40% roll every cooldown window)
			if randf() < 0.45 or not pursuer_has_triggered_this_run:
				_trigger_progressive_pursuer_event()
			else:
				pursuer_event_cooldown = 18.0

func _trigger_progressive_pursuer_event() -> void:
	var p_floor = _get_player_floor_index()
	var spawn_floor = max(p_floor - 2, 1)
	if spawn_floor == p_floor:
		spawn_floor = max(p_floor - 1, 1)
	
	pursuer_has_triggered_this_run = true
	pursuer_event_cooldown = randf_range(38.0, 55.0)
	pursuer_state = PursuerState.CLIMBING_TO_PLAYER
	pursuer_step_timer = 0.85
	
	# 1. Massive distant fire-door SLAM 2 floors below echoing up the shaft!
	var spawn_seg = floors[spawn_floor] as StairwellSegment
	spawn_seg.play_aggressive_door_slam()
	spawn_seg.trigger_main_sensor(6.0, false)
	
	# 2. Place physical 3D Pursuer at that lower floor's fire door and build climbing waypoints up the stairs!
	var start_pos = spawn_seg.to_global(Vector3(0.0, 0.0, 1.9))
	pursuer_node.global_position = start_pos
	pursuer_node.visible = true
	
	pursuer_waypoints.clear()
	var top_goal = min(p_floor + 1, TOP_FLOOR)
	for f in range(spawn_floor, top_goal):
		var next_f = f + 1
		var seg_up = floors[next_f] as StairwellSegment
		# Climb UP Flight 2 (from lower main landing Z=0.5, Y=-4.8 to mid landing Z=-7.4, Y=-2.4)
		pursuer_waypoints.append(seg_up.to_global(Vector3(1.12, -4.8, 0.4)))
		pursuer_waypoints.append(seg_up.to_global(Vector3(1.12, -2.4, -7.2)))
		# Cross mid landing & climb UP Flight 1 (from Z=-7.2, Y=-2.4 to upper main landing Z=0.8, Y=0.0)
		pursuer_waypoints.append(seg_up.to_global(Vector3(-1.12, -2.4, -7.2)))
		pursuer_waypoints.append(seg_up.to_global(Vector3(-1.12, 0.0, 0.9)))
		# Pause near the floor's fire door landing
		pursuer_waypoints.append(seg_up.to_global(Vector3(0.0, 0.0, 1.65)))

func _update_pursuer_state_machine(delta: float) -> void:
	# Always pause & reset the Antecâmara back-door timer while the Pursuer is active anywhere in the stairwell!
	var pursuer_active = (pursuer_state != PursuerState.INACTIVE)
	for f in floors.keys():
		(floors[f] as StairwellSegment).pause_back_door_timer = pursuer_active
	
	if not pursuer_active:
		return
	
	var t_sec = Time.get_ticks_msec() * 0.001
	var p_floor = _get_player_floor_index()
	var p_seg = floors[p_floor] as StairwellSegment
	var player_safe_behind_closed_door = (p_seg.player_inside_antecamara and not p_seg.is_fire_door_open)
	
	# Trigger real motion-sensor lights on whichever floor the Pursuer is physically climbing!
	var pur_floor = clamp(TOP_FLOOR - int(floor((-pursuer_node.global_position.y + 0.55) / SEGMENT_HEIGHT)), 0, TOP_FLOOR)
	if floors.has(pur_floor):
		var pur_seg = floors[pur_floor] as StairwellSegment
		var pur_local = pur_seg.to_local(pursuer_node.global_position)
		if pur_local.z > -1.5 and pur_local.y > -1.0:
			pur_seg.trigger_main_sensor(5.5, false)
		elif pur_local.z < -4.5 and pur_local.y < -1.2:
			pur_seg.trigger_mid_sensor(5.5)
	
	match pursuer_state:
		PursuerState.CLIMBING_TO_PLAYER:
			if not player_safe_behind_closed_door:
				var dist_to_player = pursuer_node.global_position.distance_to(player.global_position)
				if dist_to_player < 1.15:
					_trigger_pursuer_jumpscare()
					return
			
			if player_safe_behind_closed_door and pur_floor == p_floor:
				var door_outside_pos = p_seg.to_global(Vector3(0.0, 0.0, 2.02))
				if pursuer_node.global_position.distance_to(door_outside_pos) < 1.05:
					pursuer_node.global_position = door_outside_pos
					pursuer_node.rotation.y = 0.0
					pursuer_target_floor = p_floor
					pursuer_state = PursuerState.CHECKING_DOOR_WINDOW
					pursuer_state_timer = 2.6
					return
			
			_move_pursuer_along_waypoints(delta, 1.85, 0.58)
			if pursuer_waypoints.is_empty():
				_finish_pursuer_at_upper_door(pur_floor)
		
		PursuerState.CHECKING_DOOR_WINDOW:
			# Keep the outside stairwell light SOLIDLY ON so you can clearly see him outside the door window!
			var target_seg = floors[pursuer_target_floor] as StairwellSegment
			target_seg.trigger_main_sensor(4.0, true)
			
			pursuer_state_timer -= delta
			pursuer_head.rotation.z = deg_to_rad(sin(t_sec * 1.8) * 11.0)
			
			if target_seg.is_fire_door_open or not target_seg.is_player_hidden_in_blind_spot(player):
				target_seg.is_fire_door_open = true
				target_seg.fire_door_target_angle = deg_to_rad(-82.0)
				_trigger_pursuer_jumpscare()
				return
			
			if pursuer_state_timer <= 0.0:
				if randf() < 0.78:
					pursuer_state = PursuerState.FORCING_DOOR
					pursuer_state_timer = 2.65
					target_seg.is_door_being_forced = true
					target_seg.door_force_audio_timer = 0.0
				else:
					_begin_pursuer_leaving_upward(pursuer_target_floor)
		
		PursuerState.FORCING_DOOR:
			# Keep outside stairwell light ON while he forces the door!
			var target_seg = floors[pursuer_target_floor] as StairwellSegment
			target_seg.trigger_main_sensor(4.0, true)
			
			var is_bracing = target_seg.can_interact_with_fire_door(player.global_position) and (Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
			
			player.camera_shake = 0.018
			ps1_shader_mat.set_shader_parameter("scare_intensity", 0.22 if is_bracing else 0.45)
			
			pursuer_state_timer -= delta
			if pursuer_state_timer < 1.95 and not is_bracing:
				target_seg.is_door_being_forced = false
				target_seg.is_fire_door_open = true
				target_seg.fire_door_target_angle = deg_to_rad(-82.0)
				_trigger_pursuer_jumpscare()
				return
			
			if pursuer_state_timer <= 0.0:
				target_seg.is_door_being_forced = false
				ps1_shader_mat.set_shader_parameter("scare_intensity", 0.0)
				_begin_pursuer_leaving_upward(pursuer_target_floor)
		
		PursuerState.LEAVING_UPWARD:
			_move_pursuer_along_waypoints(delta, 2.05, 0.54)
			if pursuer_waypoints.is_empty():
				var exit_floor = min(pursuer_target_floor + 1, TOP_FLOOR)
				_finish_pursuer_at_upper_door(exit_floor)

func _begin_pursuer_leaving_upward(from_floor: int) -> void:
	pursuer_state = PursuerState.LEAVING_UPWARD
	pursuer_waypoints.clear()
	var next_f = min(from_floor + 1, TOP_FLOOR)
	if next_f == from_floor:
		_finish_pursuer_at_upper_door(from_floor)
		return
	var seg_up = floors[next_f] as StairwellSegment
	pursuer_waypoints.append(seg_up.to_global(Vector3(1.12, -4.8, 0.4)))
	pursuer_waypoints.append(seg_up.to_global(Vector3(1.12, -2.4, -7.2)))
	pursuer_waypoints.append(seg_up.to_global(Vector3(-1.12, -2.4, -7.2)))
	pursuer_waypoints.append(seg_up.to_global(Vector3(-1.12, 0.0, 0.9)))
	pursuer_waypoints.append(seg_up.to_global(Vector3(0.0, 0.0, 2.1)))

func _finish_pursuer_at_upper_door(door_floor: int) -> void:
	# Aggressive loud door slam on the next floor up -> Clear audio cue that it's SAFE to exit!
	if floors.has(door_floor):
		(floors[door_floor] as StairwellSegment).play_aggressive_door_slam()
	pursuer_node.visible = false
	pursuer_state = PursuerState.INACTIVE
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.0)

func _move_pursuer_along_waypoints(delta: float, move_speed: float, step_interval: float) -> void:
	if pursuer_waypoints.is_empty():
		return
	var target = pursuer_waypoints[0]
	var diff = target - pursuer_node.global_position
	var dist = diff.length()
	if dist < 0.25:
		pursuer_waypoints.pop_front()
		return
	
	var dir = diff.normalized()
	pursuer_node.global_position += dir * move_speed * delta
	var flat_target = Vector3(target.x, pursuer_node.global_position.y, target.z)
	if flat_target.distance_to(pursuer_node.global_position) > 0.05:
		pursuer_node.look_at(flat_target, Vector3.UP)
		pursuer_node.rotate_y(PI)
	
	# Slow heavy limb stride & echoing step audio
	var t_sec = Time.get_ticks_msec() * 0.001
	var swing = sin(t_sec * 8.5) * 0.55
	pursuer_arm_l.rotation.x = swing
	pursuer_arm_r.rotation.x = -swing
	pursuer_leg_l.rotation.x = -swing
	pursuer_leg_r.rotation.x = swing
	
	pursuer_step_timer -= delta
	if pursuer_step_timer <= 0.0:
		pursuer_step_timer = step_interval
		if sfx_pursuer_step:
			# Alternate left/right shoe samples for natural human cadence
			pursuer_step_toggle = not pursuer_step_toggle
			sfx_pursuer_step.stream = pursuer_step_stream_l if pursuer_step_toggle else pursuer_step_stream_r
			
			# True distance-based volume & muffled feel: very quiet 2 floors below (-20 dB),
			# progressively louder as he climbs closer, peaking right outside your door (+1 dB),
			# then smoothly fading back down as he walks away upward!
			var p_dist = pursuer_node.global_position.distance_to(player.global_position)
			var closeness = clamp(1.0 - (p_dist / 19.0), 0.0, 1.0)
			sfx_pursuer_step.volume_db = lerp(-21.0, 1.5, closeness * closeness)
			sfx_pursuer_step.bus = "Muffled" if p_dist > 8.5 else "Stairwell"
			sfx_pursuer_step.pitch_scale = randf_range(0.92, 1.04)
			sfx_pursuer_step.play()

# =============================================================================
# 3D JUMPSCARE SEQUENCES (OPTION A: ZERO DEATH TEXT -> BLACKOUT -> WAKE PANTING)
# =============================================================================
func _on_haunting_ignored_kill(floor_num: int) -> void:
	if is_dying_or_resetting:
		return
	is_dying_or_resetting = true
	player.controls_locked = true
	pursuer_state = PursuerState.INACTIVE
	pursuer_node.visible = false
	
	# 1. Sudden bulb POP + pitch black silence ("O Segundo de Pavor")
	if floors.has(floor_num):
		(floors[floor_num] as StairwellSegment).force_lights_off_immediately()
	if floors.has(floor_num - 1):
		(floors[floor_num - 1] as StairwellSegment).force_lights_off_immediately()
	if sfx_bulb_pop:
		sfx_bulb_pop.play()
	
	await get_tree().create_timer(0.55).timeout
	
	# 2. Whisper right behind neck -> Spawn scare entity right behind player -> Force 180° whip turn!
	if sfx_whisper_neck:
		sfx_whisper_neck.play()
	
	var back_dir = player.global_transform.basis.z.normalized()
	var scare_pos = player.global_position + back_dir * 0.72
	scare_pos.y = player.global_position.y - 0.12
	scare_entity_node.global_position = scare_pos
	scare_entity_node.look_at(Vector3(player.global_position.x, scare_pos.y, player.global_position.z), Vector3.UP)
	scare_entity_node.rotate_y(PI)
	scare_entity_node.visible = true
	
	# Whip camera 180 degrees to stare straight into the entity's face!
	var whip_tween = create_tween()
	whip_tween.tween_property(player, "rotation:y", player.rotation.y + PI, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	whip_tween.parallel().tween_property(player.head_pivot, "rotation:x", 0.08, 0.22)
	await whip_tween.finished
	
	# 3. Strobe flash + Brutal PS1 Sting + Glitch + Camera Drop -> Hard Cut to Black!
	player.scare_flash_light.visible = true
	player.scare_flash_light.light_energy = 4.2
	player.camera_shake = 0.085
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.92)
	if sfx_jumpscare_sting:
		sfx_jumpscare_sting.play()
	
	var drop_tween = create_tween()
	drop_tween.tween_property(player.head_pivot, "rotation:z", deg_to_rad(32.0), 0.55)
	drop_tween.parallel().tween_property(player.head_pivot, "position:y", 0.55, 0.55)
	await get_tree().create_timer(0.72).timeout
	
	await _hard_cut_blackout_and_restart()

func _trigger_pursuer_jumpscare() -> void:
	if is_dying_or_resetting:
		return
	is_dying_or_resetting = true
	player.controls_locked = true
	pursuer_state = PursuerState.INACTIVE
	
	# Place Pursuer inches from player face, snap camera to him, lift player up violently!
	var fwd = -player.global_transform.basis.z.normalized()
	pursuer_node.global_position = player.global_position + fwd * 0.62
	pursuer_node.global_position.y = player.global_position.y - 0.1
	pursuer_node.look_at(Vector3(player.global_position.x, pursuer_node.global_position.y, player.global_position.z), Vector3.UP)
	pursuer_node.rotate_y(PI)
	pursuer_node.visible = true
	
	player.scare_flash_light.visible = true
	player.scare_flash_light.light_energy = 3.8
	player.camera_shake = 0.095
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.95)
	if sfx_jumpscare_sting:
		sfx_jumpscare_sting.play()
	
	var lift_tween = create_tween()
	lift_tween.tween_property(player.head_pivot, "position:y", 1.92, 0.45)
	lift_tween.parallel().tween_property(player.head_pivot, "rotation:x", 0.12, 0.3)
	await get_tree().create_timer(0.78).timeout
	
	await _hard_cut_blackout_and_restart()

func _on_back_door_kill(_floor_num: int, door_world_pos: Vector3) -> void:
	if is_dying_or_resetting:
		return
	is_dying_or_resetting = true
	player.controls_locked = true
	pursuer_state = PursuerState.INACTIVE
	
	# Whip camera toward the opening back door & drag player into the dark corridor!
	scare_entity_node.global_position = door_world_pos + Vector3(0.0, -1.25, 0.35)
	scare_entity_node.look_at(Vector3(player.global_position.x, scare_entity_node.global_position.y, player.global_position.z), Vector3.UP)
	scare_entity_node.rotate_y(PI)
	scare_entity_node.visible = true
	
	player.look_at(Vector3(door_world_pos.x, player.global_position.y, door_world_pos.z), Vector3.UP)
	player.scare_flash_light.visible = true
	player.scare_flash_light.light_energy = 3.2
	player.camera_shake = 0.08
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.90)
	if sfx_jumpscare_sting:
		sfx_jumpscare_sting.play()
	
	var drag_tween = create_tween()
	drag_tween.tween_property(player, "global_position", door_world_pos - Vector3(0.0, 1.0, 0.15), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.70).timeout
	
	await _hard_cut_blackout_and_restart()

func _hard_cut_blackout_and_restart() -> void:
	# Option A: Instant hard cut to pure pitch black (ZERO text!) -> 1.7s dread silence -> Wake up panting on 10th floor!
	ui_blackout_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	player.scare_flash_light.visible = false
	player.scare_flash_light.light_energy = 0.0
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.0)
	scare_entity_node.visible = false
	pursuer_node.visible = false
	
	await get_tree().create_timer(1.75).timeout
	_start_new_run(true)

func _on_ground_floor_escaped() -> void:
	if is_dying_or_resetting:
		return
	is_dying_or_resetting = true
	player.controls_locked = true
	
	var fade = create_tween()
	fade.tween_property(ui_blackout_rect, "color", Color(0.0, 0.0, 0.0, 1.0), 1.4)
	fade.parallel().tween_property(ui_victory_label, "modulate:a", 1.0, 1.6)
	await get_tree().create_timer(4.5).timeout
	_start_new_run(false)
