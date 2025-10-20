# fog_effect.gd
extends Node2D

@export var fog_color: Color = Color(0.7, 0.8, 0.9, 0.15)  # Голубоватая дымка
@export var fog_density: float = 0.3
@export var fog_speed: float = 10.0
@export var fog_scale: float = 2.0

var fog_texture: Texture2D
var time: float = 0.0

func _ready():
	_create_fog_texture()
	set_process(true)

func _create_fog_texture():
	# Создаем текстуру для дымки с мягким градиентом
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(64, 64)
	var max_radius = 64.0
	
	for x in range(128):
		for y in range(128):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var normalized_dist = dist / max_radius
			
			if normalized_dist <= 1.0:
				# Создаем мягкий градиент от центра к краям
				var alpha = (1.0 - normalized_dist) * fog_density
				var color = fog_color
				color.a = alpha
				image.set_pixel(x, y, color)
	
	fog_texture = ImageTexture.create_from_image(image)

func _process(delta):
	time += delta
	queue_redraw()

func _draw():
	var viewport_size = get_viewport_rect().size
	
	# Рисуем несколько слоев дымки со смещением для создания движения
	for i in range(3):
		var offset_x = sin(time * fog_speed * 0.3 + i * 2.0) * 50.0
		var offset_y = cos(time * fog_speed * 0.2 + i * 1.5) * 30.0
		
		var scale_factor = fog_scale * (0.8 + i * 0.2)
		var rect_size = viewport_size * scale_factor
		var draw_position = -rect_size * 0.5 + Vector2(offset_x, offset_y)  # Переименовано из position
		
		# Рисуем дымку с разной прозрачностью для каждого слоя
		var layer_color = fog_color
		layer_color.a = fog_color.a * (0.3 + i * 0.3)
		
		draw_texture_rect(fog_texture, Rect2(draw_position, rect_size), false, layer_color)

func set_fog_intensity(intensity: float):
	"""Установка интенсивности тумана"""
	fog_density = 0.3 * intensity
	fog_color.a = 0.15 * intensity
	queue_redraw()
