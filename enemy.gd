extends CharacterBody2D

@export var speed := 55.0
@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer
@onready var Hitbox = $EnemyHitBox/CollisionShape2D

var player = null 
var player_chase = false
var player_inattack_range = false
var is_in_hurt_state = false

@export var HP: int = MaxHP : set = set_hp, get = get_hp
var is_alive = true
@export var MaxHP: int = 3

var  knockback: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var is_hurt: bool = false 
var is_attacking: bool = false
var dead: bool = false

enum Direction {DOWN, UP, LEFT, RIGHT} #Short for enumeration, this line creates a custom 'type' called Direction with named values. Direction.DOWN == 0 | Direction.UP == 1 | Direction.LEFT == 2 | Direction.RIGHT == 3 |
enum State {IDLE, CHASE, ATTACK, HURT,DEAD}


var current_direction = Direction.DOWN
var current_state = State.IDLE

func get_hp():
	return HP

func set_hp(value) :
	if value != HP :
		HP = clamp(value, 0 ,MaxHP)

func _physics_process(delta):
	
	if HP <= 0:
		is_alive = false
		is_hurt = false
		current_state = State.DEAD
		animation_player.play("Die")
		# Disable collisions but DON'T disable physics processing yet
		$EnemyHitBox/CollisionShape2D.disabled = true
		$DetectionArea/CollisionShape2D.disabled = true
		$AttackRange/CollisionShape2D.disabled = true
		# Also disable the collision shape for the enemy itself
		$CollisionShape2D.disabled = true
		return
	
	
	
	if is_hurt and not is_attacking:
		return
	
	if is_hurt and is_attacking:
		_cancel_attack()
		return
	
	if is_attacking:
		return
	
	if knockback_timer > 0.0 :
		velocity = knockback
		knockback_timer -= delta
		move_and_slide()
		if knockback_timer <= 0.0:
			knockback = Vector2.ZERO
		return
	
	# Determine direction based on player position (similar to how player gets input_vector)
	var direction_vector = Vector2.ZERO
	if player_chase:
		direction_vector = (player.global_position - global_position).normalized()
	
	# Set velocity based on state
	if player_chase and current_state != State.ATTACK:
		velocity = direction_vector * speed
		current_state = State.CHASE
	elif not player_chase:
		velocity = Vector2.ZERO
		current_state = State.IDLE
	
	# Handle attack
	if player_inattack_range and not is_hurt:
		current_state = State.ATTACK
		is_attacking = true
		animation_player.play("Attack")
		return
	
	# Determine direction for sprite flipping (similar to player)
	if abs(direction_vector.x) >= abs(direction_vector.y):
		current_direction = Direction.RIGHT if direction_vector.x > 0 else Direction.LEFT
	else:
		current_direction = Direction.DOWN if direction_vector.y > 0 else Direction.UP
	
	_update_direction()
	
	_play_animation()
	
	move_and_slide()


func _cancel_attack():
	# Disable attack hitbox when attack is interrupted
	Hitbox.disabled = true
	is_attacking = false
	

func _update_direction():
	# Flip sprite and adjust collision shape position
	if current_direction == Direction.LEFT:
		animated_sprite.flip_h = true
		# Adjust collision shape position for left direction
		if Hitbox:
			Hitbox.position.x = -abs(Hitbox.position.x)
	else:
		animated_sprite.flip_h = false
		# Adjust collision shape position for right direction
		if Hitbox:
			Hitbox.position.x = abs(Hitbox.position.x)



func _play_animation():
	match current_state:
		State.IDLE:
			animated_sprite.play("IDLE")
		State.CHASE:
			animated_sprite.play("RUN")
		State.ATTACK:
			animated_sprite.stop()
			animation_player.play("Attack")
		State.HURT:
			animated_sprite.stop()
			animation_player.play("Hurt")





func _on_detection_area_body_entered(body: Node2D) -> void:
	player = body
	player_chase = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null 
	player_chase = false


func _on_attack_range_body_entered(body: Node2D) -> void:
	print("Something entered attack range: ", body.name)
	player_inattack_range = true
	current_state = State.ATTACK


func _on_attack_range_body_exited(body: Node2D) -> void:
	player_inattack_range = false 



func take_damage(damage):
	if !is_alive :
		return
	self.HP -= damage
	print ("Enemy took", damage, "damage !", "Health = ", HP)
	




func _on_enemy_hurt_box_area_entered(hitbox: Area2D) -> void:
	is_hurt = true
	take_damage(1)
	current_state = State.HURT
	var knockback_direction = (global_position - player.global_position).normalized()
	apply_knockback(knockback_direction, 25.0, 0.12)
	_play_animation()
	

func apply_knockback(direction: Vector2, force: float, knockback_duration: float) -> void :
	knockback = direction * force
	knockback_timer = knockback_duration




func _on_enemy_hurt_box_area_exited(area: Area2D) -> void:
	is_hurt = false


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("Attack") :
		current_state = State.IDLE
		is_attacking = false
		_play_animation()
	elif anim_name.begins_with("Die") :
		queue_free()
