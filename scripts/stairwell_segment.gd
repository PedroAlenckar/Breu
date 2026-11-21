extends Node3D
class_name StairwellSegment

# Real Physical Floor Segment (stacked 10..1, plus Ground Floor 0)
const FLOOR_HEIGHT: float = 4.8
const FLIGHT_DROP: float = 2.4
const FLIGHT_RUN: float = 6.4
const NUM_STEPS: int = 16

enum AnomalyType {
	NONE = 0,
	DOOR_WINDOW_WATCHER = 1,   # Face watching behind closed fire-door wire-glass; taps glass (*TOC-TOC*) & bangs if ignored
	STATIC_DARK_FIGURE = 2,    # Dark figure standing on mid-landing; when approached, walks down the lower stairs with echoing steps
	HANDS_ON_DOOR = 3,         # Fire door starts ajar with pale fingers gripping the edge; creaks & latches shut when you move
	INVISIBLE_CAST_SHADOW = 4, # Real 3D shadow cast on the concrete wall by an invisible person under the fluorescent light
	HAUNTED_POSTER_WINDOW = 5, # Safety poster distorts + figure watching & tapping outside the mid-landing night window
	UPPER_FLOOR_STALKER = 6,   # Sensor light on the floor ABOVE clicks on by itself and footsteps walk down from above
	HAUNTED_DECOR_POSTERS = 7, # Lived-in props turn uncanny: posters warp, arrow flips UP ("NÃO DESÇA"), wet-floor sign knocked over, fuse box sparks red!
	RED_LIGHT_SHOCK = 8,       # Sudden blood-red light slam + terrifying shock sting when you trigger the stairwell sensor!
	RINGING_INTERCOM = 9,      # Red emergency intercom on the wall rings piercingly; answering/approaching blasts static whisper & kills lights!
	BROKEN_SENSOR_DARK = 10    # Mid-landing sensor sparks & fails to light up, leaving a pitch-black void with hollow breathing below!
}

var floor_index: int = 10
var is_top_floor: bool = false
var is_ground_floor: bool = false
var anomaly_type: int = AnomalyType.NONE
var was_visited_by_player: bool = false
var was_lit_since_visit: bool = false
var pause_back_door_timer: bool = false

# Lighting / Motion Presence Sensors
var main_light: OmniLight3D
var mid_light: OmniLight3D
var main_bulb_mesh: MeshInstance3D
var mid_bulb_mesh: MeshInstance3D
var main_led_mesh: MeshInstance3D
var mid_led_mesh: MeshInstance3D

const SENSOR_STAY_ON_TIME: float = 4.6
const SENSOR_RETRIGGER_DELAY: float = 0.34

var main_light_on: bool = false
var mid_light_on: bool = false
var main_light_timer: float = 0.0
var mid_light_timer: float = 0.0
var main_flicker_time: float = 0.0
var mid_flicker_time: float = 0.0
var main_motion_delay_accum: float = 0.0
var mid_motion_delay_accum: float = 0.0

# 3D Audio Players (routed through Stairwell / Muffled DSP buses!)
var sfx_click_main: AudioStreamPlayer3D
var sfx_hum_main: AudioStreamPlayer3D
var sfx_click_mid: AudioStreamPlayer3D
var sfx_hum_mid: AudioStreamPlayer3D
var sfx_door_bang: AudioStreamPlayer3D
var sfx_door_creak_shut: AudioStreamPlayer3D
var sfx_door_slam_heavy: AudioStreamPlayer3D
var sfx_door_force_push: AudioStreamPlayer3D
var sfx_glass_tap_door: AudioStreamPlayer3D
var sfx_glass_tap_window: AudioStreamPlayer3D
var sfx_heavy_stairs: AudioStreamPlayer3D
var sfx_whisper: AudioStreamPlayer3D
var sfx_locked_rattle: AudioStreamPlayer3D
var sfx_back_door_tok: AudioStreamPlayer3D
var sfx_back_door_handle: AudioStreamPlayer3D
var sfx_red_shock: AudioStreamPlayer
var sfx_intercom_ring: AudioStreamPlayer3D
var sfx_intercom_static: AudioStreamPlayer3D
var sfx_short_circuit: AudioStreamPlayer3D

# Props, Fire Door & Antecâmara
var floor_label: Label3D
var exit_sign_label: Label3D
var fire_door_pivot: Node3D
var fire_door_col_body: StaticBody3D
var safety_poster_mesh: MeshInstance3D
var evac_poster_mesh: MeshInstance3D
var extra_posters: Array[Dictionary] = []
var arrow_sign_label: Label3D
var wet_floor_sign_root: Node3D
var fuse_box_led_mesh: MeshInstance3D
var notice_board_label: Label3D
var extinguisher_root: Node3D
var intercom_anchor: Node3D
var lightning_light: OmniLight3D
var lightning_silhouette: MeshInstance3D
var red_shock_triggered: bool = false
var intercom_ring_timer: float = 0.0
var intercom_answered: bool = false
var broken_sensor_sparked: bool = false

var antecamara_light: OmniLight3D
var back_corridor_door_pivot: Node3D
var back_door_handle_pivot: Node3D

var base_unlocked_for_run: bool = false
var is_fire_door_locked: bool = true
var is_fire_door_open: bool = false
var fire_door_target_angle: float = 0.0
var player_inside_antecamara: bool = false

# Door Force Struggle (Option C: Hold [E] to brace door against Pursuer!)
var is_door_being_forced: bool = false
var door_force_audio_timer: float = 0.0

# Back Door Slow Tension inside Antecâmara ("tok... tok... tok..." -> handle turning -> death)
var antecamara_linger_timer: float = 0.0
var back_door_stage: int = 0
var back_door_handle_turn_anim: float = 0.0

# Anomaly Containers
var anomaly_root: Node3D
var door_watcher_node: Node3D
var door_watcher_face: MeshInstance3D
var door_watcher_light: OmniLight3D

var vulto_node: Node3D
var vulto_head: Node3D
var vulto_arm_l: Node3D
var vulto_arm_r: Node3D
var vulto_leg_l: Node3D
var vulto_leg_r: Node3D
var vulto_walking_down: bool = false

var hands_node: Node3D
var door_peeking_face: MeshInstance3D
var door_hand_top: Node3D
var door_hand_bot: Node3D
var door_closing_anim: bool = false

var phantom_shadow_node: Node3D
var shadow_caster_head: Node3D
var shadow_caster_arm_r: Node3D

var window_watcher_node: Node3D
var window_face_mesh: MeshInstance3D
var window_hands_l: MeshInstance3D
var window_hands_r: MeshInstance3D

var upper_stalker_node: Node3D
var upper_arm_l: Node3D
var upper_arm_r: Node3D
var upper_leg_l: Node3D
var upper_leg_r: Node3D
var upper_stalker_walking: bool = false
var upper_stalker_triggered: bool = false

var anomaly_triggered_action: bool = false
var secondary_interaction_done: bool = false
var haunting_kill_triggered: bool = false

# Enigmatic Padlock Clue Spots (4 possible hiding spots per floor)
enum ClueSpot { WALL_BLOOD = 0, ANTECAMARA_INSIDE = 1, POSTER_NOTE = 2, WINDOW_FUSE = 3 }
var clue_groups: Dictionary = {}
var clue_text_quads: Dictionary = {}
var active_clue_spot: int = -1
var active_clue_symbol: String = ""
var active_clue_phrase: String = ""
var clue_discovered_already: bool = false

signal haunting_ignored_kill(floor_num: int)
signal back_door_kill(floor_num: int, door_world_pos: Vector3)
signal request_open_keypad()
signal ground_floor_escaped()
signal floor_went_dark_after_visit(floor_num: int)
signal request_upper_floor_anomaly(target_upper_floor: int)
signal clue_discovered(symbol: String, phrase: String)

func _ready() -> void:
	_build_architecture_and_antecamara()
	_build_lights_and_sensors()
	_build_props_and_decorations()
	_build_anomaly_containers()

func setup_floor(p_floor_num: int, p_anomaly: int, p_base_unlocked: bool, p_initial_light_on: bool = false) -> void:
	floor_index = p_floor_num
	anomaly_type = p_anomaly
	base_unlocked_for_run = p_base_unlocked
	was_visited_by_player = false
	was_lit_since_visit = false
	anomaly_triggered_action = false
	secondary_interaction_done = false
	vulto_walking_down = false
	door_closing_anim = false
	upper_stalker_walking = false
	upper_stalker_triggered = false
	haunting_kill_triggered = false
	red_shock_triggered = false
	intercom_ring_timer = 1.2
	intercom_answered = false
	broken_sensor_sparked = false
	
	is_fire_door_open = false
	is_door_being_forced = false
	player_inside_antecamara = false
	antecamara_linger_timer = 0.0
	back_door_stage = 0
	back_door_handle_turn_anim = 0.0
	
	if back_corridor_door_pivot:
		back_corridor_door_pivot.rotation = Vector3.ZERO
	if back_door_handle_pivot:
		back_door_handle_pivot.rotation = Vector3.ZERO
	if antecamara_light:
		antecamara_light.light_energy = 0.36
	if upper_stalker_node:
		upper_stalker_node.visible = false
	
	main_motion_delay_accum = 0.0
	mid_motion_delay_accum = 0.0
	
	_update_door_lock_state()
	update_floor_sign_number(p_floor_num)
	clear_enigmatic_clues()
	_apply_anomaly_state()
	
	if p_initial_light_on:
		trigger_main_sensor(SENSOR_STAY_ON_TIME, true)
	else:
		main_light_on = false
		_set_main_light_power(0.0)
		if sfx_hum_main:
			sfx_hum_main.stop()
	
	mid_light_on = false
	_set_mid_light_power(0.0)
	if sfx_hum_mid:
		sfx_hum_mid.stop()

func _update_door_lock_state() -> void:
	if is_ground_floor:
		is_fire_door_locked = false
		return
	# Haunted doors are ALWAYS locked!
	if anomaly_type == AnomalyType.DOOR_WINDOW_WATCHER or anomaly_type == AnomalyType.HANDS_ON_DOOR:
		is_fire_door_locked = true
	else:
		is_fire_door_locked = not base_unlocked_for_run

func set_anomaly_runtime(new_anomaly: int) -> void:
	anomaly_type = new_anomaly
	was_visited_by_player = false
	was_lit_since_visit = false
	anomaly_triggered_action = false
	secondary_interaction_done = false
	vulto_walking_down = false
	door_closing_anim = false
	upper_stalker_triggered = false
	haunting_kill_triggered = false
	red_shock_triggered = false
	intercom_ring_timer = 1.2
	intercom_answered = false
	broken_sensor_sparked = false
	_update_door_lock_state()
	_apply_anomaly_state()

func update_floor_sign_number(p_floor_num: int) -> void:
	floor_index = p_floor_num
	if not floor_label:
		return
	if p_floor_num == 0:
		floor_label.text = "TÉRREO\nSAÍDA"
		floor_label.modulate = Color(0.35, 1.0, 0.45)
	else:
		floor_label.text = "%dº\nANDAR" % p_floor_num
		floor_label.modulate = Color(0.82, 0.80, 0.72)

func start_upper_stalker_descent() -> void:
	if upper_stalker_node:
		upper_stalker_node.visible = true
		upper_stalker_node.position = Vector3(-1.12, 0.0, 0.15)
		upper_stalker_walking = true
	if sfx_heavy_stairs:
		sfx_heavy_stairs.play()

func play_aggressive_door_slam() -> void:
	if sfx_door_slam_heavy:
		sfx_door_slam_heavy.play()

func force_lights_off_immediately() -> void:
	main_light_on = false
	mid_light_on = false
	_set_main_light_power(0.0)
	_set_mid_light_power(0.0)
	if sfx_hum_main:
		sfx_hum_main.stop()
	if sfx_hum_mid:
		sfx_hum_mid.stop()

func can_interact_with_fire_door(player_global_pos: Vector3) -> bool:
	var local_p = to_local(player_global_pos)
	return abs(local_p.x) < 1.2 and abs(local_p.y - 0.8) < 1.5 and abs(local_p.z - 2.38) < 1.65

func is_player_hidden_in_blind_spot(player: PlayerController) -> bool:
	# Option C: Inside Antecâmara, player is hidden from the fire-door wire-glass window
	# if they are crouching (Ctrl/C) OR tucked to the left/right concrete wall beside the door!
	var local_p = to_local(player.global_position)
	if local_p.z < 2.48:
		return false
	return player.is_crouching or abs(local_p.x) > 0.62

func clear_enigmatic_clues() -> void:
	active_clue_spot = -1
	active_clue_symbol = ""
	active_clue_phrase = ""
	clue_discovered_already = false
	for k in clue_groups.keys():
		var grp = clue_groups[k] as Node3D
		if grp:
			grp.visible = false

func set_enigmatic_clue(spot: int, symbol: String, enigma_phrase: String) -> void:
	active_clue_spot = spot
	active_clue_symbol = symbol
	active_clue_phrase = enigma_phrase
	clue_discovered_already = false
	if clue_text_quads.has(spot):
		var quad = clue_text_quads[spot] as MeshInstance3D
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = ProceduralTextures.make_blood_handwritten_texture(symbol, enigma_phrase)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.22
		quad.material_override = mat
	if clue_groups.has(spot):
		(clue_groups[spot] as Node3D).visible = true
	if spot == ClueSpot.ANTECAMARA_INSIDE:
		base_unlocked_for_run = true
		is_fire_door_locked = false

func can_interact_with_intercom(player_global_pos: Vector3) -> bool:
	if is_ground_floor or anomaly_type != AnomalyType.RINGING_INTERCOM or intercom_answered:
		return false
	var local_p = to_local(player_global_pos)
	return local_p.distance_to(Vector3(-2.16, 1.32, 2.02)) < 1.55

func answer_ringing_intercom() -> void:
	if intercom_answered:
		return
	intercom_answered = true
	if sfx_intercom_ring:
		sfx_intercom_ring.stop()
	if sfx_intercom_static:
		sfx_intercom_static.play()
	# Cut lights abruptly after a brief chilling beat!
	await get_tree().create_timer(0.65).timeout
	if anomaly_type == AnomalyType.RINGING_INTERCOM:
		force_lights_off_immediately()

func trigger_window_lightning(show_silhouette: bool) -> void:
	if is_ground_floor or not lightning_light:
		return
	lightning_light.visible = true
	lightning_light.light_energy = 4.5
	if lightning_silhouette:
		lightning_silhouette.visible = show_silhouette
	await get_tree().create_timer(0.16).timeout
	if lightning_light:
		lightning_light.light_energy = 0.0
		lightning_light.visible = false
	if lightning_silhouette:
		lightning_silhouette.visible = false

func unlock_ground_floor_exit() -> void:
	if not is_ground_floor:
		return
	is_fire_door_open = true
	fire_door_target_angle = deg_to_rad(-82.0)
	if sfx_door_creak_shut:
		sfx_door_creak_shut.pitch_scale = 1.05
		sfx_door_creak_shut.play()
	ground_floor_escaped.emit()

func toggle_fire_door(player_is_crouching: bool = false) -> bool:
	if is_ground_floor:
		# Opening the Térreo exit door opens the 4-digit Padlock/Keypad UI!
		if not is_fire_door_open:
			request_open_keypad.emit()
		return true
	
	# Never open/close the fire door while crouched (crouched + E is strictly for bracing!)
	# or while the Pursuer is actively forcing the door!
	if player_is_crouching or is_door_being_forced:
		return false
	
	if not is_fire_door_open:
		if is_fire_door_locked and not player_inside_antecamara:
			if sfx_locked_rattle:
				sfx_locked_rattle.play()
			if anomaly_type == AnomalyType.DOOR_WINDOW_WATCHER or anomaly_type == AnomalyType.HANDS_ON_DOOR:
				if sfx_door_bang:
					sfx_door_bang.play()
			return false
		
		is_fire_door_open = true
		fire_door_target_angle = deg_to_rad(-82.0)
		if sfx_door_creak_shut:
			sfx_door_creak_shut.pitch_scale = 1.08
			sfx_door_creak_shut.play()
		return true
	else:
		is_fire_door_open = false
		fire_door_target_angle = 0.0
		if sfx_door_creak_shut:
			sfx_door_creak_shut.pitch_scale = 0.94
			sfx_door_creak_shut.play()
		
		var player = get_tree().get_first_node_in_group("player") as Node3D
		if player and to_local(player.global_position).z > 2.45:
			player_inside_antecamara = true
			antecamara_linger_timer = 0.0
			back_door_stage = 0
		return true

func _process(delta: float) -> void:
	_update_fire_door_swing(delta)
	_update_presence_sensors_by_motion(delta)
	_update_light_timers_and_flicker(delta)
	_update_antecamara_back_door_tension(delta)
	_update_anomalies_runtime(delta)
	_update_upper_stalker_motion(delta)

func _update_fire_door_swing(delta: float) -> void:
	if not fire_door_pivot:
		return
	if is_door_being_forced:
		# Door shudders violently while Pursuer pushes against it!
		var t_sec = Time.get_ticks_msec() * 0.001
		fire_door_pivot.rotation.y = deg_to_rad(sin(t_sec * 52.0) * 2.2)
		door_force_audio_timer -= delta
		if door_force_audio_timer <= 0.0:
			door_force_audio_timer = 0.95
			if sfx_door_force_push:
				sfx_door_force_push.pitch_scale = randf_range(0.92, 1.08)
				sfx_door_force_push.play()
		return
	
	if anomaly_type == AnomalyType.HANDS_ON_DOOR and not is_fire_door_open and not door_closing_anim:
		return
	
	fire_door_pivot.rotation.y = move_toward(fire_door_pivot.rotation.y, fire_door_target_angle, delta * deg_to_rad(165.0))
	if fire_door_col_body:
		fire_door_col_body.process_mode = Node.PROCESS_MODE_DISABLED if is_fire_door_open else Node.PROCESS_MODE_INHERIT

func _update_antecamara_back_door_tension(delta: float) -> void:
	if is_ground_floor:
		return
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	
	var local_p = to_local(player.global_position)
	var in_room = (local_p.z > 2.48 and local_p.z < 5.6 and abs(local_p.x) < 1.8 and abs(local_p.y - 1.0) < 1.8)
	
	if not in_room:
		player_inside_antecamara = false
		antecamara_linger_timer = 0.0
		back_door_stage = 0
		if back_door_handle_pivot:
			back_door_handle_pivot.rotation.z = move_toward(back_door_handle_pivot.rotation.z, 0.0, delta * 3.0)
		return
	
	player_inside_antecamara = true
	
	# NEVER tick or trigger the back-door event while the Pursuer is active anywhere in the building!
	if pause_back_door_timer or is_door_being_forced or is_fire_door_open:
		antecamara_linger_timer = 0.0
		back_door_stage = 0
		return
	
	# Slow, natural escalation when lingering in the empty room:
	# - 0..9s: Complete heavy silence.
	# - 9.0s: Soft, slow "tok... tok... tok..." on the back door.
	# - 15.0s: Second, slightly closer "tok... tok... tok...".
	# - 20.0s: The back door handle visibly turns downward with a metallic creak/clack!
	# - 24.5s: The back door unlocks and opens -> 3D Back-Door Death!
	antecamara_linger_timer += delta
	
	if antecamara_linger_timer > 9.0 and back_door_stage == 0:
		back_door_stage = 1
		if sfx_back_door_tok:
			sfx_back_door_tok.volume_db = -3.0
			sfx_back_door_tok.pitch_scale = 0.96
			sfx_back_door_tok.play()
	elif antecamara_linger_timer > 15.0 and back_door_stage == 1:
		back_door_stage = 2
		if sfx_back_door_tok:
			sfx_back_door_tok.volume_db = 1.5
			sfx_back_door_tok.pitch_scale = 1.04
			sfx_back_door_tok.play()
	elif antecamara_linger_timer > 20.0 and back_door_stage == 2:
		back_door_stage = 3
		back_door_handle_turn_anim = 1.0
		if sfx_back_door_handle:
			sfx_back_door_handle.play()
		if antecamara_light:
			antecamara_light.light_energy = 0.14
	elif antecamara_linger_timer > 24.5 and back_door_stage == 3:
		back_door_stage = 4
		if back_corridor_door_pivot:
			back_corridor_door_pivot.rotation.y = deg_to_rad(-55.0)
		back_door_kill.emit(floor_index, to_global(Vector3(0.0, 1.35, 5.3)))
	
	if back_door_handle_turn_anim > 0.0 and back_door_handle_pivot:
		back_door_handle_turn_anim = max(0.0, back_door_handle_turn_anim - delta * 0.8)
		back_door_handle_pivot.rotation.z = deg_to_rad(-32.0 * sin(back_door_handle_turn_anim * PI))

func _update_presence_sensors_by_motion(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return
	
	var local_pos = to_local(player.global_position)
	# Ignore players far away vertically (on other floors)
	if local_pos.y > 2.45 or local_pos.y < -4.2:
		return
	
	# If player is closed inside Antecâmara, they do NOT trigger the outside stairwell sensor!
	if local_pos.z > 2.45 and not is_fire_door_open:
		return
	
	# Track that the player physically visited this floor
	if local_pos.y > -3.6 and local_pos.y < 1.2:
		was_visited_by_player = true
	
	var player_speed = Vector2(player.velocity.x, player.velocity.z).length()
	var is_moving = player_speed > 0.22
	
	# Main Landing Sensor Zone
	var in_main_zone = (local_pos.y > -1.25 and local_pos.y < 2.2 and local_pos.z > -2.25 and local_pos.z <= 2.45)
	if in_main_zone:
		if is_moving:
			if main_light_on:
				main_light_timer = SENSOR_STAY_ON_TIME
				main_motion_delay_accum = 0.0
			else:
				main_motion_delay_accum += delta
				_pulse_sensor_led(main_led_mesh, true)
				if main_motion_delay_accum >= SENSOR_RETRIGGER_DELAY:
					main_motion_delay_accum = 0.0
					trigger_main_sensor(SENSOR_STAY_ON_TIME, false)
		else:
			main_motion_delay_accum = max(0.0, main_motion_delay_accum - delta * 0.5)
			_pulse_sensor_led(main_led_mesh, false)
	
	if is_ground_floor:
		return
	
	# Mid Landing Sensor Zone
	var in_mid_zone = (local_pos.y > -3.85 and local_pos.y < -0.8 and local_pos.z > -8.9 and local_pos.z < -3.6)
	if in_mid_zone:
		if is_moving:
			if mid_light_on:
				mid_light_timer = SENSOR_STAY_ON_TIME
				mid_motion_delay_accum = 0.0
			else:
				mid_motion_delay_accum += delta
				_pulse_sensor_led(mid_led_mesh, true)
				if mid_motion_delay_accum >= SENSOR_RETRIGGER_DELAY:
					mid_motion_delay_accum = 0.0
					trigger_mid_sensor(SENSOR_STAY_ON_TIME)
		else:
			mid_motion_delay_accum = max(0.0, mid_motion_delay_accum - delta * 0.5)
			_pulse_sensor_led(mid_led_mesh, false)

func _pulse_sensor_led(led: MeshInstance3D, detecting: bool) -> void:
	if not led:
		return
	var mat = led.material_override as StandardMaterial3D
	if mat:
		mat.emission_energy_multiplier = 6.0 if detecting else 1.4

func _update_light_timers_and_flicker(delta: float) -> void:
	var any_turned_off_now = false
	
	if main_light_on:
		if was_visited_by_player:
			was_lit_since_visit = true
		main_light_timer -= delta
		if main_flicker_time > 0.0:
			main_flicker_time -= delta
			var pulse = 1.0 if fmod(main_flicker_time * 32.0, 1.0) > 0.45 else 0.06
			_set_main_light_power(pulse)
		else:
			_set_main_light_power(1.0)
		
		if main_light_timer <= 0.0:
			main_light_on = false
			main_motion_delay_accum = 0.0
			_set_main_light_power(0.0)
			if sfx_click_main:
				sfx_click_main.pitch_scale = 0.80
				sfx_click_main.play()
			if sfx_hum_main:
				sfx_hum_main.stop()
			any_turned_off_now = true
	
	if mid_light_on:
		if was_visited_by_player:
			was_lit_since_visit = true
		mid_light_timer -= delta
		if mid_flicker_time > 0.0:
			mid_flicker_time -= delta
			var pulse = 1.0 if fmod(mid_flicker_time * 36.0, 1.0) > 0.48 else 0.04
			_set_mid_light_power(pulse)
		else:
			if anomaly_type == AnomalyType.INVISIBLE_CAST_SHADOW or anomaly_type == AnomalyType.STATIC_DARK_FIGURE:
				var falter = 0.88 if fmod(Time.get_ticks_msec() * 0.007, 1.0) > 0.12 else 0.32
				_set_mid_light_power(falter)
			else:
				_set_mid_light_power(1.0)
		
		if mid_light_timer <= 0.0:
			mid_light_on = false
			mid_motion_delay_accum = 0.0
			_set_mid_light_power(0.0)
			if sfx_click_mid:
				sfx_click_mid.pitch_scale = 0.80
				sfx_click_mid.play()
			if sfx_hum_mid:
				sfx_hum_mid.stop()
			any_turned_off_now = true
	
	# CORE PURIFICATION MECHANIC:
	# If this floor was visited by the player, has an active haunting, and BOTH its lights
	# just went dark (player retreated up to the floor above and waited in the dark!),
	# notify main.gd so this floor can PURIFY (70%) or SWAP to another haunting (30%)!
	if any_turned_off_now and not main_light_on and not mid_light_on and was_visited_by_player and was_lit_since_visit:
		was_lit_since_visit = false
		floor_went_dark_after_visit.emit(floor_index)

func trigger_main_sensor(duration: float = SENSOR_STAY_ON_TIME, instant: bool = false) -> void:
	var was_off = not main_light_on
	main_light_on = true
	main_light_timer = max(main_light_timer, duration)
	if was_off:
		main_flicker_time = 0.05 if instant else 0.34
		if not instant and sfx_click_main:
			sfx_click_main.pitch_scale = 1.0
			sfx_click_main.play()
		if sfx_hum_main and not sfx_hum_main.playing:
			sfx_hum_main.play()

func trigger_mid_sensor(duration: float = SENSOR_STAY_ON_TIME) -> void:
	if is_ground_floor:
		return
	# Anomaly #10: Broken Sensor / Short-Circuit! Sparks once and stays pitch black with breathing below!
	if anomaly_type == AnomalyType.BROKEN_SENSOR_DARK:
		if not broken_sensor_sparked:
			broken_sensor_sparked = true
			if sfx_short_circuit:
				sfx_short_circuit.play()
			if sfx_whisper:
				sfx_whisper.play()
			# Tiny 0.08s spark flash then dead pitch black
			_set_mid_light_power(0.65)
			await get_tree().create_timer(0.08).timeout
			_set_mid_light_power(0.0)
			mid_light_on = false
		return
	
	var was_off = not mid_light_on
	mid_light_on = true
	mid_light_timer = max(mid_light_timer, duration)
	if was_off:
		mid_flicker_time = 0.44
		if sfx_click_mid:
			sfx_click_mid.pitch_scale = 1.0
			sfx_click_mid.play()
		if sfx_hum_mid and not sfx_hum_mid.playing:
			sfx_hum_mid.play()

func _set_main_light_power(factor: float) -> void:
	if not main_light:
		return
	main_light.visible = (factor > 0.01)
	if anomaly_type == AnomalyType.RED_LIGHT_SHOCK and red_shock_triggered:
		main_light.light_color = Color(1.0, 0.06, 0.04)
		main_light.light_energy = 2.05 * factor
	else:
		main_light.light_color = Color(0.85, 0.93, 0.88) if not is_ground_floor else Color(0.75, 1.0, 0.82)
		main_light.light_energy = 1.55 * factor
	var mat = main_bulb_mesh.material_override as StandardMaterial3D
	if mat:
		mat.emission = main_light.light_color
		mat.emission_energy_multiplier = 2.5 * factor

func _set_mid_light_power(factor: float) -> void:
	if not mid_light:
		return
	mid_light.visible = (factor > 0.01)
	if anomaly_type == AnomalyType.RED_LIGHT_SHOCK and red_shock_triggered:
		mid_light.light_color = Color(1.0, 0.06, 0.04)
		mid_light.light_energy = 2.15 * factor
	else:
		mid_light.light_color = Color(0.84, 0.92, 0.88)
		mid_light.light_energy = 1.45 * factor
	var mat = mid_bulb_mesh.material_override as StandardMaterial3D
	if mat:
		mat.emission = mid_light.light_color
		mat.emission_energy_multiplier = 2.5 * factor

func _build_architecture_and_antecamara() -> void:
	var concrete_mat = StandardMaterial3D.new()
	concrete_mat.albedo_texture = ProceduralTextures.get_concrete_texture()
	concrete_mat.uv1_triplanar = true
	concrete_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	concrete_mat.roughness = 0.95
	concrete_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	var step_mat = StandardMaterial3D.new()
	step_mat.albedo_texture = ProceduralTextures.get_step_texture()
	step_mat.uv1_triplanar = true
	step_mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	step_mat.roughness = 0.9
	step_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	var rail_mat = StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.18, 0.20, 0.22)
	rail_mat.metallic = 0.6
	rail_mat.roughness = 0.5
	
	# 1. Outer Stairwell Shaft Walls
	if not is_ground_floor:
		_add_static_box(Vector3(0.2, FLOOR_HEIGHT, 11.6), Vector3(-2.3, -2.4, -3.2), concrete_mat)
		_add_static_box(Vector3(0.2, FLOOR_HEIGHT, 11.6), Vector3(2.3, -2.4, -3.2), concrete_mat)
		_add_static_box(Vector3(4.8, FLOOR_HEIGHT, 0.2), Vector3(0.0, -2.4, -8.9), concrete_mat)
		_add_static_box(Vector3(0.28, FLOOR_HEIGHT, 6.2), Vector3(0.0, -2.4, -3.1), concrete_mat)
		
		# Top Floor (10º Andar) has NO floor above it, so build the upper concrete enclosure walls & ceiling!
		if is_top_floor:
			var top_h = 3.2
			_add_static_box(Vector3(0.2, top_h, 11.6), Vector3(-2.3, top_h * 0.5, -3.2), concrete_mat)
			_add_static_box(Vector3(0.2, top_h, 11.6), Vector3(2.3, top_h * 0.5, -3.2), concrete_mat)
			_add_static_box(Vector3(4.8, top_h, 0.2), Vector3(0.0, top_h * 0.5, -8.9), concrete_mat)
			_add_static_box(Vector3(0.28, top_h, 6.2), Vector3(0.0, top_h * 0.5, -3.1), concrete_mat)
			# Solid concrete wall & floor threshold directly behind the iron security gate on the right side (ZERO floor gap!)
			_add_static_box(Vector3(2.1, top_h, 0.25), Vector3(1.12, top_h * 0.5, -0.22), concrete_mat)
			_add_static_box(Vector3(2.1, 0.25, 0.45), Vector3(1.12, -0.125, -0.15), concrete_mat)
			# Textured concrete ceiling slab above the 10th floor landing & flight
			_add_static_box(Vector3(4.8, 0.25, 11.8), Vector3(0.0, top_h, -3.2), concrete_mat)
			# Upper front wall above doorway lintel (Y from 2.5 to 3.2)
			_add_static_box(Vector3(4.8, 0.9, 0.2), Vector3(0.0, 2.85, 2.5), concrete_mat)
	else:
		# Ground Floor (Térreo) is a closed terminal lobby landing!
		_add_static_box(Vector3(0.2, 3.2, 3.2), Vector3(-2.3, 1.4, 1.1), concrete_mat)
		_add_static_box(Vector3(0.2, 3.2, 3.2), Vector3(2.3, 1.4, 1.1), concrete_mat)
		_add_static_box(Vector3(2.2, 3.2, 0.2), Vector3(-1.12, 1.4, -0.1), concrete_mat)
	
	# 2. Front Wall at Z = +2.5 with real doorway opening
	_add_static_box(Vector3(1.85, FLOOR_HEIGHT, 0.2), Vector3(-1.475, 0.0, 2.5), concrete_mat)
	_add_static_box(Vector3(1.85, FLOOR_HEIGHT, 0.2), Vector3(1.475, 0.0, 2.5), concrete_mat)
	_add_static_box(Vector3(1.1, 0.4, 0.2), Vector3(0.0, 2.3, 2.5), concrete_mat)
	_add_static_box(Vector3(1.1, 2.4, 0.2), Vector3(0.0, -1.2, 2.5), concrete_mat)
	
	fire_door_col_body = StaticBody3D.new()
	fire_door_col_body.position = Vector3(0.0, 1.05, 2.42)
	var fd_col = CollisionShape3D.new()
	var fd_box = BoxShape3D.new()
	fd_box.size = Vector3(1.1, 2.1, 0.14)
	fd_col.shape = fd_box
	fire_door_col_body.add_child(fd_col)
	add_child(fire_door_col_body)
	
	# 3. THE ANTECÂMARA (Empty fire-lock room behind Fire Door: Z from +2.5 to +5.4)
	_add_static_box(Vector3(3.1, 0.25, 3.0), Vector3(0.0, -0.125, 3.95), concrete_mat)
	_add_static_box(Vector3(3.1, 0.2, 3.0), Vector3(0.0, 2.55, 3.95), concrete_mat)
	_add_static_box(Vector3(0.2, 2.6, 3.0), Vector3(-1.45, 1.25, 3.95), concrete_mat)
	_add_static_box(Vector3(0.2, 2.6, 3.0), Vector3(1.45, 1.25, 3.95), concrete_mat)
	_add_static_box(Vector3(3.1, 2.6, 0.2), Vector3(0.0, 1.25, 5.45), concrete_mat)
	
	antecamara_light = OmniLight3D.new()
	antecamara_light.position = Vector3(0.0, 2.3, 3.95)
	antecamara_light.light_color = Color(0.75, 0.55, 0.35) if not is_ground_floor else Color(0.45, 0.95, 0.55)
	antecamara_light.light_energy = 0.36
	antecamara_light.omni_range = 3.6
	antecamara_light.shadow_enabled = false
	add_child(antecamara_light)
	
	# Second Door at the back of the Antecâmara
	back_corridor_door_pivot = Node3D.new()
	back_corridor_door_pivot.position = Vector3(-0.55, 0.0, 5.33)
	add_child(back_corridor_door_pivot)
	
	var back_door_mesh = MeshInstance3D.new()
	var bd_box = BoxMesh.new()
	bd_box.size = Vector3(1.1, 2.1, 0.08)
	back_door_mesh.mesh = bd_box
	back_door_mesh.position = Vector3(0.55, 1.05, 0.0)
	var bd_mat = StandardMaterial3D.new()
	bd_mat.albedo_color = Color(0.14, 0.15, 0.16)
	bd_mat.roughness = 0.85
	bd_mat.metallic = 0.45
	back_door_mesh.material_override = bd_mat
	back_corridor_door_pivot.add_child(back_door_mesh)
	
	# Animated Doorknob Handle Pivot (visibly rotates down when something tries to open it!)
	back_door_handle_pivot = Node3D.new()
	back_door_handle_pivot.position = Vector3(0.98, 1.0, -0.05)
	back_corridor_door_pivot.add_child(back_door_handle_pivot)
	
	var handle_mesh = MeshInstance3D.new()
	var h_box = BoxMesh.new()
	h_box.size = Vector3(0.15, 0.035, 0.09)
	handle_mesh.mesh = h_box
	handle_mesh.position = Vector3(-0.06, 0.0, 0.0)
	handle_mesh.material_override = rail_mat
	back_door_handle_pivot.add_child(handle_mesh)
	
	var back_door_label = Label3D.new()
	back_door_label.position = Vector3(0.55, 1.48, -0.05)
	back_door_label.rotation.y = PI
	back_door_label.pixel_size = 0.0028
	back_door_label.font_size = 22
	back_door_label.modulate = Color(0.75, 0.72, 0.65)
	back_door_label.text = "ACESSO AO ANDAR\n[ TRANCADO ]" if not is_ground_floor else "RUA / SAÍDA"
	back_corridor_door_pivot.add_child(back_door_label)
	
	# 4. Main Landing Platform
	_add_static_box(Vector3(4.4, 0.25, 2.4), Vector3(0.0, -0.125, 1.2), concrete_mat)
	
	if is_ground_floor:
		return
	
	# 5. Mid Landing & 16-step Flights 1 and 2
	_add_static_box(Vector3(4.4, 0.25, 2.4), Vector3(0.0, -2.525, -7.6), concrete_mat)
	
	var step_depth = FLIGHT_RUN / float(NUM_STEPS)
	var step_drop = FLIGHT_DROP / float(NUM_STEPS)
	for i in range(NUM_STEPS):
		var sz = -(float(i) + 0.5) * step_depth
		var sy = -(float(i) + 1.0) * step_drop
		_add_mesh_box(Vector3(1.92, step_drop, step_depth + 0.04), Vector3(-1.12, sy + step_drop * 0.5, sz), step_mat)
	_add_collision_ramp(Vector3(-1.12, -1.2, -3.2), 1.92, FLIGHT_RUN, FLIGHT_DROP, true)
	
	for i in range(NUM_STEPS):
		var sz = -FLIGHT_RUN + (float(i) + 0.5) * step_depth
		var sy = -FLIGHT_DROP - (float(i) + 1.0) * step_drop
		_add_mesh_box(Vector3(1.92, step_drop, step_depth + 0.04), Vector3(1.12, sy + step_drop * 0.5, sz), step_mat)
	_add_collision_ramp(Vector3(1.12, -3.6, -3.2), 1.92, FLIGHT_RUN, FLIGHT_DROP, false)
	
	var rail_len = sqrt(FLIGHT_RUN * FLIGHT_RUN + FLIGHT_DROP * FLIGHT_DROP)
	var rail_box = BoxMesh.new()
	rail_box.size = Vector3(0.06, 0.06, rail_len)
	
	var rail1 = MeshInstance3D.new()
	rail1.mesh = rail_box
	rail1.material_override = rail_mat
	rail1.position = Vector3(-0.22, -0.3, -3.2)
	rail1.rotation.x = atan2(-FLIGHT_DROP, FLIGHT_RUN)
	add_child(rail1)
	
	var rail2 = MeshInstance3D.new()
	rail2.mesh = rail_box
	rail2.material_override = rail_mat
	rail2.position = Vector3(0.22, -2.7, -3.2)
	rail2.rotation.x = atan2(FLIGHT_DROP, FLIGHT_RUN)
	add_child(rail2)

func _build_lights_and_sensors() -> void:
	var main_fixture = Node3D.new()
	main_fixture.position = Vector3(0.0, 2.45, 2.32)
	add_child(main_fixture)
	
	main_bulb_mesh = _create_bulb_fixture(main_fixture)
	main_led_mesh = _create_sensor_box(main_fixture)
	
	main_light = OmniLight3D.new()
	main_light.position = Vector3(0.0, 2.25, 1.85)
	main_light.light_color = Color(0.85, 0.93, 0.88) if not is_ground_floor else Color(0.75, 1.0, 0.82)
	main_light.omni_range = 6.8
	main_light.omni_attenuation = 1.35
	main_light.shadow_enabled = true
	main_light.light_energy = 0.0
	main_light.visible = false
	add_child(main_light)
	
	# Audio routed through Stairwell Reverb & Muffled buses!
	sfx_click_main = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_relay_click(), 6.5, 24.0, "Stairwell", 0.0)
	sfx_hum_main = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_fluorescent_hum(), 3.0, 9.0, "Master", -4.0)
	sfx_door_bang = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_door_bang(), 9.0, 24.0, "Stairwell", 1.0)
	sfx_door_creak_shut = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_door_creak_and_latch(), 8.0, 20.0, "Stairwell", 0.0)
	sfx_door_slam_heavy = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_distant_door_slam(), 14.0, 38.0, "Stairwell", 3.5)
	sfx_door_force_push = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_door_force_push(), 8.0, 18.0, "Stairwell", 2.0)
	sfx_glass_tap_door = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_glass_tap(), 7.0, 16.0, "Stairwell", 0.0)
	sfx_locked_rattle = AudioSynth.create_player_3d(main_fixture, AudioSynth.make_locked_door_rattle(), 6.0, 14.0, "Stairwell", -1.0)
	
	# Back Door Muffled Sounds (behind the inner Antecâmara door!)
	sfx_back_door_tok = AudioSynth.create_player_3d(back_corridor_door_pivot, AudioSynth.make_back_door_tok(), 5.0, 12.0, "Muffled", 0.0)
	sfx_back_door_handle = AudioSynth.create_player_3d(back_corridor_door_pivot, AudioSynth.make_handle_turn(), 5.0, 12.0, "Muffled", 1.5)
	sfx_red_shock = AudioSynth.create_player(self, AudioSynth.make_red_light_shock_sting(), "Scare", 1.5)
	
	if is_ground_floor:
		return
	
	var mid_fixture = Node3D.new()
	mid_fixture.position = Vector3(0.0, 0.05, -8.72)
	add_child(mid_fixture)
	
	mid_bulb_mesh = _create_bulb_fixture(mid_fixture)
	mid_led_mesh = _create_sensor_box(mid_fixture)
	
	mid_light = OmniLight3D.new()
	mid_light.position = Vector3(0.0, -0.15, -8.25)
	mid_light.light_color = Color(0.85, 0.93, 0.88)
	mid_light.omni_range = 6.8
	mid_light.omni_attenuation = 1.35
	mid_light.shadow_enabled = true
	mid_light.light_energy = 0.0
	mid_light.visible = false
	add_child(mid_light)
	
	sfx_click_mid = AudioSynth.create_player_3d(mid_fixture, AudioSynth.make_relay_click(), 6.5, 24.0, "Stairwell", 0.0)
	sfx_hum_mid = AudioSynth.create_player_3d(mid_fixture, AudioSynth.make_fluorescent_hum(), 3.0, 9.0, "Master", -4.0)
	sfx_heavy_stairs = AudioSynth.create_player_3d(mid_fixture, AudioSynth.make_heavy_stair_steps(), 10.0, 26.0, "Stairwell", 1.0)
	sfx_glass_tap_window = AudioSynth.create_player_3d(mid_fixture, AudioSynth.make_glass_tap(), 8.0, 16.0, "Stairwell", 0.5)
	sfx_whisper = AudioSynth.create_player_3d(mid_fixture, AudioSynth.make_whisper_breath(), 7.0, 16.0, "Stairwell", -1.0)
	
	# Soft muffled night rain & wind right at the mid-landing barred window (audible as you descend toward it!)
	var win_rain_anchor = Node3D.new()
	win_rain_anchor.position = Vector3(-0.95, -0.85, -8.75)
	add_child(win_rain_anchor)
	var sfx_win_rain = AudioSynth.create_player_3d(win_rain_anchor, AudioSynth.make_night_rain_window(), 3.8, 11.5, "Muffled", 0.5)
	sfx_win_rain.play()
	sfx_short_circuit = AudioSynth.create_player_3d(mid_fixture, AudioSynth.make_short_circuit_spark(), 7.0, 18.0, "Stairwell", 1.5)
	
	# Lightning flash light & spooky silhouette outside the barred night window!
	lightning_light = OmniLight3D.new()
	lightning_light.position = Vector3(-0.95, -0.75, -8.45)
	lightning_light.light_color = Color(0.68, 0.80, 1.0)
	lightning_light.omni_range = 8.5
	lightning_light.light_energy = 0.0
	lightning_light.visible = false
	add_child(lightning_light)
	
	lightning_silhouette = MeshInstance3D.new()
	var lsq = QuadMesh.new()
	lsq.size = Vector2(0.55, 0.72)
	lightning_silhouette.mesh = lsq
	lightning_silhouette.position = Vector3(-0.95, -0.92, -8.70)
	var ls_mat = StandardMaterial3D.new()
	ls_mat.albedo_texture = ProceduralTextures.get_peeking_face_texture()
	ls_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ls_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	lightning_silhouette.material_override = ls_mat
	lightning_silhouette.visible = false
	add_child(lightning_silhouette)

func _create_bulb_fixture(parent: Node3D) -> MeshInstance3D:
	var housing = MeshInstance3D.new()
	var hbox = BoxMesh.new()
	hbox.size = Vector3(0.95, 0.12, 0.12)
	housing.mesh = hbox
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0.15, 0.15, 0.16)
	housing.material_override = hmat
	parent.add_child(housing)
	
	var bulb = MeshInstance3D.new()
	var bbox = BoxMesh.new()
	bbox.size = Vector3(0.85, 0.07, 0.08)
	bulb.mesh = bbox
	bulb.position = Vector3(0.0, -0.05, 0.0)
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.85, 0.9, 0.88)
	bmat.emission_enabled = true
	bmat.emission = Color(0.84, 0.95, 0.90)
	bmat.emission_energy_multiplier = 0.0
	bulb.material_override = bmat
	parent.add_child(bulb)
	return bulb

func _create_sensor_box(parent: Node3D) -> MeshInstance3D:
	var sbox = MeshInstance3D.new()
	var smesh = BoxMesh.new()
	smesh.size = Vector3(0.1, 0.1, 0.08)
	sbox.mesh = smesh
	sbox.position = Vector3(0.62, 0.0, 0.0)
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0.55, 0.55, 0.52)
	sbox.material_override = smat
	parent.add_child(sbox)
	
	var led = MeshInstance3D.new()
	var lmesh = SphereMesh.new()
	lmesh.radius = 0.016
	lmesh.height = 0.032
	led.mesh = lmesh
	led.position = Vector3(0.62, 0.0, -0.04)
	var lmat = StandardMaterial3D.new()
	lmat.albedo_color = Color(0.9, 0.1, 0.1)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.05, 0.05)
	lmat.emission_energy_multiplier = 1.6
	led.material_override = lmat
	parent.add_child(led)
	return led

func _build_props_and_decorations() -> void:
	fire_door_pivot = Node3D.new()
	fire_door_pivot.position = Vector3(-0.55, 0.0, 2.38)
	add_child(fire_door_pivot)
	
	var dmat = StandardMaterial3D.new()
	dmat.albedo_texture = ProceduralTextures.get_fire_door_texture()
	dmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dmat.roughness = 0.85
	if is_ground_floor:
		dmat.albedo_color = Color(0.4, 0.95, 0.5)
	
	var d_bot = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(1.1, 1.28, 0.08)
	d_bot.mesh = b_box
	d_bot.position = Vector3(0.55, 0.64, 0.0)
	d_bot.material_override = dmat
	fire_door_pivot.add_child(d_bot)
	
	var d_top = MeshInstance3D.new()
	var t_box = BoxMesh.new()
	t_box.size = Vector3(1.1, 0.42, 0.08)
	d_top.mesh = t_box
	d_top.position = Vector3(0.55, 1.89, 0.0)
	d_top.material_override = dmat
	fire_door_pivot.add_child(d_top)
	
	var d_left = MeshInstance3D.new()
	var l_box = BoxMesh.new()
	l_box.size = Vector3(0.41, 0.40, 0.08)
	d_left.mesh = l_box
	d_left.position = Vector3(0.205, 1.48, 0.0)
	d_left.material_override = dmat
	fire_door_pivot.add_child(d_left)
	
	var d_right = MeshInstance3D.new()
	var r_box = BoxMesh.new()
	r_box.size = Vector3(0.41, 0.40, 0.08)
	d_right.mesh = r_box
	d_right.position = Vector3(0.895, 1.48, 0.0)
	d_right.material_override = dmat
	fire_door_pivot.add_child(d_right)
	
	var glass_mesh = MeshInstance3D.new()
	var gbox = BoxMesh.new()
	gbox.size = Vector3(0.28, 0.40, 0.02)
	glass_mesh.mesh = gbox
	glass_mesh.position = Vector3(0.55, 1.48, 0.0)
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.08, 0.12, 0.10, 0.30)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.roughness = 0.25
	glass_mesh.material_override = gmat
	fire_door_pivot.add_child(glass_mesh)
	
	var barmat = StandardMaterial3D.new()
	barmat.albedo_color = Color(0.55, 0.56, 0.58)
	barmat.metallic = 0.85
	barmat.roughness = 0.35
	
	for side_z in [-0.05, 0.05]:
		var bar_mesh = MeshInstance3D.new()
		var bar_box = BoxMesh.new()
		bar_box.size = Vector3(0.85, 0.05, 0.08)
		bar_mesh.mesh = bar_box
		bar_mesh.position = Vector3(0.55, 1.0, side_z)
		bar_mesh.material_override = barmat
		fire_door_pivot.add_child(bar_mesh)
	
	# Floor Number Sign
	var sign_plate = MeshInstance3D.new()
	var sbox = BoxMesh.new()
	sbox.size = Vector3(0.65, 0.45, 0.03)
	sign_plate.mesh = sbox
	sign_plate.position = Vector3(-1.3, 1.55, 2.38)
	var sp_mat = StandardMaterial3D.new()
	sp_mat.albedo_color = Color(0.08, 0.10, 0.09)
	sign_plate.material_override = sp_mat
	add_child(sign_plate)
	
	floor_label = Label3D.new()
	floor_label.position = Vector3(-1.3, 1.55, 2.35)
	floor_label.rotation.y = PI
	floor_label.pixel_size = 0.0045
	floor_label.font_size = 38
	floor_label.outline_size = 6
	floor_label.text = "10º\nANDAR"
	add_child(floor_label)
	
	# Emergency Exit Box & Air Vent Grate
	var exit_box = MeshInstance3D.new()
	var ebox = BoxMesh.new()
	ebox.size = Vector3(0.76, 0.17, 0.04)
	exit_box.mesh = ebox
	exit_box.position = Vector3(1.3, 1.85, 2.38)
	var eb_mat = StandardMaterial3D.new()
	eb_mat.albedo_color = Color(0.05, 0.18, 0.07)
	exit_box.material_override = eb_mat
	add_child(exit_box)
	
	exit_sign_label = Label3D.new()
	exit_sign_label.position = Vector3(1.3, 1.85, 2.35)
	exit_sign_label.rotation.y = PI
	exit_sign_label.pixel_size = 0.0022
	exit_sign_label.font_size = 22
	exit_sign_label.modulate = Color(0.35, 0.95, 0.45)
	exit_sign_label.text = "SAÍDA DE EMERGÊNCIA"
	add_child(exit_sign_label)
	
	var vent_frame = MeshInstance3D.new()
	var vf_box = BoxMesh.new()
	vf_box.size = Vector3(0.55, 0.32, 0.03)
	vent_frame.mesh = vf_box
	vent_frame.position = Vector3(1.3, 2.35, 2.38)
	var vf_mat = StandardMaterial3D.new()
	vf_mat.albedo_color = Color(0.02, 0.02, 0.02)
	vent_frame.material_override = vf_mat
	add_child(vent_frame)
	
	var slat_mat = StandardMaterial3D.new()
	slat_mat.albedo_color = Color(0.22, 0.23, 0.24)
	slat_mat.metallic = 0.5
	for i in range(4):
		var slat = MeshInstance3D.new()
		var sl_box = BoxMesh.new()
		sl_box.size = Vector3(0.50, 0.03, 0.04)
		slat.mesh = sl_box
		slat.position = Vector3(1.3, 2.24 + float(i) * 0.07, 2.37)
		slat.rotation.x = deg_to_rad(25.0)
		slat.material_override = slat_mat
		add_child(slat)
	
	# Extinguisher, Pipe, Poster, Notice Board
	extinguisher_root = Node3D.new()
	extinguisher_root.position = Vector3(1.45, 0.95, 2.28)
	add_child(extinguisher_root)
	
	var red_metal_mat = StandardMaterial3D.new()
	red_metal_mat.albedo_color = Color(0.55, 0.08, 0.06)
	red_metal_mat.roughness = 0.4
	red_metal_mat.metallic = 0.3
	
	var ext_cyl = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.085
	cm.bottom_radius = 0.085
	cm.height = 0.46
	cm.radial_segments = 10
	ext_cyl.mesh = cm
	ext_cyl.material_override = red_metal_mat
	extinguisher_root.add_child(ext_cyl)
	
	var ext_valve = MeshInstance3D.new()
	var vm = CylinderMesh.new()
	vm.top_radius = 0.025
	vm.bottom_radius = 0.035
	vm.height = 0.08
	ext_valve.mesh = vm
	ext_valve.position = Vector3(0.0, 0.26, 0.0)
	ext_valve.material_override = slat_mat
	extinguisher_root.add_child(ext_valve)
	
	var pipe_mesh = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.045
	pm.height = FLOOR_HEIGHT
	pm.radial_segments = 8
	pipe_mesh.mesh = pm
	pipe_mesh.position = Vector3(-2.12, -2.4, 2.28)
	pipe_mesh.material_override = slat_mat
	add_child(pipe_mesh)
	
	safety_poster_mesh = MeshInstance3D.new()
	var pquad = QuadMesh.new()
	pquad.size = Vector2(0.52, 0.76)
	safety_poster_mesh.mesh = pquad
	safety_poster_mesh.position = Vector3(-2.19, 1.45, 1.15)
	safety_poster_mesh.rotation.y = PI * 0.5
	var pmat = StandardMaterial3D.new()
	pmat.albedo_texture = ProceduralTextures.get_poster_normal_texture()
	pmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pmat.roughness = 0.9
	safety_poster_mesh.material_override = pmat
	add_child(safety_poster_mesh)
	
	var board_frame = MeshInstance3D.new()
	var bf_box = BoxMesh.new()
	bf_box.size = Vector3(0.03, 0.58, 0.78)
	board_frame.mesh = bf_box
	board_frame.position = Vector3(2.19, 1.45, 1.15)
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.24, 0.16, 0.10)
	board_frame.material_override = wood_mat
	add_child(board_frame)
	
	notice_board_label = Label3D.new()
	notice_board_label.position = Vector3(2.16, 1.45, 1.15)
	notice_board_label.rotation.y = -PI * 0.5
	notice_board_label.pixel_size = 0.0022
	notice_board_label.font_size = 20
	notice_board_label.modulate = Color(0.85, 0.82, 0.75)
	notice_board_label.text = "AVISO AOS MORADORES\n\nViu algo no andar?\nVolte ao andar de cima\ne espere a luz apagar."
	add_child(notice_board_label)
	
	# 5. NEW LIVED-IN BUILDING DECORATIONS (Gives life & visual landmarks to every floor!)
	# 5a. Yellow "CUIDADO / PISO MOLHADO" Caution A-Frame Sign in corner of Main Landing (tips over in Anomaly #7!)
	wet_floor_sign_root = Node3D.new()
	wet_floor_sign_root.position = Vector3(-1.75, 0.0, 2.0)
	wet_floor_sign_root.rotation.y = deg_to_rad(32.0)
	add_child(wet_floor_sign_root)
	
	var yellow_mat = StandardMaterial3D.new()
	yellow_mat.albedo_color = Color(0.76, 0.62, 0.08)
	yellow_mat.roughness = 0.65
	for side_a in [-1.0, 1.0]:
		var panel = MeshInstance3D.new()
		var pbox = BoxMesh.new()
		pbox.size = Vector3(0.28, 0.56, 0.02)
		panel.mesh = pbox
		panel.position = Vector3(0.0, 0.27, side_a * 0.08)
		panel.rotation.x = deg_to_rad(-side_a * 16.0)
		panel.material_override = yellow_mat
		wet_floor_sign_root.add_child(panel)
	
	# 5b. Small Metal Trash Bin in corner opposite the caution sign
	var bin_mesh = MeshInstance3D.new()
	var bin_cyl = CylinderMesh.new()
	bin_cyl.top_radius = 0.16
	bin_cyl.bottom_radius = 0.13
	bin_cyl.height = 0.42
	bin_cyl.radial_segments = 10
	bin_mesh.mesh = bin_cyl
	bin_mesh.position = Vector3(1.88, 0.21, 2.08)
	bin_mesh.material_override = slat_mat
	add_child(bin_mesh)
	
	# 5b2. Red Wall Emergency Intercom Box (Interfone de Emergência) on Main Landing Left Wall
	intercom_anchor = Node3D.new()
	intercom_anchor.position = Vector3(-2.16, 1.32, 2.02)
	add_child(intercom_anchor)
	
	var intercom = MeshInstance3D.new()
	var ic_box = BoxMesh.new()
	ic_box.size = Vector3(0.08, 0.26, 0.18)
	intercom.mesh = ic_box
	intercom.material_override = red_metal_mat
	intercom_anchor.add_child(intercom)
	
	sfx_intercom_ring = AudioSynth.create_player_3d(intercom_anchor, AudioSynth.make_intercom_ring(), 7.5, 22.0, "Stairwell", 0.5)
	sfx_intercom_static = AudioSynth.create_player_3d(intercom_anchor, AudioSynth.make_intercom_static_voice(), 6.0, 14.0, "Stairwell", 2.0)
	
	# 5b3. Per-Floor Unique Lived-In Narrative Props (makes each floor visually distinct!)
	_build_per_floor_narrative_props(slat_mat, wood_mat)
	
	# 5b4. Enigmatic Clue Labels (Hidden until main.gd places the 4 run clues!)
	_build_clue_label_anchors()
	
	if is_ground_floor:
		# Build the 4-Digit Keypad Box & Symbol Order Plaque right next to the Térreo exit door!
		var kp_box = MeshInstance3D.new()
		var kpm = BoxMesh.new()
		kpm.size = Vector3(0.18, 0.26, 0.06)
		kp_box.mesh = kpm
		kp_box.position = Vector3(0.75, 1.32, 2.38)
		kp_box.material_override = slat_mat
		add_child(kp_box)
		
		var order_note = Label3D.new()
		order_note.position = Vector3(1.32, 1.35, 2.35)
		order_note.rotation.y = PI
		order_note.pixel_size = 0.0025
		order_note.font_size = 24
		order_note.modulate = Color(0.92, 0.86, 0.72)
		order_note.text = "SENHA DO TÉRREO\n\n1º: ◈    2º: ✕\n3º: ☾    4º: ▲\n\n(Procure os símbolos\npelos andares acima)"
		add_child(order_note)
		return
	
	# 5c. Directional "↓ SAÍDA" Sign on the Center Concrete Divider Pillar facing Flight 1 (flips UP in Anomaly #7!)
	var arrow_plate = MeshInstance3D.new()
	var ap_box = BoxMesh.new()
	ap_box.size = Vector3(0.32, 0.22, 0.03)
	arrow_plate.mesh = ap_box
	arrow_plate.position = Vector3(-0.15, 0.95, -0.02)
	arrow_plate.rotation.y = -PI * 0.5
	var ap_mat = StandardMaterial3D.new()
	ap_mat.albedo_color = Color(0.06, 0.22, 0.10)
	arrow_plate.material_override = ap_mat
	add_child(arrow_plate)
	
	arrow_sign_label = Label3D.new()
	arrow_sign_label.position = Vector3(-0.17, 0.95, -0.02)
	arrow_sign_label.rotation.y = -PI * 0.5
	arrow_sign_label.pixel_size = 0.0028
	arrow_sign_label.font_size = 26
	arrow_sign_label.modulate = Color(0.42, 0.95, 0.50)
	arrow_sign_label.text = "↓ SAÍDA"
	add_child(arrow_sign_label)
	
	# 5d. Second Poster (Evacuation Stick-Figure Diagram) on the Mid-Landing Left Wall (warps in Anomaly #7!)
	evac_poster_mesh = MeshInstance3D.new()
	var ep_quad = QuadMesh.new()
	ep_quad.size = Vector2(0.56, 0.70)
	evac_poster_mesh.mesh = ep_quad
	evac_poster_mesh.position = Vector3(-2.19, -1.0, -7.45)
	evac_poster_mesh.rotation.y = PI * 0.5
	var ep_mat = StandardMaterial3D.new()
	ep_mat.albedo_texture = ProceduralTextures.get_evac_poster_normal()
	ep_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ep_mat.roughness = 0.9
	evac_poster_mesh.material_override = ep_mat
	add_child(evac_poster_mesh)
	
	# 5e. Wall-Mounted Red Fire Hose Cabinet (Caixa de Hidrante) on Mid-Landing Right Wall
	var hose_box = MeshInstance3D.new()
	var hb_mesh = BoxMesh.new()
	hb_mesh.size = Vector3(0.14, 0.72, 0.62)
	hose_box.mesh = hb_mesh
	hose_box.position = Vector3(2.13, -1.12, -7.55)
	hose_box.material_override = red_metal_mat
	add_child(hose_box)
	
	var hose_glass = MeshInstance3D.new()
	var hg_mesh = BoxMesh.new()
	hg_mesh.size = Vector3(0.02, 0.46, 0.42)
	hose_glass.mesh = hg_mesh
	hose_glass.position = Vector3(2.05, -1.12, -7.55)
	var hg_mat = StandardMaterial3D.new()
	hg_mat.albedo_color = Color(0.05, 0.06, 0.07, 0.75)
	hg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hose_glass.material_override = hg_mat
	add_child(hose_glass)
	
	# 5f. Electrical Fuse Box (Quadro de Luz) with status LED on Mid-Landing Back Wall (Right of Window)
	var fuse_box = MeshInstance3D.new()
	var fb_mesh = BoxMesh.new()
	fb_mesh.size = Vector3(0.48, 0.62, 0.12)
	fuse_box.mesh = fb_mesh
	fuse_box.position = Vector3(1.15, -1.05, -8.74)
	fuse_box.material_override = slat_mat
	add_child(fuse_box)
	
	fuse_box_led_mesh = MeshInstance3D.new()
	var fl_sph = SphereMesh.new()
	fl_sph.radius = 0.018
	fl_sph.height = 0.036
	fuse_box_led_mesh.mesh = fl_sph
	fuse_box_led_mesh.position = Vector3(1.28, -0.84, -8.67)
	var fl_mat = StandardMaterial3D.new()
	fl_mat.albedo_color = Color(0.15, 0.9, 0.25)
	fl_mat.emission_enabled = true
	fl_mat.emission = Color(0.15, 0.95, 0.25)
	fl_mat.emission_energy_multiplier = 2.0
	fuse_box_led_mesh.material_override = fl_mat
	add_child(fuse_box_led_mesh)
	
	# Mid-Landing High Grimy Night Window with metal bars (Z = -8.8)
	var win_frame = MeshInstance3D.new()
	var wf_box = BoxMesh.new()
	wf_box.size = Vector3(1.25, 1.15, 0.08)
	win_frame.mesh = wf_box
	win_frame.position = Vector3(-0.95, -0.85, -8.78)
	var wf_mat = StandardMaterial3D.new()
	wf_mat.albedo_color = Color(0.12, 0.13, 0.14)
	win_frame.material_override = wf_mat
	add_child(win_frame)
	
	var win_glass = MeshInstance3D.new()
	var wg_box = BoxMesh.new()
	wg_box.size = Vector3(1.12, 1.02, 0.09)
	win_glass.mesh = wg_box
	win_glass.position = Vector3(-0.95, -0.85, -8.78)
	var wg_mat = StandardMaterial3D.new()
	wg_mat.albedo_color = Color(0.015, 0.02, 0.035)
	wg_mat.roughness = 0.15
	wg_mat.metallic = 0.75
	win_glass.material_override = wg_mat
	add_child(win_glass)
	
	for bx in [-1.25, -0.95, -0.65]:
		var wbar = MeshInstance3D.new()
		var wb_cyl = CylinderMesh.new()
		wb_cyl.top_radius = 0.014
		wb_cyl.bottom_radius = 0.014
		wb_cyl.height = 1.08
		wbar.mesh = wb_cyl
		wbar.position = Vector3(bx, -0.85, -8.73)
		wbar.material_override = slat_mat
		add_child(wbar)

func _build_anomaly_containers() -> void:
	anomaly_root = Node3D.new()
	add_child(anomaly_root)
	if is_ground_floor:
		return
	
	var pitch_black_mat = StandardMaterial3D.new()
	pitch_black_mat.albedo_color = Color(0.012, 0.012, 0.015)
	pitch_black_mat.roughness = 1.0
	
	var fmat = StandardMaterial3D.new()
	fmat.albedo_texture = ProceduralTextures.get_peeking_face_texture()
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	var hmat = StandardMaterial3D.new()
	hmat.albedo_texture = ProceduralTextures.get_handprint_texture()
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# 1. Door Window Watcher
	door_watcher_node = Node3D.new()
	door_watcher_node.position = Vector3(0.55, 1.48, 0.06)
	fire_door_pivot.add_child(door_watcher_node)
	
	door_watcher_face = MeshInstance3D.new()
	var dw_quad = QuadMesh.new()
	dw_quad.size = Vector2(0.24, 0.30)
	door_watcher_face.mesh = dw_quad
	door_watcher_face.rotation.y = PI
	door_watcher_face.material_override = fmat
	door_watcher_node.add_child(door_watcher_face)
	
	door_watcher_light = OmniLight3D.new()
	door_watcher_light.light_color = Color(0.55, 0.65, 0.58)
	door_watcher_light.light_energy = 0.32
	door_watcher_light.omni_range = 0.55
	door_watcher_light.position = Vector3(0.0, 0.04, 0.05)
	door_watcher_node.add_child(door_watcher_light)
	
	# 2. Interactive Dark Figure on Mid-Landing
	vulto_node = Node3D.new()
	vulto_node.position = Vector3(0.85, -2.4, -7.25)
	vulto_node.rotation.y = deg_to_rad(-25.0)
	anomaly_root.add_child(vulto_node)
	
	var v_parts = build_articulated_dark_figure(vulto_node, pitch_black_mat)
	vulto_head = v_parts["head"]
	vulto_arm_l = v_parts["arm_l"]
	vulto_arm_r = v_parts["arm_r"]
	vulto_leg_l = v_parts["leg_l"]
	vulto_leg_r = v_parts["leg_r"]
	
	# 3. Hands on Ajar Door
	hands_node = Node3D.new()
	fire_door_pivot.add_child(hands_node)
	
	var hand_quad = MeshInstance3D.new()
	var qmesh = QuadMesh.new()
	qmesh.size = Vector2(0.20, 0.28)
	hand_quad.mesh = qmesh
	hand_quad.position = Vector3(0.55, 1.46, -0.02)
	hand_quad.rotation.y = PI
	hand_quad.material_override = hmat
	hands_node.add_child(hand_quad)
	
	door_peeking_face = MeshInstance3D.new()
	var fquad = QuadMesh.new()
	fquad.size = Vector2(0.18, 0.23)
	door_peeking_face.mesh = fquad
	door_peeking_face.position = Vector3(0.53, 1.47, 0.04)
	door_peeking_face.rotation.y = PI
	door_peeking_face.material_override = fmat
	hands_node.add_child(door_peeking_face)
	
	door_hand_top = _build_3d_grasping_hand(Vector3(1.06, 1.24, -0.04))
	hands_node.add_child(door_hand_top)
	door_hand_bot = _build_3d_grasping_hand(Vector3(1.06, 0.78, -0.04))
	hands_node.add_child(door_hand_bot)
	
	# 4. Invisible Cast 3D Shadow
	phantom_shadow_node = Node3D.new()
	phantom_shadow_node.position = Vector3(-0.75, -2.4, -7.65)
	anomaly_root.add_child(phantom_shadow_node)
	_build_shadows_only_human(phantom_shadow_node, pitch_black_mat)
	
	# 5. Haunted Poster & Mid-Landing Window Watcher
	window_watcher_node = Node3D.new()
	window_watcher_node.position = Vector3(-0.95, -0.92, -8.71)
	anomaly_root.add_child(window_watcher_node)
	
	window_face_mesh = MeshInstance3D.new()
	var wf_quad = QuadMesh.new()
	wf_quad.size = Vector2(0.38, 0.46)
	window_face_mesh.mesh = wf_quad
	window_face_mesh.material_override = fmat
	window_watcher_node.add_child(window_face_mesh)
	
	window_hands_l = MeshInstance3D.new()
	var wh_quad = QuadMesh.new()
	wh_quad.size = Vector2(0.24, 0.32)
	window_hands_l.mesh = wh_quad
	window_hands_l.position = Vector3(-0.34, -0.10, 0.01)
	window_hands_l.material_override = hmat
	window_watcher_node.add_child(window_hands_l)
	
	window_hands_r = MeshInstance3D.new()
	window_hands_r.mesh = wh_quad
	window_hands_r.position = Vector3(0.34, -0.05, 0.01)
	window_hands_r.scale.x = -1.0
	window_hands_r.material_override = hmat
	window_watcher_node.add_child(window_hands_r)
	
	# 6. Upper Floor Stalker (activated on the floor ABOVE when anomaly 6 triggers!)
	upper_stalker_node = Node3D.new()
	upper_stalker_node.position = Vector3(-1.12, 0.0, 0.15)
	upper_stalker_node.rotation.y = PI
	upper_stalker_node.visible = false
	add_child(upper_stalker_node)
	
	var u_parts = build_articulated_dark_figure(upper_stalker_node, pitch_black_mat)
	upper_arm_l = u_parts["arm_l"]
	upper_arm_r = u_parts["arm_r"]
	upper_leg_l = u_parts["leg_l"]
	upper_leg_r = u_parts["leg_r"]

static func build_articulated_dark_figure(parent: Node3D, mat: Material) -> Dictionary:
	var torso = MeshInstance3D.new()
	var tcap = CapsuleMesh.new()
	tcap.radius = 0.19
	tcap.height = 0.84
	torso.mesh = tcap
	torso.position = Vector3(0.0, 1.15, 0.0)
	torso.rotation.x = deg_to_rad(8.0)
	torso.material_override = mat
	parent.add_child(torso)
	
	var head_pivot = Node3D.new()
	head_pivot.position = Vector3(0.0, 1.66, 0.03)
	parent.add_child(head_pivot)
	
	var head = MeshInstance3D.new()
	var hsph = SphereMesh.new()
	hsph.radius = 0.13
	hsph.height = 0.28
	head.mesh = hsph
	head.material_override = mat
	head_pivot.add_child(head)
	
	var faint_eye_mat = StandardMaterial3D.new()
	faint_eye_mat.albedo_color = Color(0.78, 0.75, 0.72)
	faint_eye_mat.emission_enabled = true
	faint_eye_mat.emission = Color(0.68, 0.65, 0.62)
	faint_eye_mat.emission_energy_multiplier = 1.1
	faint_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ox in [-0.038, 0.038]:
		var fe = MeshInstance3D.new()
		var fem = SphereMesh.new()
		fem.radius = 0.0075
		fem.height = 0.013
		fe.mesh = fem
		fe.position = Vector3(ox, 0.0, 0.125)
		fe.material_override = faint_eye_mat
		head_pivot.add_child(fe)
	
	var arm_l = _create_limb_pivot(parent, Vector3(-0.23, 1.45, 0.0), 0.70, 0.055, mat)
	var arm_r = _create_limb_pivot(parent, Vector3(0.23, 1.45, 0.0), 0.70, 0.055, mat)
	var leg_l = _create_limb_pivot(parent, Vector3(-0.11, 0.80, 0.0), 0.80, 0.068, mat)
	var leg_r = _create_limb_pivot(parent, Vector3(0.11, 0.80, 0.0), 0.80, 0.068, mat)
	
	return { "head": head_pivot, "arm_l": arm_l, "arm_r": arm_r, "leg_l": leg_l, "leg_r": leg_r }

static func _create_limb_pivot(parent: Node3D, pivot_pos: Vector3, length: float, radius: float, mat: Material) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	var limb = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = radius
	cap.height = length
	limb.mesh = cap
	limb.position = Vector3(0.0, -length * 0.5, 0.0)
	limb.material_override = mat
	pivot.add_child(limb)
	return pivot

func _build_shadows_only_human(parent: Node3D, mat: Material) -> void:
	var torso = MeshInstance3D.new()
	var tcap = CapsuleMesh.new()
	tcap.radius = 0.20
	tcap.height = 0.85
	torso.mesh = tcap
	torso.position = Vector3(0.0, 1.15, 0.0)
	torso.material_override = mat
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(torso)
	
	shadow_caster_head = Node3D.new()
	shadow_caster_head.position = Vector3(0.0, 1.66, 0.0)
	parent.add_child(shadow_caster_head)
	
	var head = MeshInstance3D.new()
	var hsph = SphereMesh.new()
	hsph.radius = 0.135
	hsph.height = 0.29
	head.mesh = hsph
	head.material_override = mat
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow_caster_head.add_child(head)
	
	for sx in [-0.24, 0.24]:
		var arm_pivot = Node3D.new()
		arm_pivot.position = Vector3(sx, 1.45, 0.0)
		parent.add_child(arm_pivot)
		if sx > 0.0:
			shadow_caster_arm_r = arm_pivot
		var arm = MeshInstance3D.new()
		var acap = CapsuleMesh.new()
		acap.radius = 0.055
		acap.height = 0.72
		arm.mesh = acap
		arm.position = Vector3(0.0, -0.32, 0.0)
		arm.material_override = mat
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		arm_pivot.add_child(arm)
	
	for lx in [-0.11, 0.11]:
		var leg = MeshInstance3D.new()
		var lcap = CapsuleMesh.new()
		lcap.radius = 0.07
		lcap.height = 0.82
		leg.mesh = lcap
		leg.position = Vector3(lx, 0.41, 0.0)
		leg.material_override = mat
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		parent.add_child(leg)

func _build_3d_grasping_hand(pos: Vector3) -> Node3D:
	var hroot = Node3D.new()
	hroot.position = pos
	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.52, 0.46, 0.44)
	skin_mat.roughness = 0.9
	var nail_mat = StandardMaterial3D.new()
	nail_mat.albedo_color = Color(0.15, 0.04, 0.04)
	
	for i in range(4):
		var y_off = float(i) * 0.034
		var knuckle = MeshInstance3D.new()
		var kbox = BoxMesh.new()
		kbox.size = Vector3(0.035, 0.024, 0.065)
		knuckle.mesh = kbox
		knuckle.position = Vector3(0.015, y_off, 0.02)
		knuckle.rotation.y = deg_to_rad(-25.0)
		knuckle.material_override = skin_mat
		hroot.add_child(knuckle)
		
		var tip = MeshInstance3D.new()
		var tbox = BoxMesh.new()
		tbox.size = Vector3(0.045, 0.020, 0.03)
		tip.mesh = tbox
		tip.position = Vector3(-0.018, y_off, -0.01)
		tip.rotation.y = deg_to_rad(15.0)
		tip.material_override = skin_mat
		hroot.add_child(tip)
		
		var nail = MeshInstance3D.new()
		var nbox = BoxMesh.new()
		nbox.size = Vector3(0.015, 0.016, 0.015)
		nail.mesh = nbox
		nail.position = Vector3(-0.038, y_off, -0.012)
		nail.material_override = nail_mat
		hroot.add_child(nail)
	return hroot

func _apply_anomaly_state() -> void:
	if is_ground_floor:
		return
	door_watcher_node.visible = (anomaly_type == AnomalyType.DOOR_WINDOW_WATCHER)
	door_watcher_face.position = Vector3.ZERO
	
	vulto_node.visible = (anomaly_type == AnomalyType.STATIC_DARK_FIGURE)
	vulto_node.position = Vector3(0.85, -2.4, -7.25)
	vulto_node.rotation.y = deg_to_rad(-25.0)
	
	hands_node.visible = (anomaly_type == AnomalyType.HANDS_ON_DOOR)
	door_hand_top.visible = true
	door_hand_bot.visible = true
	door_peeking_face.visible = true
	door_peeking_face.position = Vector3(0.53, 1.47, 0.04)
	
	phantom_shadow_node.visible = (anomaly_type == AnomalyType.INVISIBLE_CAST_SHADOW)
	window_watcher_node.visible = (anomaly_type == AnomalyType.HAUNTED_POSTER_WINDOW)
	window_face_mesh.position = Vector3.ZERO
	
	if fire_door_pivot and not is_fire_door_open:
		if anomaly_type == AnomalyType.HANDS_ON_DOOR:
			fire_door_pivot.rotation.y = deg_to_rad(18.0)
			fire_door_target_angle = deg_to_rad(18.0)
		else:
			fire_door_pivot.rotation.y = 0.0
			fire_door_target_angle = 0.0
	
	if safety_poster_mesh:
		var pmat = safety_poster_mesh.material_override as StandardMaterial3D
		if pmat:
			var is_poster_haunted = (anomaly_type == AnomalyType.HAUNTED_POSTER_WINDOW or anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS)
			pmat.albedo_texture = ProceduralTextures.get_poster_haunted_texture() if is_poster_haunted else ProceduralTextures.get_poster_normal_texture()
	
	if evac_poster_mesh:
		var epmat = evac_poster_mesh.material_override as StandardMaterial3D
		if epmat:
			epmat.albedo_texture = ProceduralTextures.get_evac_poster_haunted() if (anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS) else ProceduralTextures.get_evac_poster_normal()
	
	for ep_data in extra_posters:
		var m = ep_data["mesh"] as MeshInstance3D
		if m:
			var mat = m.material_override as StandardMaterial3D
			if mat:
				var is_h = (anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS or anomaly_type == AnomalyType.HAUNTED_POSTER_WINDOW)
				mat.albedo_texture = ep_data["haunted"] if is_h else ep_data["normal"]
	
	if arrow_sign_label:
		if anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS:
			arrow_sign_label.text = "↑ NÃO DESÇA"
			arrow_sign_label.modulate = Color(0.95, 0.22, 0.18)
		else:
			arrow_sign_label.text = "↓ SAÍDA"
			arrow_sign_label.modulate = Color(0.42, 0.95, 0.50)
	
	if wet_floor_sign_root:
		if anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS:
			# Knocked over on its side on the concrete landing!
			wet_floor_sign_root.position = Vector3(-1.55, 0.12, 1.65)
			wet_floor_sign_root.rotation = Vector3(deg_to_rad(82.0), deg_to_rad(55.0), deg_to_rad(15.0))
		else:
			wet_floor_sign_root.position = Vector3(-1.75, 0.0, 2.0)
			wet_floor_sign_root.rotation = Vector3(0.0, deg_to_rad(32.0), 0.0)
	
	if fuse_box_led_mesh:
		var flm = fuse_box_led_mesh.material_override as StandardMaterial3D
		if flm:
			if anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS:
				flm.albedo_color = Color(0.95, 0.1, 0.08)
				flm.emission = Color(1.0, 0.08, 0.05)
				flm.emission_energy_multiplier = 4.5
			else:
				flm.albedo_color = Color(0.15, 0.9, 0.25)
				flm.emission = Color(0.15, 0.95, 0.25)
				flm.emission_energy_multiplier = 2.0
	
	if notice_board_label:
		if anomaly_type == AnomalyType.HAUNTED_POSTER_WINDOW:
			notice_board_label.text = "AVISO AOS MORADORES\n\nNão olhe pela janela\ndo patamar.\nSuba e apague a luz."
		elif anomaly_type == AnomalyType.HAUNTED_DECOR_POSTERS:
			notice_board_label.text = "AVISO AOS MORADORES\n\nOS PÔSTERES ESTÃO\nOLHANDO PARA VOCÊ.\nNÃO DESÇA."
		else:
			notice_board_label.text = _get_story_notice_for_floor(floor_index)

func _get_story_notice_for_floor(f: int) -> String:
	match f:
		10:
			return "COMUNICADO - 10º ANDAR\n\nElevador em manutenção.\nEm caso de apagão, use a\nescada. Térreo com senha."
		9:
			return "AVISO AOS MORADORES\n\nViu algo estranho no andar?\nVolte ao andar de cima\ne espere a luz apagar."
		8:
			return "BILHETE - APTO 802\n\nAlguém subiu a escada às 3h.\nO sensor acendia sozinho,\nmas não tinha ninguém lá."
		7:
			return "MANUTENÇÃO ELÉTRICA\n\nSensores ajustados para\napagar após 4 segundos.\nNão force as portas."
		6:
			return "RECADO RABISCADO\n\nSe a porta de trás da\nantecâmara começar a bater,\nsaia. Não são moradores."
		5:
			return "AVISO DE SEGURANÇA\n\nAlgumas antecâmaras foram\ntrancadas pelo zelador.\nMemorize as abertas."
		4:
			return "ZELADORIA — URGENTE\n\nTranquei o Térreo e mudei\na senha. Espalhei os 4\nsímbolos pelos andares."
		3:
			return "ANOTAÇÃO NA PAREDE\n\nSe ouvir uma porta bater\nforte lá embaixo, corra\ne agache longe do vidro."
		2:
			return "BILHETE RASGADO\n\nEu esqueci o último\nnúmero da senha...\nVou ter que subir de novo."
		1:
			return "1º ANDAR — QUASE LÁ\n\nAbaixo fica o Térreo.\nSem os 4 símbolos, a\nporta não vai abrir."
		0:
			return "PORTARIA — TÉRREO\n\nTrava noturna ativa.\nDigite os 4 dígitos na\nordem dos símbolos."
	return "AVISO AOS MORADORES\n\nMantenha a porta\ncorta-fogo fechada."

func _build_per_floor_narrative_props(metal_mat: Material, wood_mat: Material) -> void:
	# Cardboard Moving Boxes on floors 9, 5, 2
	if floor_index in [9, 5, 2]:
		var box_mat = StandardMaterial3D.new()
		box_mat.albedo_color = Color(0.42, 0.31, 0.19)
		box_mat.roughness = 0.95
		_add_static_box(Vector3(0.46, 0.38, 0.42), Vector3(1.82, 0.19, 1.35), box_mat)
		_add_static_box(Vector3(0.36, 0.30, 0.34), Vector3(1.80, 0.53, 1.38), box_mat)
	
	# Janitor's Mop & Cleaning Bucket on floors 8, 4
	if floor_index in [8, 4]:
		var bucket_mat = StandardMaterial3D.new()
		bucket_mat.albedo_color = Color(0.14, 0.28, 0.45)
		var bucket = MeshInstance3D.new()
		var bcyl = CylinderMesh.new()
		bcyl.top_radius = 0.17
		bcyl.bottom_radius = 0.13
		bcyl.height = 0.34
		bcyl.radial_segments = 10
		bucket.mesh = bcyl
		bucket.position = Vector3(-1.82, 0.17, 0.55)
		bucket.material_override = bucket_mat
		add_child(bucket)
		
		var mop_stick = MeshInstance3D.new()
		var mcyl = CylinderMesh.new()
		mcyl.top_radius = 0.015
		mcyl.bottom_radius = 0.015
		mcyl.height = 1.35
		mop_stick.mesh = mcyl
		mop_stick.position = Vector3(-1.86, 0.72, 0.52)
		mop_stick.rotation.z = deg_to_rad(14.0)
		mop_stick.material_override = wood_mat
		add_child(mop_stick)
	
	# Old Folding Chair leaning against wall on floors 7, 3
	if floor_index in [7, 3]:
		var chair = Node3D.new()
		chair.position = Vector3(1.92, 0.0, 0.62)
		chair.rotation.y = deg_to_rad(-75.0)
		add_child(chair)
		var seat = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(0.42, 0.04, 0.40)
		seat.mesh = sm
		seat.position = Vector3(0.0, 0.45, 0.0)
		seat.material_override = wood_mat
		chair.add_child(seat)
		var back = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.42, 0.46, 0.04)
		back.mesh = bm
		back.position = Vector3(0.0, 0.68, -0.18)
		back.material_override = wood_mat
		chair.add_child(back)
		for lx in [-0.18, 0.18]:
			for lz in [-0.17, 0.17]:
				var leg = MeshInstance3D.new()
				var lm = BoxMesh.new()
				lm.size = Vector3(0.03, 0.45, 0.03)
				leg.mesh = lm
				leg.position = Vector3(lx, 0.225, lz)
				leg.material_override = metal_mat
				chair.add_child(leg)
	
	# Dark Damp Water Puddle under corner pipe drips on lower floors 6, 4, 2, 1
	if floor_index in [6, 4, 2, 1]:
		var puddle = MeshInstance3D.new()
		var pq = QuadMesh.new()
		pq.size = Vector2(0.85, 0.72)
		puddle.mesh = pq
		puddle.position = Vector3(-1.72, 0.008, 1.95)
		puddle.rotation.x = -PI * 0.5
		var pud_mat = StandardMaterial3D.new()
		pud_mat.albedo_color = Color(0.03, 0.04, 0.05, 0.75)
		pud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pud_mat.roughness = 0.08
		pud_mat.metallic = 0.5
		puddle.material_override = pud_mat
		add_child(puddle)
	
	# Varied Extra Retro Posters per floor (some floors have 3-4 posters clustered along walls, others fewer!)
	if not is_ground_floor:
		# Left wall going down Flight 1 (floors 9, 7, 5, 3, 1 get a Missing Person flyer along the stairs)
		if floor_index in [9, 7, 5, 3, 1]:
			_add_extra_poster(
				Vector3(-2.19, 0.35, -2.55), Vector3(0.0, PI * 0.5, deg_to_rad(-2.5)),
				Vector2(0.46, 0.64),
				ProceduralTextures.get_missing_poster_normal(),
				ProceduralTextures.get_missing_poster_haunted()
			)
		# Main landing left wall beside the first poster (floors 9, 7, 6, 3, 2 get an extra clustered poster!)
		if floor_index in [9, 7, 6, 3, 2]:
			_add_extra_poster(
				Vector3(-2.19, 1.48, 0.45), Vector3(0.0, PI * 0.5, deg_to_rad(3.0)),
				Vector2(0.44, 0.44),
				ProceduralTextures.get_warning_poster_normal(),
				ProceduralTextures.get_warning_poster_haunted()
			)
		# Flight 1 lower left wall (floors 7, 5, 3, 1 get a second portrait poster down the stairs!)
		if floor_index in [7, 5, 3, 1]:
			_add_extra_poster(
				Vector3(-2.19, -0.55, -4.85), Vector3(0.0, PI * 0.5, deg_to_rad(2.0)),
				Vector2(0.48, 0.70),
				ProceduralTextures.get_poster_normal_texture(),
				ProceduralTextures.get_poster_haunted_texture()
			)
		# Mid-landing right wall beside the fire hose box (floors 8, 7, 3, 2 get a Missing Person flyer)
		if floor_index in [8, 7, 3, 2]:
			_add_extra_poster(
				Vector3(2.19, -1.05, -8.25), Vector3(0.0, -PI * 0.5, deg_to_rad(-3.0)),
				Vector2(0.46, 0.64),
				ProceduralTextures.get_missing_poster_normal(),
				ProceduralTextures.get_missing_poster_haunted()
			)

func _add_extra_poster(pos: Vector3, rot: Vector3, sz: Vector2, norm_tex: Texture2D, haunt_tex: Texture2D) -> void:
	var mi = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = sz
	mi.mesh = qm
	mi.position = pos
	mi.rotation = rot
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = norm_tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	extra_posters.append({ "mesh": mi, "normal": norm_tex, "haunted": haunt_tex })

func _build_clue_label_anchors() -> void:
	if is_ground_floor:
		return
	
	var blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_texture = ProceduralTextures.get_blood_wall_splatter_texture()
	blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	blood_mat.roughness = 0.25
	
	var hand_blood_mat = StandardMaterial3D.new()
	hand_blood_mat.albedo_texture = ProceduralTextures.get_handprint_texture()
	hand_blood_mat.albedo_color = Color(0.62, 0.04, 0.03, 0.92)
	hand_blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hand_blood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hand_blood_mat.roughness = 0.25
	
	# 0. WALL_BLOOD: Huge exaggerated dripping blood mural on the mid-landing concrete wall!
	var g_blood = _create_blood_clue_group(
		Vector3(2.17, -1.12, -6.35),
		Vector3(0.0, -PI * 0.5, deg_to_rad(-4.5)),
		Vector2(2.15, 1.55), blood_mat, hand_blood_mat, true
	)
	clue_groups[ClueSpot.WALL_BLOOD] = g_blood["root"]
	clue_text_quads[ClueSpot.WALL_BLOOD] = g_blood["text_quad"]
	
	# 1. ANTECAMARA_INSIDE: Dramatic bloody scrawl across the inner concrete wall of the Antecâmara!
	var g_ante = _create_blood_clue_group(
		Vector3(-1.33, 1.32, 4.05),
		Vector3(0.0, PI * 0.5, deg_to_rad(3.5)),
		Vector2(1.90, 1.38), blood_mat, hand_blood_mat, true
	)
	clue_groups[ClueSpot.ANTECAMARA_INSIDE] = g_ante["root"]
	clue_text_quads[ClueSpot.ANTECAMARA_INSIDE] = g_ante["text_quad"]
	
	# 2. POSTER_NOTE: Bloody scrawl slashed across the wall right below/beside the Safety Poster!
	var g_poster = _create_blood_clue_group(
		Vector3(-2.17, 0.86, 1.15),
		Vector3(0.0, PI * 0.5, deg_to_rad(-3.0)),
		Vector2(1.55, 1.10), blood_mat, hand_blood_mat, false
	)
	clue_groups[ClueSpot.POSTER_NOTE] = g_poster["root"]
	clue_text_quads[ClueSpot.POSTER_NOTE] = g_poster["text_quad"]
	
	# 3. WINDOW_FUSE: Dripping blood smear between the Night Window & Fuse Box on the mid-landing!
	var g_win = _create_blood_clue_group(
		Vector3(0.28, -1.08, -8.76),
		Vector3(0.0, 0.0, deg_to_rad(4.0)),
		Vector2(1.65, 1.22), blood_mat, hand_blood_mat, true
	)
	clue_groups[ClueSpot.WINDOW_FUSE] = g_win["root"]
	clue_text_quads[ClueSpot.WINDOW_FUSE] = g_win["text_quad"]

func _create_blood_clue_group(pos: Vector3, rot: Vector3, smear_size: Vector2, blood_mat: Material, hand_mat: Material, add_handprints: bool) -> Dictionary:
	var root = Node3D.new()
	root.position = pos
	root.rotation = rot
	root.visible = false
	add_child(root)
	
	# Huge dripping blood smear backdrop on the wall
	var smear = MeshInstance3D.new()
	var sq = QuadMesh.new()
	sq.size = smear_size
	smear.mesh = sq
	smear.position = Vector3(0.0, -0.08, 0.0)
	smear.material_override = blood_mat
	root.add_child(smear)
	
	# Bloody handprints stamped frantically beside the scrawled clue
	if add_handprints:
		for hx in [-smear_size.x * 0.38, smear_size.x * 0.38]:
			var hp = MeshInstance3D.new()
			var hq = QuadMesh.new()
			hq.size = Vector2(0.32, 0.42)
			hp.mesh = hq
			hp.position = Vector3(hx, -0.22 if hx < 0.0 else 0.16, 0.005)
			hp.rotation.z = deg_to_rad(18.0 if hx < 0.0 else -22.0)
			hp.material_override = hand_mat
			root.add_child(hp)
	
	# Hand-painted trembling blood calligraphy Quad (ZERO clean computer fonts!)
	var text_quad = MeshInstance3D.new()
	var tq = QuadMesh.new()
	tq.size = Vector2(smear_size.x * 0.96, smear_size.y * 0.88)
	text_quad.mesh = tq
	text_quad.position = Vector3(0.0, 0.04, 0.012)
	root.add_child(text_quad)
	
	return { "root": root, "text_quad": text_quad }

func _update_anomalies_runtime(delta: float) -> void:
	if is_ground_floor:
		return
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	
	var local_p = to_local(player.global_position)
	# Only animate/trigger anomalies or clue discovery when player is physically on this floor!
	if local_p.y > 2.0 or local_p.y < -4.5:
		return
	
	# Auto-discover blood clue for the [TAB] Notebook when player walks close to it!
	if active_clue_spot != -1 and not clue_discovered_already and clue_groups.has(active_clue_spot):
		var grp = clue_groups[active_clue_spot] as Node3D
		if grp.visible and local_p.distance_to(grp.position) < 2.35:
			clue_discovered_already = true
			clue_discovered.emit(active_clue_symbol, active_clue_phrase)
	
	if anomaly_type == AnomalyType.NONE:
		return
	
	var t_sec = Time.get_ticks_msec() * 0.001
	
	# 1. Door Window Watcher
	if anomaly_type == AnomalyType.DOOR_WINDOW_WATCHER:
		door_watcher_face.position.y = sin(t_sec * 2.4) * 0.015
		door_watcher_face.rotation.z = sin(t_sec * 1.6) * 0.08
		var dist_to_door = local_p.distance_to(Vector3(0.0, 1.0, 2.3))
		if not anomaly_triggered_action and (dist_to_door < 1.55 or local_p.z < -0.25):
			anomaly_triggered_action = true
			if sfx_glass_tap_door:
				sfx_glass_tap_door.play()
		if anomaly_triggered_action and not secondary_interaction_done and local_p.z < -2.0:
			secondary_interaction_done = true
			if sfx_door_bang:
				sfx_door_bang.play()
		if secondary_interaction_done:
			door_watcher_face.position.y = move_toward(door_watcher_face.position.y, -0.32, delta * 1.1)
			if door_watcher_face.position.y <= -0.28:
				door_watcher_node.visible = false
	
	# 2. Interactive Dark Figure on Mid-Landing
	if anomaly_type == AnomalyType.STATIC_DARK_FIGURE and vulto_node.visible:
		if not vulto_walking_down:
			if vulto_head:
				vulto_head.rotation.z = deg_to_rad(sin(t_sec * 1.5) * 10.0)
			if (local_p.z < -3.0 or mid_light_on) and not anomaly_triggered_action:
				anomaly_triggered_action = true
				vulto_walking_down = true
				if sfx_heavy_stairs:
					sfx_heavy_stairs.play()
		else:
			vulto_node.rotation.y = lerp_angle(vulto_node.rotation.y, 0.0, delta * 8.0)
			vulto_node.position.x = move_toward(vulto_node.position.x, 1.12, delta * 1.6)
			vulto_node.position.z += delta * 2.25
			if vulto_node.position.z > -6.4:
				var progress = clamp((vulto_node.position.z - (-6.4)) / FLIGHT_RUN, 0.0, 1.0)
				vulto_node.position.y = -2.4 - progress * FLIGHT_DROP + abs(sin(t_sec * 14.0)) * 0.04
			var walk_swing = sin(t_sec * 14.0) * 0.65
			vulto_arm_l.rotation.x = walk_swing
			vulto_arm_r.rotation.x = -walk_swing
			vulto_leg_l.rotation.x = -walk_swing
			vulto_leg_r.rotation.x = walk_swing
			if vulto_node.position.z > -1.2:
				vulto_node.visible = false
	
	# 3. Ajar Fire Door that Creaks & Latches Shut
	if anomaly_type == AnomalyType.HANDS_ON_DOOR and not is_fire_door_open:
		if not door_closing_anim:
			var finger_twitch = sin(t_sec * 6.0) * 0.006
			door_hand_top.position.x = 1.06 + finger_twitch
			door_hand_bot.position.x = 1.06 - finger_twitch
			var dist_door = local_p.distance_to(Vector3(0.0, 1.0, 2.3))
			if (local_p.z < -0.45 and local_p.y < 0.5) or dist_door < 1.35:
				door_closing_anim = true
				fire_door_target_angle = 0.0
				if sfx_door_creak_shut:
					sfx_door_creak_shut.play()
		else:
			door_hand_top.visible = false
			door_hand_bot.visible = false
			door_peeking_face.position.y = move_toward(door_peeking_face.position.y, 1.22, delta * 1.2)
			fire_door_pivot.rotation.y = move_toward(fire_door_pivot.rotation.y, 0.0, delta * deg_to_rad(29.0))
	
	# 4. Invisible Cast Shadow
	if anomaly_type == AnomalyType.INVISIBLE_CAST_SHADOW:
		if shadow_caster_head:
			shadow_caster_head.rotation.z = deg_to_rad(sin(t_sec * 1.4) * 18.0)
		if shadow_caster_arm_r:
			shadow_caster_arm_r.rotation.z = deg_to_rad(12.0 + sin(t_sec * 1.1) * 10.0)
		if not anomaly_triggered_action and local_p.z < -3.5:
			anomaly_triggered_action = true
			if sfx_whisper:
				sfx_whisper.play()
	
	# 5. Haunted Poster & Mid-Landing Window Watcher
	if anomaly_type == AnomalyType.HAUNTED_POSTER_WINDOW:
		window_face_mesh.position.y = sin(t_sec * 2.1) * 0.02
		if not anomaly_triggered_action and local_p.z < -3.2:
			anomaly_triggered_action = true
			if sfx_glass_tap_window:
				sfx_glass_tap_window.play()
		if local_p.z < -6.2:
			window_face_mesh.position.y = move_toward(window_face_mesh.position.y, -0.65, delta * 0.85)
	
	# 6. Upper Floor Stalker
	if anomaly_type == AnomalyType.UPPER_FLOOR_STALKER:
		if not upper_stalker_triggered and local_p.z < -1.35 and local_p.y < -0.35:
			upper_stalker_triggered = true
			request_upper_floor_anomaly.emit(floor_index + 1)
	
	# 7. SUDDEN BLOOD-RED LIGHT SHOCK (Luzes acendem vermelho de uma vez com som assustador!)
	if anomaly_type == AnomalyType.RED_LIGHT_SHOCK:
		if not red_shock_triggered and local_p.z < -2.1 and local_p.y < -0.55:
			red_shock_triggered = true
			# Slam BOTH main and mid lights blood-red simultaneously with a sudden horror sting!
			main_light_on = true
			mid_light_on = true
			main_light_timer = 6.5
			mid_light_timer = 6.5
			main_flicker_time = 0.0
			mid_flicker_time = 0.0
			_set_main_light_power(1.0)
			_set_mid_light_power(1.0)
			if sfx_red_shock:
				sfx_red_shock.play()
			if player is PlayerController:
				(player as PlayerController).camera_shake = 0.048
	
	# 8. RINGING RED INTERCOM (Interfone toca sozinho no escuro!)
	if anomaly_type == AnomalyType.RINGING_INTERCOM and not intercom_answered:
		intercom_ring_timer -= delta
		if intercom_ring_timer <= 0.0:
			intercom_ring_timer = 2.6
			if sfx_intercom_ring and not sfx_intercom_ring.playing:
				sfx_intercom_ring.play()
	
	# 7. HAUNTING DEATH TRIGGER ("O Puxão no Breu"):
	# If the player ignores the active haunting on this floor and keeps descending Flight 2
	# past the point of no return (Y < -3.45 on Flight 2), trigger the 3D jumpscare!
	if not haunting_kill_triggered and local_p.y < -3.45 and local_p.x > 0.0:
		haunting_kill_triggered = true
		haunting_ignored_kill.emit(floor_index)

func _update_upper_stalker_motion(delta: float) -> void:
	if not upper_stalker_walking or not upper_stalker_node or not upper_stalker_node.visible:
		return
	var t_sec = Time.get_ticks_msec() * 0.001
	upper_stalker_node.position.z -= delta * 1.95
	var progress = clamp(-upper_stalker_node.position.z / FLIGHT_RUN, 0.0, 1.0)
	upper_stalker_node.position.y = -progress * FLIGHT_DROP + abs(sin(t_sec * 13.0)) * 0.04
	var swing = sin(t_sec * 13.0) * 0.6
	if upper_arm_l:
		upper_arm_l.rotation.x = swing
		upper_arm_r.rotation.x = -swing
		upper_leg_l.rotation.x = -swing
		upper_leg_r.rotation.x = swing
	if upper_stalker_node.position.z < -4.8:
		upper_stalker_walking = false
		upper_stalker_node.visible = false

func _add_static_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var sb = StaticBody3D.new()
	sb.position = pos
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	sb.add_child(col)
	
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	add_child(sb)

func _add_mesh_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi = MeshInstance3D.new()
	mi.position = pos
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	add_child(mi)

func _add_collision_ramp(center_pos: Vector3, width: float, run_z: float, drop_y: float, going_negative_z: bool) -> void:
	var sb = StaticBody3D.new()
	sb.position = center_pos
	var ramp_len = sqrt(run_z * run_z + drop_y * drop_y)
	var angle = atan2(drop_y, run_z)
	sb.rotation.x = -angle if going_negative_z else angle
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(width, 0.2, ramp_len)
	col.shape = box
	sb.add_child(col)
	add_child(sb)
