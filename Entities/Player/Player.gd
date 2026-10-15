extends CharacterBody2D
class_name Player

const ACCELERATION_FACTOR = 100.0
const SPEED = 250.0
const JUMP_VELOCITY = -400.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED
	#if direction:
		#velocity = velocity.move_toward(direction , ACCELERATION_FACTOR)
	#else:
	
	velocity = velocity.move_toward(direction, ACCELERATION_FACTOR)
	
	move_and_slide()
