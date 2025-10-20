# fireflies_effect.gd
extends Node2D

@export var firefly_count: int = 15
@export var spawn_radius: float = 600.0
@export var min_lifetime: float = 1.0
@export var max_lifetime: float = 2.0
@export var min_speed: float = 20.0
@export var max_speed: float = 60.0
@export var firefly_color: Color = Color(0.6, 0.8, 1.0, 0.8)  # Голубой свет

var active_fireflies: Array = []
var firefly_texture: Texture2D

class FireflyData:
	var node: Node2D
	var sprite: Sprite2D
	var velocity: Vector2
	var lifetime: float
	var initial_lifetime: float
	var time: float = 0.0
	var state: String = "appearing"  # "appearing", "alive", "disappearing"

func _ready():
	_create_firefly_texture()
	_start_effect()

func _create_firefly_texture():
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Рисуем простой круг с градиентом
	var center = Vector2(16, 16)
	var radius = 8.0
	
	for x in range(32):
		for y in range(32):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist <= radius:
				var alpha = 1.0 - (dist / radius)
				var color = Color(1, 1, 1, alpha * 0.8)
				image.set_pixel(x, y, color)
	
	firefly_texture = ImageTexture.create_from_image(image)

func _start_effect():
	# Создаем начальных светлячков
	for i in range(firefly_count):
		_spawn_firefly()
	
	# Запускаем таймер для постоянного спавна
	var timer = Timer.new()
	timer.wait_time = 0.5  # Спавним нового светлячка каждые 0.5 секунд
	timer.timeout.connect(_spawn_firefly)
	add_child(timer)
	timer.start()

func _spawn_firefly():
	# Создаем узел светлячка
	var firefly = Node2D.new()
	add_child(firefly)
	
	# Создаем спрайт для светлячка
	var sprite = Sprite2D.new()
	sprite.texture = firefly_texture
	sprite.modulate = firefly_color
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0  # Начинаем с прозрачного
	firefly.add_child(sprite)
	
	# Случайная позиция вокруг камеры
	var angle = randf() * TAU
	var distance = randf() * spawn_radius
	var spawn_pos = Vector2(cos(angle), sin(angle)) * distance
	firefly.position = spawn_pos
	
	# Случайное время жизни
	var lifetime = randf_range(min_lifetime, max_lifetime)
	
	# Случайное направление движения
	var move_angle = randf() * TAU
	var speed = randf_range(min_speed, max_speed)
	var velocity = Vector2(cos(move_angle), sin(move_angle)) * speed
	
	# Создаем данные светлячка
	var firefly_data = FireflyData.new()
	firefly_data.node = firefly
	firefly_data.sprite = sprite
	firefly_data.velocity = velocity
	firefly_data.lifetime = lifetime
	firefly_data.initial_lifetime = lifetime
	firefly_data.state = "appearing"
	
	active_fireflies.append(firefly_data)

func _process(delta):
	# Обновляем позиции и анимации всех активных светлячков
	var fireflies_to_remove = []
	
	for firefly_data in active_fireflies:
		if not is_instance_valid(firefly_data.node):
			fireflies_to_remove.append(firefly_data)
			continue
			
		# Обновляем позицию
		firefly_data.node.position += firefly_data.velocity * delta
		
		# Плавное изменение скорости (замедление)
		firefly_data.velocity = firefly_data.velocity.lerp(Vector2.ZERO, 0.1 * delta)
		
		# Уменьшаем время жизни
		firefly_data.lifetime -= delta
		firefly_data.time += delta
		
		# Управление состоянием светлячка
		var life_progress = 1.0 - (firefly_data.lifetime / firefly_data.initial_lifetime)
		
		if firefly_data.state == "appearing":
			# Плавное появление в первые 30% времени жизни
			var appear_progress = min(1.0, life_progress / 0.3)
			firefly_data.sprite.modulate.a = lerp(0.0, firefly_color.a, appear_progress)
			
			if life_progress >= 0.3:
				firefly_data.state = "alive"
				
		elif firefly_data.state == "alive":
			# Полная видимость в середине жизни
			firefly_data.sprite.modulate.a = firefly_color.a
			
			# Начинаем исчезать в последние 30% времени жизни
			if life_progress >= 0.7:
				firefly_data.state = "disappearing"
				
		elif firefly_data.state == "disappearing":
			# Плавное исчезновение в последние 30% времени жизни
			var disappear_progress = (life_progress - 0.7) / 0.3
			firefly_data.sprite.modulate.a = lerp(firefly_color.a, 0.0, disappear_progress)
		
		# Анимация мерцания (только когда светлячок видим)
		if firefly_data.sprite.modulate.a > 0:
			var pulse = sin(firefly_data.time * 5.0) * 0.1 + 0.9
			firefly_data.sprite.scale = Vector2(0.3, 0.3) * pulse
		
		# Если время жизни истекло, удаляем светлячка
		if firefly_data.lifetime <= 0:
			fireflies_to_remove.append(firefly_data)
	
	# Удаляем светлячков, которые завершили свой жизненный цикл
	for firefly_data in fireflies_to_remove:
		if active_fireflies.has(firefly_data):
			active_fireflies.erase(firefly_data)
		if is_instance_valid(firefly_data.node):
			firefly_data.node.queue_free()

func set_effect_intensity(intensity: float):
	# Регулируем интенсивность эффекта
	firefly_count = int(15 * intensity)
	spawn_radius = 600.0 * intensity
	
	# Очищаем текущих светлячков
	for firefly_data in active_fireflies:
		if is_instance_valid(firefly_data.node):
			firefly_data.node.queue_free()
	active_fireflies.clear()
	
	# Перезапускаем эффект
	_start_effect()
