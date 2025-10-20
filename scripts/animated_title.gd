# animated_title.gd
extends VBoxContainer

# Экспортируемые настройки для редактора
@export_category("Title Settings")
@export var use_translation: bool = true  # Использовать перевод из I18n
@export var title_text: String = "SLIME POP"
@export var letter_colors: Array[Color] = []
@export var wave_speed: float = 2.0
@export var wave_amplitude: float = 15.0
@export var letter_spacing: float = 5.0
@export var font_size: int = 72

var letter_labels: Array[Label] = []
var time_passed: float = 0.0

func _ready():
	# Если используем перевод - получаем текст из I18n
	if use_translation and I18n:
		title_text = I18n.translate("title_label")
	
	_create_title()
	_apply_default_colors()

func _create_title():
	# Очищаем предыдущие буквы
	for child in get_children():
		child.queue_free()
	letter_labels.clear()
	
	# Создаем контейнер для букв
	var letters_container = HBoxContainer.new()
	letters_container.alignment = BoxContainer.ALIGNMENT_CENTER
	letters_container.add_theme_constant_override("separation", int(letter_spacing))
	add_child(letters_container)
	
	# Создаем Label для каждой буквы
	for i in range(title_text.length()):
		var letter = title_text[i]
		var label = Label.new()
		label.text = letter
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 12)
		
		# Применяем цвет если он задан
		if i < letter_colors.size():
			label.add_theme_color_override("font_color", letter_colors[i])
		
		letters_container.add_child(label)
		letter_labels.append(label)

func _apply_default_colors():
	"""Применяет радужные цвета по умолчанию если не заданы"""
	if letter_colors.is_empty():
		letter_colors = _generate_rainbow_colors(title_text.length())
		_update_letter_colors()

func _generate_rainbow_colors(count: int) -> Array[Color]:
	"""Генерирует радужный градиент"""
	var colors: Array[Color] = []
	for i in range(count):
		var hue = float(i) / float(count)
		colors.append(Color.from_hsv(hue, 0.8, 1.0))
	return colors

func _update_letter_colors():
	"""Обновляет цвета букв"""
	for i in range(min(letter_labels.size(), letter_colors.size())):
		letter_labels[i].add_theme_color_override("font_color", letter_colors[i])

func _process(delta):
	time_passed += delta * wave_speed
	
	# Анимация волны для каждой буквы
	for i in range(letter_labels.size()):
		var label = letter_labels[i]
		var wave_offset = sin(time_passed + i * 0.5) * wave_amplitude
		label.position.y = wave_offset

# Методы для изменения из редактора
func set_title(text: String):
	title_text = text
	if is_inside_tree():
		_create_title()
		_apply_default_colors()

func set_colors(colors: Array[Color]):
	letter_colors = colors
	if is_inside_tree():
		_update_letter_colors()

func set_rainbow_colors():
	"""Устанавливает радужные цвета"""
	letter_colors = _generate_rainbow_colors(title_text.length())
	_update_letter_colors()

func set_gradient_colors(color1: Color, color2: Color):
	"""Устанавливает градиент между двумя цветами"""
	letter_colors.clear()
	for i in range(title_text.length()):
		var t = float(i) / float(title_text.length() - 1)
		letter_colors.append(color1.lerp(color2, t))
	_update_letter_colors()
