# slime.gd - ИСПРАВЛЕНО: улучшена область нажатия
extends Area2D

enum SlimeType { SMALL, MEDIUM, BOSS }

@export_category("Slime Settings")
@export var base_speed_multiplier: float = 1.2
@export var base_scale_multiplier: float = 1.3
@export var boss_speed_multiplier: float = 0.4

@export_category("Touch Settings")
# ИСПРАВЛЕНО: увеличена область касания для мобильных
@export var touch_area_multiplier: float = 3.0

var wave_speed_multiplier: float = 1.0
var pop_effect_scene = preload("res://effects/slime_pop_effect.tscn")

const BLUE_FRAMES = preload("res://assets/slimes_blue.tres")
const DARK_FRAMES = preload("res://assets/slimes_dark.tres")
const GREEN_FRAMES = preload("res://assets/slimes_green.tres")
const PINK_FRAMES = preload("res://assets/slimes_pink.tres")
const WHITE_FRAMES = preload("res://assets/slimes_white.tres")
const YELLOW_FRAMES = preload("res://assets/slimes_yellow.tres")

const SLIME_FRAME_RESOURCES = [
	BLUE_FRAMES, DARK_FRAMES, GREEN_FRAMES, 
	PINK_FRAMES, WHITE_FRAMES, YELLOW_FRAMES
]

var slime_type := SlimeType.SMALL
var hp := 1
var max_hp := 1
var speed := 750.0
var score_value := 10
var color := Color.WHITE
var is_invincible := false

@onready var slime_sprite: AnimatedSprite2D = $SlimeSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D 
@onready var hp_bar: ProgressBar = $HPBar
@onready var timer_invincibility: Timer = $InvincibilityTimer

signal slime_killed(type, position)
signal reached_bottom

func _ready():
	# КРИТИЧЕСКИ ВАЖНО: включаем обработку всех типов ввода
	input_pickable = true
	monitorable = true
	monitoring = true
	
	# ИСПРАВЛЕНО: увеличенная область для мобильных
	if OS.has_feature("mobile") or OS.has_feature("web"):
		_update_touch_collision()
	
	# Подключаем сигналы ввода
	input_event.connect(_on_input_event)
	
	# НОВОЕ: дополнительная обработка тач-событий
	if OS.has_feature("mobile") or OS.has_feature("web"):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	
	if is_instance_valid(timer_invincibility):
		timer_invincibility.timeout.connect(_on_invincibility_timer_timeout)
	
	_setup_slime()
	slime_sprite.play("walk")

func _update_touch_collision():
	"""ИСПРАВЛЕНО: значительно увеличиваем область касания"""
	if collision_shape.shape is CircleShape2D:
		var base_radius = 50.0 * scale.x
		# Для мобильных утраиваем радиус коллизии
		collision_shape.shape.radius = base_radius * touch_area_multiplier
		print("📱 Touch collision radius: ", collision_shape.shape.radius)

func _on_mouse_entered():
	"""НОВОЕ: визуальная обратная связь при наведении"""
	if OS.has_feature("mobile") or OS.has_feature("web"):
		slime_sprite.modulate = slime_sprite.modulate.lightened(0.2)

func _on_mouse_exited():
	"""НОВОЕ: возврат цвета"""
	slime_sprite.modulate = color

func _setup_slime():
	var random_frames = SLIME_FRAME_RESOURCES.pick_random()
	slime_sprite.sprite_frames = random_frames
	
	match slime_type:
		SlimeType.SMALL:
			max_hp = 1 
			hp = 1
			speed = randf_range(180.0, 300.0) * base_speed_multiplier * wave_speed_multiplier
			score_value = 10
			scale = Vector2(1.8, 1.8) * base_scale_multiplier
			color = Color.WHITE
			
		SlimeType.MEDIUM:
			max_hp = 2
			hp = 2
			speed = randf_range(120.0, 180.0) * base_speed_multiplier * wave_speed_multiplier
			score_value = 25
			scale = Vector2(2.7, 2.7) * base_scale_multiplier
			color = Color(1.0, 0.9, 0.8)
			
		SlimeType.BOSS:
			max_hp = 5
			hp = 5
			speed = randf_range(40.0, 80.0) * base_speed_multiplier * wave_speed_multiplier * boss_speed_multiplier
			score_value = 100
			scale = Vector2(4.5, 4.5) * base_scale_multiplier
			color = Color(1.0, 0.7, 0.7)
			print("🐲 Boss spawned")
	
	slime_sprite.modulate = color
	_update_collision()
	_update_hp_bar()

func _update_collision():
	if collision_shape.shape is CircleShape2D:
		var base_radius = 50.0 * scale.x
		# Применяем множитель для мобильных
		if OS.has_feature("mobile") or OS.has_feature("web"):
			collision_shape.shape.radius = base_radius * touch_area_multiplier
		else:
			collision_shape.shape.radius = base_radius

func _process(delta):
	if GameManager.paused or not GameManager.game_active:
		return
	
	# Эффект мигания при уроне
	if is_invincible:
		var flash = int(Time.get_ticks_msec() / 100.0) % 2 == 0
		slime_sprite.modulate = color if flash else Color.WHITE
	else:
		slime_sprite.modulate = color
	
	var camera_scale = _get_camera_scale()
	var adjusted_speed = speed * camera_scale
	position.y += adjusted_speed * delta
	
	var viewport_size = get_viewport_rect().size
	var bottom_threshold = viewport_size.y / camera_scale + 200
	
	if position.y > bottom_threshold:
		emit_signal("reached_bottom")
		queue_free()

func _get_camera_scale() -> float:
	var game_node = get_tree().get_first_node_in_group("game_node")
	if game_node and game_node.camera:
		return game_node.camera.zoom.x
	return 1.0

func _on_input_event(_viewport, event, _shape_idx):
	"""ИСПРАВЛЕНО: улучшенная обработка тач-событий"""
	var should_take_damage = false
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			should_take_damage = true
			print("🖱️ Mouse click on slime")
			
	elif event is InputEventScreenTouch:
		if event.pressed:
			should_take_damage = true
			print("👆 Touch on slime at: ", event.position)
	
	if should_take_damage and not is_invincible:
		take_damage()

func take_damage():
	if not GameManager.game_active or is_invincible:
		return
	
	hp -= 1
	_update_hp_bar()
	
	# НОВОЕ: тактильная обратная связь для мобильных
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(50) # 50ms вибрация
	
	# Визуальный эффект удара
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.2, 0.1)
	tween.tween_property(self, "scale", scale, 0.1)
	
	if hp > 0:
		is_invincible = true
		if is_instance_valid(timer_invincibility):
			timer_invincibility.start(0.15)
		slime_sprite.play("walk")
	else:
		die()

func _on_invincibility_timer_timeout():
	is_invincible = false

func die():
	GameManager.add_score(score_value)
	
	if slime_type == SlimeType.BOSS:
		if not GameManager.achievements["boss_kill"]["unlocked"]:
			GameManager.unlock_achievement("boss_kill")
	
	if AudioManager:
		AudioManager.play_pop_sound()
	
	_spawn_pop_effect()
	emit_signal("slime_killed", slime_type, global_position)
	
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	input_pickable = false
	
	if slime_sprite.sprite_frames.has_animation("death"):
		slime_sprite.play("death")
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.5, 0.3)
	tween.tween_property(slime_sprite, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	queue_free()

func _spawn_pop_effect():
	if pop_effect_scene:
		var pop_effect = pop_effect_scene.instantiate()
		pop_effect.position = global_position
		
		var effect_color = Color.WHITE
		var effect_scale = 1.0
		
		match slime_type:
			SlimeType.SMALL:
				effect_color = Color(0.2, 0.8, 0.2)
				effect_scale = 0.7
			SlimeType.MEDIUM:
				effect_color = Color(0.8, 0.8, 0.2)
				effect_scale = 1.2
			SlimeType.BOSS:
				effect_color = Color(0.8, 0.2, 0.1)
				effect_scale = 2.5
		
		var camera_scale = _get_camera_scale()
		effect_scale /= camera_scale
		
		if pop_effect.has_method("set_pop_properties"):
			pop_effect.set_pop_properties(effect_color, effect_scale)
		
		get_parent().add_child(pop_effect)

func _update_hp_bar():
	if is_instance_valid(hp_bar):
		hp_bar.value = (float(hp) / float(max_hp)) * 10.0
		hp_bar.visible = hp < max_hp
		
		var hp_percent = float(hp) / float(max_hp)
		var bar_color = Color.GREEN
		
		if hp_percent < 0.3:
			bar_color = Color.RED
		elif hp_percent < 0.6:
			bar_color = Color.YELLOW
		
		if hp_bar.has_theme_stylebox_override("fill"):
			var style = hp_bar.get_theme_stylebox("fill")
			if style is StyleBoxFlat:
				style.bg_color = bar_color
