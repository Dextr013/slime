# camera_shake.gd
extends Camera2D

var shake_amount := 0.0
var shake_duration := 0.0
var shake_timer := 0.0
var original_offset := Vector2.ZERO

# Эффект светлячков (будет установлен извне)
var fireflies_effect: Node = null

func _ready():
	original_offset = offset

func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		
		# Случайное смещение камеры
		offset = original_offset + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		
		# Затухание тряски
		shake_amount = lerp(shake_amount, 0.0, delta * 5.0)
	else:
		# Плавное возвращение к исходной позиции
		offset = lerp(offset, original_offset, delta * 10.0)

func shake(amount: float, duration: float):
	shake_amount = amount
	shake_duration = duration
	shake_timer = duration

func small_shake():
	shake(5.0, 0.2)

func medium_shake():
	shake(10.0, 0.3)

func big_shake():
	shake(20.0, 0.5)

# Методы для управления эффектом светлячков (опционально)
func set_fireflies_intensity(intensity: float):
	if fireflies_effect and fireflies_effect.has_method("set_effect_intensity"):
		fireflies_effect.set_effect_intensity(intensity)

func enable_fireflies():
	if fireflies_effect:
		fireflies_effect.visible = true
		fireflies_effect.set_process(true)

func disable_fireflies():
	if fireflies_effect:
		fireflies_effect.visible = false
		fireflies_effect.set_process(false)

func set_effects_paused(paused: bool):
	if fireflies_effect:
		fireflies_effect.set_process(!paused)
		fireflies_effect.visible = !paused

# Метод для установки эффекта извне
func set_fireflies_effect(effect_node: Node):
	fireflies_effect = effect_node
