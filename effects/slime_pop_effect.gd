extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var splash_particles: GPUParticles2D = $SplashParticles
@onready var shockwave_particles: GPUParticles2D = $ShockwaveParticles
@onready var light: PointLight2D = $PointLight2D

var slime_color := Color.WHITE

func _ready():
	await get_tree().process_frame
	
	if particles:
		particles.emitting = true
	
	if splash_particles:
		splash_particles.emitting = true
	
	if shockwave_particles:
		shockwave_particles.emitting = true
	
	if light:
		# Вспышка света
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.0, 0.6)
	
	# Удаляем после завершения
	var max_lifetime = 2.5
	if particles:
		max_lifetime = max(max_lifetime, particles.lifetime * 1.2)
	
	await get_tree().create_timer(max_lifetime).timeout
	queue_free()

func set_pop_properties(color: Color, scale_multiplier: float = 1.0):
	"""Настройка СОЧНОГО эффекта по цвету и размеру"""
	slime_color = color
	
	# Основные частицы (брызги)
	if particles:
		particles.scale = Vector2.ONE * scale_multiplier
		particles.amount = int(50 * scale_multiplier)  # Больше частиц
		
		var mat = particles.process_material as ParticleProcessMaterial
		if mat:
			# Создаем яркий градиент цвета
			var gradient = Gradient.new()
			gradient.add_point(0.0, color.lightened(0.3))  # Яркий старт
			gradient.add_point(0.2, color)
			gradient.add_point(0.5, color.darkened(0.1))
			gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
			
			var gradient_texture = GradientTexture1D.new()
			gradient_texture.gradient = gradient
			mat.color_ramp = gradient_texture
			
			# Увеличенная физика частиц для сочности
			mat.initial_velocity_min = 200.0 * scale_multiplier
			mat.initial_velocity_max = 450.0 * scale_multiplier
			mat.scale_min = 1.5 * scale_multiplier
			mat.scale_max = 3.5 * scale_multiplier
			mat.gravity = Vector3(0, 400, 0)
			mat.damping_min = 20.0
			mat.damping_max = 40.0
	
	# Частицы всплеска (большие капли)
	if splash_particles:
		splash_particles.scale = Vector2.ONE * scale_multiplier * 1.8
		splash_particles.amount = int(25 * scale_multiplier)
		
		var mat = splash_particles.process_material as ParticleProcessMaterial
		if mat:
			var gradient = Gradient.new()
			gradient.add_point(0.0, color.lightened(0.4))
			gradient.add_point(0.3, color.lightened(0.2))
			gradient.add_point(0.7, color)
			gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
			
			var gradient_texture = GradientTexture1D.new()
			gradient_texture.gradient = gradient
			mat.color_ramp = gradient_texture
			
			mat.initial_velocity_min = 120.0 * scale_multiplier
			mat.initial_velocity_max = 250.0 * scale_multiplier
			mat.scale_min = 3.0 * scale_multiplier
			mat.scale_max = 6.0 * scale_multiplier
			mat.gravity = Vector3(0, 500, 0)
			mat.damping_min = 15.0
			mat.damping_max = 30.0
	
	# Частицы ударной волны (кольцо)
	if shockwave_particles:
		shockwave_particles.scale = Vector2.ONE * scale_multiplier * 2.0
		shockwave_particles.amount = int(30 * scale_multiplier)
		
		var mat = shockwave_particles.process_material as ParticleProcessMaterial
		if mat:
			var gradient = Gradient.new()
			gradient.add_point(0.0, color.lightened(0.5))
			gradient.add_point(0.3, color.lightened(0.2))
			gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
			
			var gradient_texture = GradientTexture1D.new()
			gradient_texture.gradient = gradient
			mat.color_ramp = gradient_texture
			
			mat.initial_velocity_min = 150.0 * scale_multiplier
			mat.initial_velocity_max = 300.0 * scale_multiplier
			mat.scale_min = 2.0 * scale_multiplier
			mat.scale_max = 4.0 * scale_multiplier
			mat.radial_accel_min = 50.0
			mat.radial_accel_max = 100.0
	
	if light:
		light.color = color.lightened(0.3)
		light.energy = 3.0 * scale_multiplier
		light.texture_scale = 3.0 * scale_multiplier

func set_effect_properties(slime_type: int, scale_mult: float = 1.0):
	"""Совместимость со старым API"""
	var color := Color.WHITE
	var scale_multiplier := 1.0
	
	match slime_type:
		0:  # SMALL
			color = Color(0.3, 0.9, 0.3)
			scale_multiplier = 0.8 * scale_mult
		1:  # MEDIUM
			color = Color(0.9, 0.9, 0.3)
			scale_multiplier = 1.5 * scale_mult
		2:  # BOSS
			color = Color(0.9, 0.3, 0.2)
			scale_multiplier = 3.0 * scale_mult  # Еще больше для боссов
	
	set_pop_properties(color, scale_multiplier)
