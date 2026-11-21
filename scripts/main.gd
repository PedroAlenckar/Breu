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

# Ground Floor 4-Digit Keypad / Padlock System
var keypad_overlay: ColorRect
var keypad_display_label: Label
var keypad_status_label: Label
var is_keypad_open: bool = false
var exit_code_digits: Array[int] = [0, 0, 0, 0]
var entered_code: String = ""
var sfx_keypad_beep: AudioStreamPlayer
var sfx_keypad_error: AudioStreamPlayer
var sfx_keypad_unlock: AudioStreamPlayer

# Main Menu, Pause Menu, Crosshair & [TAB] Clue Notebook
var menu_overlay: ColorRect
var menu_title_label: Label
var menu_subtitle_label: Label
var menu_play_btn: Button
var menu_restart_btn: Button
var menu_controls_panel: PanelContainer
var ui_crosshair: ColorRect
var notebook_panel: PanelContainer
var notebook_label: Label
var ui_toast_label: Label
var discovered_clues: Dictionary = {}
var is_notebook_open: bool = false
var is_in_menu: bool = true
var is_game_started: bool = false
var current_vignette: float = 0.55

# Delayed Phantom Footsteps Behind You micro-event
var sfx_phantom_behind: AudioStreamPlayer3D
var sfx_window_face_thud: AudioStreamPlayer
var player_was_moving: bool = false
var phantom_step_cooldown: float = 28.0

# Global Audio & Ambient Soundscape
var sfx_ambient_drone: AudioStreamPlayer
var sfx_bulb_pop: AudioStreamPlayer
var sfx_jumpscare_sting: AudioStreamPlayer
var sfx_wake_pant: AudioStreamPlayer
var sfx_whisper_neck: AudioStreamPlayer
var sfx_heartbeat: AudioStreamPlayer
var sfx_darkness_pressure: AudioStreamPlayer
var sfx_distant_building: AudioStreamPlayer
var sfx_ambient_3d_emitter: AudioStreamPlayer3D
var ambient_oneshot_timer: float = 4.0
var distant_building_timer: float = 9.0
var heartbeat_timer: float = 0.0
var darkness_pressure_level: float = 0.0

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
	_show_menu(false)

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
		seg.floor_index = f
		seg.is_top_floor = (f == TOP_FLOOR)
		seg.is_ground_floor = (f == 0)
		seg.position = Vector3(0.0, -float(TOP_FLOOR - f) * SEGMENT_HEIGHT, 0.0)
		seg.haunting_ignored_kill.connect(_on_haunting_ignored_kill)
		seg.back_door_kill.connect(_on_back_door_kill)
		seg.request_open_keypad.connect(_open_keypad_ui)
		seg.ground_floor_escaped.connect(_on_ground_floor_escaped)
		seg.floor_went_dark_after_visit.connect(_on_floor_went_dark_after_visit)
		seg.request_upper_floor_anomaly.connect(_on_request_upper_floor_anomaly)
		seg.clue_discovered.connect(_on_clue_discovered)
		add_child(seg)
		floors[f] = seg

func _setup_top_floor_security_gate() -> void:
	# Iron security gate ONLY on the 10th floor — flush with the landing edge (Z = 0.02) so there is ZERO floor gap!
	var gate = Node3D.new()
	gate.position = Vector3(1.12, 0.0, 0.02)
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
	
	# 1. Physical 3D Pursuer (Unnaturally tall, long spindly arms, crooked neck, larger stark pale face!)
	pursuer_node = Node3D.new()
	pursuer_node.scale = Vector3(1.0, 1.18, 1.0)
	pursuer_node.visible = false
	add_child(pursuer_node)
	
	var parts = StairwellSegment.build_articulated_dark_figure(pursuer_node, p_mat)
	pursuer_head = parts["head"]
	pursuer_head.rotation.z = deg_to_rad(20.0)
	pursuer_arm_l = parts["arm_l"]
	pursuer_arm_r = parts["arm_r"]
	pursuer_arm_l.scale = Vector3(0.85, 1.28, 0.85)
	pursuer_arm_r.scale = Vector3(0.85, 1.28, 0.85)
	pursuer_leg_l = parts["leg_l"]
	pursuer_leg_r = parts["leg_r"]
	
	var p_face = MeshInstance3D.new()
	var pf_quad = QuadMesh.new()
	pf_quad.size = Vector2(0.28, 0.36)
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
	ui_hint_label.text = "BREU  |  [WASD] Andar  [SHIFT] Correr  [CTRL] Agachar  [E] Interagir  [TAB] Notas  [ESC] Pausa"
	canvas.add_child(ui_hint_label)
	
	# Subtle Center Crosshair Dot (brightens when looking near an interactable!)
	ui_crosshair = ColorRect.new()
	ui_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	ui_crosshair.position = Vector2(-2, -2)
	ui_crosshair.size = Vector2(4, 4)
	ui_crosshair.color = Color(0.85, 0.88, 0.85, 0.30)
	ui_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_crosshair)
	
	# [TAB] Crumpled Paper Clue Notebook Panel (Top-Right)
	notebook_panel = PanelContainer.new()
	notebook_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notebook_panel.position = Vector2(-325, 26)
	notebook_panel.custom_minimum_size = Vector2(300, 195)
	notebook_panel.visible = false
	canvas.add_child(notebook_panel)
	
	notebook_label = Label.new()
	notebook_label.add_theme_font_size_override("font_size", 15)
	notebook_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	notebook_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	notebook_panel.add_child(notebook_label)
	
	# Subtle Bottom-Right Clue Discovery Toast
	ui_toast_label = Label.new()
	ui_toast_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ui_toast_label.position = Vector2(-330, -48)
	ui_toast_label.size = Vector2(310, 32)
	ui_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_toast_label.add_theme_font_size_override("font_size", 16)
	ui_toast_label.add_theme_color_override("font_color", Color(0.88, 0.35, 0.30, 0.0))
	ui_toast_label.text = ""
	canvas.add_child(ui_toast_label)
	
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
	
	_build_keypad_ui(canvas)
	_build_main_and_pause_menu(canvas)

func _build_main_and_pause_menu(canvas: CanvasLayer) -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	canvas.add_child(menu_overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(360, 340)
	vbox.position = Vector2(-180, -170)
	vbox.add_theme_constant_override("separation", 14)
	menu_overlay.add_child(vbox)
	
	menu_title_label = Label.new()
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 56)
	menu_title_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.85))
	menu_title_label.text = "B R E U"
	vbox.add_child(menu_title_label)
	
	menu_subtitle_label = Label.new()
	menu_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle_label.add_theme_font_size_override("font_size", 15)
	menu_subtitle_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.20))
	menu_subtitle_label.text = "10º ANDAR — ESCADA DE EMERGÊNCIA"
	vbox.add_child(menu_subtitle_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer)
	
	menu_play_btn = Button.new()
	menu_play_btn.text = "JOGAR"
	menu_play_btn.custom_minimum_size = Vector2(0, 48)
	menu_play_btn.add_theme_font_size_override("font_size", 22)
	menu_play_btn.pressed.connect(_on_menu_play_pressed)
	vbox.add_child(menu_play_btn)
	
	menu_restart_btn = Button.new()
	menu_restart_btn.text = "REINICIAR (10º ANDAR)"
	menu_restart_btn.custom_minimum_size = Vector2(0, 42)
	menu_restart_btn.add_theme_font_size_override("font_size", 18)
	menu_restart_btn.visible = false
	menu_restart_btn.pressed.connect(_on_menu_restart_pressed)
	vbox.add_child(menu_restart_btn)
	
	var controls_btn = Button.new()
	controls_btn.text = "CONTROLES E SOBREVIVÊNCIA"
	controls_btn.custom_minimum_size = Vector2(0, 42)
	controls_btn.add_theme_font_size_override("font_size", 17)
	controls_btn.pressed.connect(func():
		if menu_controls_panel:
			menu_controls_panel.visible = not menu_controls_panel.visible
	)
	vbox.add_child(controls_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "SAIR"
	quit_btn.custom_minimum_size = Vector2(0, 42)
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)
	
	# Expandable Controls & Survival Briefing Panel
	menu_controls_panel = PanelContainer.new()
	menu_controls_panel.visible = false
	vbox.add_child(menu_controls_panel)
	
	var clbl = Label.new()
	clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clbl.add_theme_font_size_override("font_size", 14)
	clbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.80))
	clbl.text = "[WASD] Andar   |   [SHIFT] Correr   |   [CTRL] Agachar\n[E] Porta / Interfone   |   [TAB] Notas   |   [ESC] Pausar\n\n• Viu algo errado? Volte ao andar de cima e espere a luz apagar.\n• Ouviu passos subindo? Esconda-se numa antecâmara.\n• Descubra os 4 símbolos para destravar o Térreo."
	menu_controls_panel.add_child(clbl)
	
	# QoL Sliders: Mouse Sensitivity & Master Volume
	var settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 4)
	vbox.add_child(settings_box)
	
	var sens_lbl = Label.new()
	sens_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sens_lbl.add_theme_font_size_override("font_size", 13)
	sens_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.74))
	sens_lbl.text = "SENSIBILIDADE DO MOUSE"
	settings_box.add_child(sens_lbl)
	
	var sens_slider = HSlider.new()
	sens_slider.min_value = 0.0010
	sens_slider.max_value = 0.0055
	sens_slider.step = 0.0002
	sens_slider.value = 0.0026
	sens_slider.value_changed.connect(func(v):
		if player:
			player.mouse_sensitivity = v
	)
	settings_box.add_child(sens_slider)
	
	var vol_lbl = Label.new()
	vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_lbl.add_theme_font_size_override("font_size", 13)
	vol_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.74))
	vol_lbl.text = "VOLUME GERAL"
	settings_box.add_child(vol_lbl)
	
	var vol_slider = HSlider.new()
	vol_slider.min_value = -24.0
	vol_slider.max_value = 6.0
	vol_slider.step = 0.5
	vol_slider.value = 0.0
	vol_slider.value_changed.connect(func(v):
		AudioServer.set_bus_volume_db(0, v)
	)
	settings_box.add_child(vol_slider)

func _show_menu(is_pause: bool) -> void:
	is_in_menu = true
	menu_overlay.visible = true
	menu_controls_panel.visible = false
	ui_hint_label.visible = false
	ui_interact_prompt.text = ""
	player.controls_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if is_pause:
		menu_title_label.text = "PAUSADO"
		menu_subtitle_label.text = "O BREU AGUARDA LÁ FORA"
		menu_play_btn.text = "CONTINUAR"
		menu_restart_btn.visible = true
	else:
		menu_title_label.text = "B R E U"
		menu_subtitle_label.text = "10º ANDAR — ESCADA DE EMERGÊNCIA"
		menu_play_btn.text = "JOGAR"
		menu_restart_btn.visible = false

func _on_menu_play_pressed() -> void:
	if sfx_keypad_beep:
		sfx_keypad_beep.pitch_scale = 0.72
		sfx_keypad_beep.play()
	is_in_menu = false
	is_game_started = true
	menu_overlay.visible = false
	ui_hint_label.visible = true
	player.controls_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_menu_restart_pressed() -> void:
	_start_new_run(false)
	_on_menu_play_pressed()

func _build_keypad_ui(canvas: CanvasLayer) -> void:
	keypad_overlay = ColorRect.new()
	keypad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	keypad_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	keypad_overlay.visible = false
	canvas.add_child(keypad_overlay)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 440)
	panel.position = Vector2(-170, -220)
	keypad_overlay.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.78, 0.85, 0.78))
	title.text = "TRAVA NOTURNA — TÉRREO\n◈   ✕   ☾   ▲"
	vbox.add_child(title)
	
	keypad_display_label = Label.new()
	keypad_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keypad_display_label.add_theme_font_size_override("font_size", 34)
	keypad_display_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
	keypad_display_label.text = "_  _  _  _"
	vbox.add_child(keypad_display_label)
	
	keypad_status_label = Label.new()
	keypad_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keypad_status_label.add_theme_font_size_override("font_size", 15)
	keypad_status_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	keypad_status_label.text = "Digite os 4 dígitos [0-9] ou clique"
	vbox.add_child(keypad_status_label)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	
	var keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "OK"]
	for k in keys:
		var btn = Button.new()
		btn.text = k
		btn.custom_minimum_size = Vector2(96, 54)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_keypad_button_pressed.bind(k))
		grid.add_child(btn)
	
	var close_btn = Button.new()
	close_btn.text = "[ESC] Voltar para a Escada"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.pressed.connect(_close_keypad_ui)
	vbox.add_child(close_btn)

func _setup_global_audio() -> void:
	sfx_ambient_drone = AudioSynth.create_player(self, AudioSynth.make_ambient_building_drone(), "Master", -2.5)
	sfx_ambient_drone.play()
	sfx_bulb_pop = AudioSynth.create_player(self, AudioSynth.make_bulb_pop(), "Stairwell", 2.0)
	sfx_jumpscare_sting = AudioSynth.create_player(self, AudioSynth.make_jumpscare_sting(), "Scare", 1.5)
	sfx_wake_pant = AudioSynth.create_player(self, AudioSynth.make_wake_pant(), "Master", 0.5)
	sfx_whisper_neck = AudioSynth.create_player(self, AudioSynth.make_whisper_breath(), "Master", 2.5)
	sfx_heartbeat = AudioSynth.create_player(self, AudioSynth.make_heartbeat_thump(), "Master", -8.0)
	sfx_darkness_pressure = AudioSynth.create_player(self, AudioSynth.make_darkness_pressure_hum(), "Master", -45.0)
	sfx_darkness_pressure.play()
	sfx_distant_building = AudioSynth.create_player(self, AudioSynth.make_distant_thunder(), "Muffled", -1.5)
	sfx_keypad_beep = AudioSynth.create_player(self, AudioSynth.make_keypad_beep(), "Master", -2.0)
	sfx_keypad_error = AudioSynth.create_player(self, AudioSynth.make_keypad_error(), "Master", -1.0)
	sfx_keypad_unlock = AudioSynth.create_player(self, AudioSynth.make_keypad_unlock(), "Stairwell", 1.0)
	sfx_window_face_thud = AudioSynth.create_player(self, AudioSynth.make_window_face_thud(), "Stairwell", 2.0)
	
	# 3D emitter for the rare "Delayed Phantom Footsteps Behind You" micro-event!
	sfx_phantom_behind = AudioStreamPlayer3D.new()
	sfx_phantom_behind.stream = AudioSynth.make_footstep()
	sfx_phantom_behind.bus = "Stairwell"
	sfx_phantom_behind.unit_size = 4.0
	sfx_phantom_behind.max_distance = 12.0
	sfx_phantom_behind.volume_db = -1.5
	add_child(sfx_phantom_behind)
	
	# Mobile 3D emitter for organic building one-shots (water drips from pipes, distant pipe settles)
	sfx_ambient_3d_emitter = AudioStreamPlayer3D.new()
	sfx_ambient_3d_emitter.unit_size = 4.0
	sfx_ambient_3d_emitter.max_distance = 18.0
	sfx_ambient_3d_emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(sfx_ambient_3d_emitter)

func _start_new_run(play_wake_breath: bool) -> void:
	is_dying_or_resetting = false
	pursuer_state = PursuerState.INACTIVE
	pursuer_node.visible = false
	scare_entity_node.visible = false
	pursuer_has_triggered_this_run = false
	pursuer_event_cooldown = randf_range(16.0, 26.0)
	lowest_floor_reached = TOP_FLOOR
	ps1_shader_mat.set_shader_parameter("scare_intensity", 0.0)
	
	# Shuffled anomaly deck guarantees you encounter diverse hauntings!
	var deck = [
		StairwellSegment.AnomalyType.RED_LIGHT_SHOCK,
		StairwellSegment.AnomalyType.RINGING_INTERCOM,
		StairwellSegment.AnomalyType.BROKEN_SENSOR_DARK,
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
	
	# Generate randomized 4-digit Padlock Code & scatter 4 Enigmatic Clues across floors 9..1!
	discovered_clues.clear()
	is_notebook_open = false
	if notebook_panel:
		notebook_panel.visible = false
	_refresh_notebook_ui()
	_scatter_enigmatic_clues_for_run()
	is_keypad_open = false
	entered_code = ""
	if keypad_overlay:
		keypad_overlay.visible = false
	
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
		StairwellSegment.AnomalyType.HAUNTED_DECOR_POSTERS,
		StairwellSegment.AnomalyType.RED_LIGHT_SHOCK,
		StairwellSegment.AnomalyType.RINGING_INTERCOM,
		StairwellSegment.AnomalyType.BROKEN_SENSOR_DARK
	]
	if floor_num < TOP_FLOOR:
		pool.append(StairwellSegment.AnomalyType.UPPER_FLOOR_STALKER)
	pool.erase(exclude_anom)
	return pool[randi() % pool.size()]

func _on_clue_discovered(symbol: String, phrase: String) -> void:
	discovered_clues[symbol] = phrase
	_refresh_notebook_ui()
	if ui_toast_label:
		ui_toast_label.text = "Pista anotada: %s  [TAB]" % symbol
		ui_toast_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var tw = create_tween()
		tw.tween_interval(2.8)
		tw.tween_property(ui_toast_label, "modulate:a", 0.0, 0.6)

func _refresh_notebook_ui() -> void:
	if not notebook_label:
		return
	var txt = "ANOTAÇÕES — SENHA DO TÉRREO\n"
	for sym in ["◈", "✕", "☾", "▲"]:
		if discovered_clues.has(sym):
			txt += "\n%s  %s" % [sym, discovered_clues[sym]]
		else:
			txt += "\n%s  ???" % sym
	notebook_label.text = txt

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

func _scatter_enigmatic_clues_for_run() -> void:
	var symbols = ["◈", "✕", "☾", "▲"]
	var enigmas_by_digit = [
		"O vazio do zero",
		"Um único vulto na escada",
		"Dois olhos atrás do vidro",
		"Três batidas na porta de trás",
		"Quatro passos no breu",
		"Cinco dedos arranhando o ferro",
		"Seis segundos até a luz morrer",
		"Sete degraus abaixo de você",
		"Oito batimentos no escuro",
		"Nove portas trancadas"
	]
	
	exit_code_digits.clear()
	for i in range(4):
		exit_code_digits.append(randi() % 10)
	
	# Pick 4 distinct floors between 9 and 1 for the 4 hiding spots
	var candidate_floors = [9, 8, 7, 6, 5, 4, 3, 2, 1]
	candidate_floors.shuffle()
	
	# Ensure the ANTECAMARA_INSIDE clue floor does NOT have a haunted door anomaly so the player can enter it!
	var spots = [
		StairwellSegment.ClueSpot.WALL_BLOOD,
		StairwellSegment.ClueSpot.ANTECAMARA_INSIDE,
		StairwellSegment.ClueSpot.POSTER_NOTE,
		StairwellSegment.ClueSpot.WINDOW_FUSE
	]
	
	var used_floors: Array[int] = []
	for i in range(4):
		var chosen_f = -1
		for f in candidate_floors:
			if f in used_floors:
				continue
			var seg = floors[f] as StairwellSegment
			if spots[i] == StairwellSegment.ClueSpot.ANTECAMARA_INSIDE:
				if seg.anomaly_type == StairwellSegment.AnomalyType.DOOR_WINDOW_WATCHER or seg.anomaly_type == StairwellSegment.AnomalyType.HANDS_ON_DOOR:
					continue
			chosen_f = f
			break
		if chosen_f == -1:
			chosen_f = candidate_floors[i]
		used_floors.append(chosen_f)
		
		var digit = exit_code_digits[i]
		var seg_target = floors[chosen_f] as StairwellSegment
		seg_target.set_enigmatic_clue(spots[i], symbols[i], enigmas_by_digit[digit])

func _open_keypad_ui() -> void:
	if is_dying_or_resetting or is_keypad_open:
		return
	is_keypad_open = true
	entered_code = ""
	player.controls_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	keypad_overlay.visible = true
	keypad_status_label.text = "Digite os 4 dígitos [0-9] ou clique"
	keypad_status_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	_refresh_keypad_display()

func _close_keypad_ui() -> void:
	if not is_keypad_open:
		return
	is_keypad_open = false
	keypad_overlay.visible = false
	player.controls_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh_keypad_display() -> void:
	var out = ""
	for i in range(4):
		if i < entered_code.length():
			out += entered_code[i]
		else:
			out += "_"
		if i < 3:
			out += "  "
	keypad_display_label.text = out

func _on_keypad_button_pressed(k: String) -> void:
	if not is_keypad_open:
		return
	if k == "CLR":
		entered_code = ""
		if sfx_keypad_beep:
			sfx_keypad_beep.pitch_scale = 0.8
			sfx_keypad_beep.play()
		_refresh_keypad_display()
	elif k == "OK":
		_submit_keypad_code()
	else:
		if entered_code.length() < 4:
			entered_code += k
			if sfx_keypad_beep:
				sfx_keypad_beep.pitch_scale = randf_range(0.96, 1.04)
				sfx_keypad_beep.play()
			_refresh_keypad_display()
			if entered_code.length() == 4:
				_submit_keypad_code()

func _submit_keypad_code() -> void:
	var expected = "%d%d%d%d" % [exit_code_digits[0], exit_code_digits[1], exit_code_digits[2], exit_code_digits[3]]
	if entered_code == expected:
		if sfx_keypad_unlock:
			sfx_keypad_unlock.play()
		keypad_status_label.text = "ACESSO LIBERADO"
		keypad_status_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		await get_tree().create_timer(0.55).timeout
		_close_keypad_ui()
		(floors[0] as StairwellSegment).unlock_ground_floor_exit()
	else:
		if sfx_keypad_error:
			sfx_keypad_error.play()
		keypad_status_label.text = "SENHA INCORRETA — Procure os 4 símbolos acima"
		keypad_status_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.22))
		entered_code = ""
		_refresh_keypad_display()

func _unhandled_input(event: InputEvent) -> void:
	if is_in_menu:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and is_game_started:
			_on_menu_play_pressed()
		return
	
	if is_keypad_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_close_keypad_ui()
			elif event.keycode == KEY_BACKSPACE:
				if entered_code.length() > 0:
					entered_code = entered_code.substr(0, entered_code.length() - 1)
					_refresh_keypad_display()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_submit_keypad_code()
			elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
				_on_keypad_button_pressed(str(event.keycode - KEY_0))
			elif event.keycode >= KEY_KP_0 and event.keycode <= KEY_KP_9:
				_on_keypad_button_pressed(str(event.keycode - KEY_KP_0))
		return
	
	if is_dying_or_resetting or not player or player.controls_locked:
		return
	
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_show_menu(true)
		return
	
	# [TAB] Toggle Clue Notebook!
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		is_notebook_open = not is_notebook_open
		if notebook_panel:
			notebook_panel.visible = is_notebook_open
		return
	
	var pressed_interact = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed_interact = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		pressed_interact = true
	
	if pressed_interact:
		var p_f = _get_player_floor_index()
		if floors.has(p_f) and (floors[p_f] as StairwellSegment).can_interact_with_intercom(player.global_position):
			(floors[p_f] as StairwellSegment).answer_ringing_intercom()
			return
		var seg = _get_nearest_door_segment()
		if seg:
			# Passing player.is_crouching prevents opening/closing the door while crouched!
			seg.toggle_fire_door(player.is_crouching)
	
	# [F1] Debug: Cycle all 10 anomalies on the floor the player is currently standing on
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		var f = _get_player_floor_index()
		if f > 0 and floors.has(f):
			var seg = floors[f] as StairwellSegment
			var next_a = (seg.anomaly_type + 1) % 11
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
	if is_in_menu:
		# Subtle slow atmospheric camera sway on the live 3D stairwell behind the title screen!
		if player and not is_game_started:
			var t_sec = Time.get_ticks_msec() * 0.001
			player.rotation.y = deg_to_rad(18.0 + sin(t_sec * 0.35) * 6.0)
			player.head_pivot.rotation.x = deg_to_rad(-10.0 + sin(t_sec * 0.25) * 2.5)
		return
	if is_dying_or_resetting or not player:
		return
	
	_update_interact_prompt()
	_update_ambient_soundscape(delta)
	_update_pursuer_event_spawner(delta)
	_update_pursuer_state_machine(delta)

func _update_ambient_soundscape(delta: float) -> void:
	var p_floor = _get_player_floor_index()
	var p_seg = floors[p_floor] as StairwellSegment if floors.has(p_floor) else null
	var closed_in_antecamara = (p_seg != null and p_seg.player_inside_antecamara and not p_seg.is_fire_door_open)
	
	# 1. Dynamic Acoustics + Crouch Vignette Feedback
	player.set_inside_small_room(closed_in_antecamara)
	var target_vig = 0.78 if player.is_crouching else 0.55
	current_vignette = lerp(current_vignette, target_vig, delta * 7.0)
	ps1_shader_mat.set_shader_parameter("vignette_strength", current_vignette)
	
	if sfx_ambient_drone:
		sfx_ambient_drone.bus = "Muffled" if closed_in_antecamara else "Master"
		var target_drone_db = -11.5 if closed_in_antecamara else -2.5
		sfx_ambient_drone.volume_db = lerp(sfx_ambient_drone.volume_db, target_drone_db, delta * 4.0)
	
	# 1b. Rare Micro-Event: "Delayed Phantom Footsteps Behind You" when stopping on stairs!
	phantom_step_cooldown = max(0.0, phantom_step_cooldown - delta)
	if player_was_moving and not player.is_moving_now and not closed_in_antecamara and phantom_step_cooldown <= 0.0:
		if randf() < 0.28:
			phantom_step_cooldown = randf_range(28.0, 46.0)
			_trigger_delayed_phantom_steps_behind()
	player_was_moving = player.is_moving_now
	
	# 2. Pitch-Black Silence / Ear-Pressure Tension when waiting in total dark (Option 3)
	var in_pitch_dark = (p_seg != null and not closed_in_antecamara and not p_seg.main_light_on and not p_seg.mid_light_on)
	var target_dark = 1.0 if in_pitch_dark else 0.0
	darkness_pressure_level = move_toward(darkness_pressure_level, target_dark, delta * (0.55 if in_pitch_dark else 2.8))
	if sfx_darkness_pressure:
		sfx_darkness_pressure.volume_db = lerp(-46.0, -4.5, darkness_pressure_level)
	
	# 3. Distant Night Thunder (+ Window Lightning Flash!) & Old Elevator Machinery (Option 2)
	distant_building_timer -= delta
	if distant_building_timer <= 0.0 and sfx_distant_building and not sfx_distant_building.playing:
		distant_building_timer = randf_range(18.0, 32.0)
		if randf() < 0.62:
			sfx_distant_building.stream = AudioSynth.make_distant_thunder()
			sfx_distant_building.volume_db = randf_range(-2.5, 1.5)
			sfx_distant_building.pitch_scale = randf_range(0.85, 1.08)
			if p_seg:
				p_seg.trigger_window_lightning(randf() < 0.45)
		else:
			sfx_distant_building.stream = AudioSynth.make_elevator_machinery()
			sfx_distant_building.volume_db = randf_range(-4.0, 0.5)
			sfx_distant_building.pitch_scale = randf_range(0.90, 1.05)
		sfx_distant_building.play()
	
	# 4. Organic 3D building life sounds (water drips in corner pipe, distant thermal pipe settles)
	ambient_oneshot_timer -= delta
	if ambient_oneshot_timer <= 0.0 and sfx_ambient_3d_emitter and not sfx_ambient_3d_emitter.playing:
		ambient_oneshot_timer = randf_range(5.0, 11.5)
		if p_seg:
			if randf() < 0.65:
				sfx_ambient_3d_emitter.global_position = p_seg.to_global(Vector3(-2.05, randf_range(-2.2, 1.2), randf_range(-5.0, 2.2)))
				sfx_ambient_3d_emitter.stream = AudioSynth.make_water_drip()
				sfx_ambient_3d_emitter.bus = "Stairwell"
				sfx_ambient_3d_emitter.volume_db = randf_range(-1.5, 2.0)
				sfx_ambient_3d_emitter.pitch_scale = randf_range(0.88, 1.18)
				sfx_ambient_3d_emitter.play()
			else:
				var y_off = randf_range(-6.0, 6.0)
				sfx_ambient_3d_emitter.global_position = player.global_position + Vector3(randf_range(-2.0, 2.0), y_off, randf_range(-4.0, 2.0))
				sfx_ambient_3d_emitter.stream = AudioSynth.make_pipe_settle()
				sfx_ambient_3d_emitter.bus = "Muffled"
				sfx_ambient_3d_emitter.volume_db = randf_range(-2.0, 1.5)
				sfx_ambient_3d_emitter.pitch_scale = randf_range(0.85, 1.12)
				sfx_ambient_3d_emitter.play()
	
	# 5. Dynamic Heartbeat ONLY when Pursuer is dangerously close (< 9.5m) or testing your door!
	if pursuer_state != PursuerState.INACTIVE and pursuer_node.visible:
		var dist = pursuer_node.global_position.distance_to(player.global_position)
		if dist < 9.5 or pursuer_state == PursuerState.CHECKING_DOOR_WINDOW or pursuer_state == PursuerState.FORCING_DOOR:
			var intensity = clamp(1.0 - (dist / 9.5), 0.15, 1.0)
			if pursuer_state == PursuerState.FORCING_DOOR:
				intensity = 1.0
			heartbeat_timer -= delta
			if heartbeat_timer <= 0.0:
				heartbeat_timer = lerp(1.15, 0.56, intensity)
				if sfx_heartbeat:
					sfx_heartbeat.volume_db = lerp(-15.0, -3.5, intensity)
					sfx_heartbeat.pitch_scale = lerp(0.95, 1.12, intensity)
					sfx_heartbeat.play()
	else:
		heartbeat_timer = 0.0

func _update_interact_prompt() -> void:
	var p_f = _get_player_floor_index()
	if floors.has(p_f) and (floors[p_f] as StairwellSegment).can_interact_with_intercom(player.global_position):
		ui_interact_prompt.text = "[E] Atender Interfone"
		if ui_crosshair:
			ui_crosshair.color = Color(0.95, 0.35, 0.30, 0.85)
		return
	
	var seg = _get_nearest_door_segment()
	if not seg:
		ui_interact_prompt.text = ""
		if ui_crosshair:
			ui_crosshair.color = Color(0.85, 0.88, 0.85, 0.28)
		return
	
	if ui_crosshair:
		ui_crosshair.color = Color(0.95, 0.94, 0.82, 0.82)
	
	var holding = Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if seg.is_ground_floor:
		ui_interact_prompt.text = "[E] Trava Noturna — Digitar Senha"
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

func _trigger_delayed_phantom_steps_behind() -> void:
	if not player or not sfx_phantom_behind:
		return
	var back_pos = player.global_position + player.global_transform.basis.z.normalized() * 1.45
	sfx_phantom_behind.global_position = back_pos
	await get_tree().create_timer(0.28).timeout
	if is_in_menu or is_dying_or_resetting:
		return
	sfx_phantom_behind.pitch_scale = randf_range(0.88, 0.96)
	sfx_phantom_behind.play()
	await get_tree().create_timer(0.36).timeout
	if is_in_menu or is_dying_or_resetting:
		return
	sfx_phantom_behind.global_position = player.global_position + player.global_transform.basis.z.normalized() * 0.85
	sfx_phantom_behind.pitch_scale = randf_range(0.94, 1.02)
	sfx_phantom_behind.play()

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
					# Sudden startling glass thud as he presses his pale face against the window!
					if sfx_window_face_thud:
						sfx_window_face_thud.play()
					player.camera_shake = 0.032
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
