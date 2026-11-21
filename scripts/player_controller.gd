extends CharacterBody3D
class_name PlayerController

const WALK_SPEED: float = 2.65
const SPRINT_SPEED: float = 3.95
const CROUCH_SPEED: float = 1.45
const STAND_EYE_Y: float = 1.56
const CROUCH_EYE_Y: float = 0.94
const GRAVITY: float = 14.0
const MOUSE_SENSITIVITY: float = 0.0026

var camera: Camera3D
var head_pivot: Node3D
var scare_flash_light: OmniLight3D
var sfx_step: AudioStreamPlayer
var bob_time: float = 0.0
var step_accum: float = 0.0
var controls_locked: bool = false
var is_crouching: bool = false
var camera_shake: float = 0.0

func _ready() -> void:
	add_to_group("player")
	
	var col = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.70
	col.shape = cap
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)
	
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0.0, STAND_EYE_Y, 0.0)
	add_child(head_pivot)
	
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 36.0
	head_pivot.add_child(camera)
	
	# Ultra-dim close-range night vision so pitch darkness isn't 100% blind within 1m
	var close_glow = OmniLight3D.new()
	close_glow.light_color = Color(0.55, 0.60, 0.65)
	close_glow.light_energy = 0.035
	close_glow.omni_range = 1.4
	close_glow.shadow_enabled = false
	head_pivot.add_child(close_glow)
	
	# Harsh strobe light attached to head used ONLY during 3D jumpscares!
	scare_flash_light = OmniLight3D.new()
	scare_flash_light.light_color = Color(0.92, 0.96, 0.95)
	scare_flash_light.light_energy = 0.0
	scare_flash_light.omni_range = 3.2
	scare_flash_light.visible = false
	head_pivot.add_child(scare_flash_light)
	
	# Footsteps routed through the concrete Stairwell Reverb bus!
	sfx_step = AudioSynth.create_player(self, AudioSynth.make_footstep(), "Stairwell", -4.5)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head_pivot.rotation.x = clamp(head_pivot.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
	elif event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if camera_shake > 0.001:
		camera.h_offset = randf_range(-camera_shake, camera_shake)
		camera.v_offset = randf_range(-camera_shake, camera_shake)
		camera_shake = move_toward(camera_shake, 0.0, delta * 0.25)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	
	if controls_locked:
		velocity = Vector3.ZERO
		return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Crouch (Ctrl or C) for hiding in the Antecâmara blind spot!
	is_crouching = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	var target_eye_y = CROUCH_EYE_Y if is_crouching else STAND_EYE_Y
	head_pivot.position.y = lerp(head_pivot.position.y, target_eye_y, delta * 10.0)
	
	var input_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0
	input_vec = input_vec.normalized()
	
	var speed = WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_key_pressed(KEY_SHIFT):
		speed = SPRINT_SPEED
	
	var move_dir = (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	
	if move_dir != Vector3.ZERO:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		
		var bob_amp = 0.022 if is_crouching else 0.045
		bob_time += delta * speed * 3.4
		camera.position.y = sin(bob_time) * bob_amp
		camera.position.x = cos(bob_time * 0.5) * (bob_amp * 0.55)
		
		step_accum += delta * speed
		if step_accum >= 1.38:
			step_accum = 0.0
			if sfx_step:
				sfx_step.volume_db = -12.0 if is_crouching else -4.5
				sfx_step.pitch_scale = randf_range(0.88, 1.08)
				sfx_step.play()
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)
		camera.position.y = lerp(camera.position.y, 0.0, delta * 8.0)
		camera.position.x = lerp(camera.position.x, 0.0, delta * 8.0)
	
	move_and_slide()
