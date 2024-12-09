extends CharacterBody3D

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const GRAVITY = 9.8
const SENSITIVITY = 0.003

#references to nodes must be in onready variables
@onready var head: Node3D = $Head
@onready var camera = $Head/Camera3D

#headbob variables
const BOB_FREQ = 2.0 #bob frequency - how often we headbob
const BOB_AMP = 0.08 #bob amplitude - how much the camera moves up/down
var t_bob = 0.0 #variable that tracks how far along the sin wave we are

#FOV variables
const BASE_FOV = 70.0
const FOV_CHANGE = 1.5

func _ready():
	#capture the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
#handle mouse movement
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY) #left/right rotation
		camera.rotate_x(-event.relative.y * SENSITIVITY) #up/down rotation
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		#velocity += get_gravity() * delta
		velocity.y += -GRAVITY * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	#Handle sprinting
	if Input.is_action_pressed("sprint") and is_on_floor():
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#when we are in the air, we should have some inertia
	#so, only give the player full control of horizontal movement while they are on the ground
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			#decelerate when we stop pressing a movement key
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 9.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 9.0)
	else:
		#player is in the air
		#lerp between our current velocity and
		#our target velocity (which we would be travelling if we were moving on the ground)
		# delta is usually around 0.05. 
		#for instance doing 2 * delta => we move towards our target velocity by 10% each frame (frame or tick?)
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
		
	#head bob
	#bob speed relative to delta and velocity.length (bob faster when moving faster)
	#multiply by is_on_floor => don't headbob in the air
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	#FOV - increase the faster we are going
	var velocity_clamped = clamp(velocity.length(), WALK_SPEED, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP #up/down headbob
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP #side-to-side headbob
	return pos
