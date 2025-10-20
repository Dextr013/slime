# menu.gd - ИСПРАВЛЕНО: кнопка "Играть" теперь работает на смартфонах
extends Control

var DebugChecker

@onready var play_button = $CenterContainer/VBoxContainer/PlayButton
@onready var animated_title = $CenterContainer/VBoxContainer/AnimatedTitle
@onready var high_score_label = $CenterContainer/VBoxContainer/HighScoreLabel

var sdk_timeout_reached := false
var data_timeout_reached := false
var safe_area_top := 0
var safe_area_bottom := 0
var is_ready := false

func _ready():
	_setup_display_mode()
	_setup_safe_area()
	_setup_fullscreen()
	_show_loading()
	
	# КРИТИЧНО: Подключаем кнопку ДО инициализации SDK
	_setup_play_button_early()
	
	# Инициализация SDK с таймаутом
	if OS.has_feature("web"):
		print("⏳ Waiting for Yandex Games SDK...")
		sdk_timeout_reached = false
		
		var timeout_timer = get_tree().create_timer(5.0)
		timeout_timer.timeout.connect(_on_sdk_timeout)
		
		await YandexGames.sdk_ready
		if not sdk_timeout_reached:
			print("✅ SDK initialized")
		else:
			print("⚠️ SDK timeout, using fallback")
	
	# ИСПРАВЛЕНО: Ждем готовности языка ПЕРЕД загрузкой данных
	if not I18n.is_ready:
		print("⏳ Waiting for I18n...")
		await I18n.language_ready
		print("✅ I18n ready")
	
	# Загрузка данных с таймаутом
	print("⏳ Loading game data...")
	data_timeout_reached = false
	var data_timer = get_tree().create_timer(5.0)  # ИСПРАВЛЕНО: увеличен до 5 секунд
	data_timer.timeout.connect(_on_data_timeout)
	
	# ИСПРАВЛЕНО: Прямой вызов без call_deferred для await
	GameManager.load_game_data()
	
	# Ждем завершения загрузки (с таймаутом)
	await get_tree().create_timer(5.0).timeout
	
	if not data_timeout_reached:
		print("✅ Game data loaded")
	else:
		print("⚠️ Game data load timeout, using defaults")
	
	_setup_ui()
	_hide_loading()
	
	# GameReady после всех загрузок
	if OS.has_feature("web"):
		print("📤 Sending GameReady...")
		YandexGames.send_game_ready()
		print("✅ GameReady sent")
	
	is_ready = true
	
	# Отладчик
	if Engine.has_singleton("DebugChecker"):
		DebugChecker = Engine.get_singleton("DebugChecker")
		DebugChecker.check_all()

func _setup_play_button_early():
	"""ИСПРАВЛЕНО: Надежная настройка кнопки для всех платформ"""
	if not play_button:
		push_error("❌ Play button not found!")
		return
	
	# Очищаем все существующие соединения
	if play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.disconnect(_on_play_pressed)
	if play_button.gui_input.is_connected(_on_play_button_gui_input):
		play_button.gui_input.disconnect(_on_play_button_gui_input)
	
	# КРИТИЧНО: Подключаем оба сигнала для максимальной надежности
	play_button.pressed.connect(_on_play_pressed)
	play_button.gui_input.connect(_on_play_button_gui_input)
	
	# Обязательные настройки для тач-устройств
	play_button.focus_mode = Control.FOCUS_ALL
	play_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# НОВОЕ: Принудительно активируем кнопку
	play_button.disabled = false
	play_button.visible = true
	
	print("✅ Play button early setup complete")

func _on_play_button_gui_input(event: InputEvent):
	"""ИСПРАВЛЕНО: Улучшенная обработка всех типов ввода"""
	if not is_ready or not play_button or play_button.disabled:
		return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			print("👆 Touch detected on play button!")
			# Помечаем событие как обработанное
			get_viewport().set_input_as_handled()
			_on_play_pressed()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("🖱️ Click detected on play button!")
			get_viewport().set_input_as_handled()
			_on_play_pressed()

func _setup_display_mode():
	"""Настройка режима отображения"""
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		print("📱 Mobile portrait mode")
	elif OS.has_feature("web"):
		var screen_size = DisplayServer.screen_get_size()
		if screen_size.x < screen_size.y:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
			print("🌐 Web mobile portrait")
		else:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
			print("🌐 Web desktop landscape")
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		print("💻 Desktop landscape")

func _setup_safe_area():
	"""Настройка Safe Area для iOS"""
	if OS.has_feature("mobile"):
		var safe_rect = DisplayServer.get_display_safe_area()
		safe_area_top = safe_rect.position.y
		safe_area_bottom = DisplayServer.screen_get_size().y - (safe_rect.position.y + safe_rect.size.y)
		
		print("📱 Safe Area - Top: ", safe_area_top, " Bottom: ", safe_area_bottom)
		
		var center_container = $CenterContainer
		if center_container and safe_area_top > 0:
			center_container.add_theme_constant_override("margin_top", safe_area_top)
			center_container.add_theme_constant_override("margin_bottom", safe_area_bottom)
			print("✅ Menu adjusted for safe area")

func _on_sdk_timeout():
	if not YandexGames.is_initialized:
		sdk_timeout_reached = true
		print("⚠️ SDK timeout")
		YandexGames.is_initialized = true
		YandexGames.emit_signal("sdk_ready")

func _on_data_timeout():
	data_timeout_reached = true
	print("⚠️ Data timeout")

func _setup_fullscreen():
	var window = get_window()
	if window:
		if OS.has_feature("mobile") or OS.has_feature("web"):
			window.mode = Window.MODE_FULLSCREEN
		else:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(1280, 720)
		
		window.unresizable = true
		print("🖥️ Window size: ", window.size)
		
		_setup_menu_viewport()
		
		if OS.has_feature("web"):
			_apply_web_fullscreen_fix()
		
		print("✅ Menu setup complete")

func _setup_menu_viewport():
	var viewport = get_viewport()
	if viewport:
		viewport.size = get_window().size
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		
		if OS.has_feature("mobile") or (OS.has_feature("web") and DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_PORTRAIT):
			viewport.size_2d_override_size = Vector2i(720, 1280)
		else:
			viewport.size_2d_override_size = Vector2i(1280, 720)
		
		print("📱 Menu viewport: ", viewport.size)

func _apply_web_fullscreen_fix():
	var js_code = """
	(function() {
		var style = document.createElement('style');
		style.textContent = `
			* { 
				margin: 0; 
				padding: 0; 
				box-sizing: border-box;
				-webkit-tap-highlight-color: transparent;
			}
			html, body { 
				width: 100%; 
				height: 100%; 
				overflow: hidden; 
				background: #000;
				position: fixed;
				touch-action: manipulation;
				-webkit-user-select: none;
				user-select: none;
			}
			canvas { 
				width: 100% !important; 
				height: 100% !important; 
				display: block;
				position: fixed;
				top: 0; 
				left: 0;
				touch-action: none;
			}
		`;
		document.head.appendChild(style);
		
		// КРИТИЧНО: Предотвращаем ВСЕ жесты браузера
		var preventDefault = function(e) { 
			e.preventDefault(); 
			return false; 
		};
		
		document.addEventListener('gesturestart', preventDefault);
		document.addEventListener('gesturechange', preventDefault);
		document.addEventListener('gestureend', preventDefault);
		
		// Предотвращаем масштабирование
		document.addEventListener('touchstart', function(e) {
			if (e.touches.length > 1) {
				e.preventDefault();
			}
		}, { passive: false });
		
		document.addEventListener('touchmove', function(e) {
			if (e.touches.length > 1) {
				e.preventDefault();
			}
		}, { passive: false });
		
		// НОВОЕ: Убираем задержку 300ms на клики
		var FastClick = function(element) {
			var timeout;
			element.addEventListener('touchstart', function() {
				timeout = setTimeout(function() {
					timeout = null;
				}, 300);
			});
			element.addEventListener('touchend', function(event) {
				if (timeout) {
					clearTimeout(timeout);
					event.preventDefault();
					event.target.click();
					return false;
				}
			});
		};
		
		// Применяем FastClick ко всему документу
		if (document.body) {
			FastClick(document.body);
		}
		
		// Предотвращаем двойной тап для зума
		var lastTouchEnd = 0;
		document.addEventListener('touchend', function(event) {
			var now = Date.now();
			if (now - lastTouchEnd <= 300) {
				event.preventDefault();
			}
			lastTouchEnd = now;
		}, false);
		
		console.log('✅ Web fullscreen fix with FastClick applied');
	})();
	"""
	JavaScriptBridge.eval(js_code)

func _show_loading():
	if play_button:
		play_button.disabled = true
		play_button.text = I18n.translate("loading")

func _hide_loading():
	if play_button:
		play_button.disabled = false
		# ИСПРАВЛЕНО: Гарантируем что язык готов
		play_button.text = I18n.translate("play") if I18n.is_ready else "PLAY"

func _setup_ui():
	if animated_title and animated_title.has_method("set_rainbow_colors"):
		animated_title.set_rainbow_colors()
	
	if not play_button:
		push_error("❌ Play button not found in _setup_ui!")
		return
	
	play_button.text = I18n.translate("play")
	
	# ИСПРАВЛЕНО: Еще больше увеличиваем для надежности
	if OS.has_feature("mobile") or OS.has_feature("web"):
		# Очень большая кнопка
		play_button.custom_minimum_size = Vector2(600, 180)
		play_button.add_theme_font_size_override("font_size", 56)
		
		# КРИТИЧНО: Создаем стиль с padding
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.6, 1.0, 0.9)
		style_normal.corner_radius_top_left = 25
		style_normal.corner_radius_top_right = 25
		style_normal.corner_radius_bottom_left = 25
		style_normal.corner_radius_bottom_right = 25
		style_normal.content_margin_top = 50
		style_normal.content_margin_bottom = 50
		style_normal.content_margin_left = 80
		style_normal.content_margin_right = 80
		style_normal.border_width_left = 4
		style_normal.border_width_top = 4
		style_normal.border_width_right = 4
		style_normal.border_width_bottom = 4
		style_normal.border_color = Color.WHITE
		play_button.add_theme_stylebox_override("normal", style_normal)
		
		# Стиль при нажатии
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.1, 0.4, 0.8, 1.0)
		style_pressed.corner_radius_top_left = 25
		style_pressed.corner_radius_top_right = 25
		style_pressed.corner_radius_bottom_left = 25
		style_pressed.corner_radius_bottom_right = 25
		style_pressed.content_margin_top = 50
		style_pressed.content_margin_bottom = 50
		style_pressed.content_margin_left = 80
		style_pressed.content_margin_right = 80
		play_button.add_theme_stylebox_override("pressed", style_pressed)
		
		# Стиль при наведении
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.3, 0.7, 1.0, 1.0)
		style_hover.corner_radius_top_left = 25
		style_hover.corner_radius_top_right = 25
		style_hover.corner_radius_bottom_left = 25
		style_hover.corner_radius_bottom_right = 25
		style_hover.content_margin_top = 50
		style_hover.content_margin_bottom = 50
		style_hover.content_margin_left = 80
		style_hover.content_margin_right = 80
		play_button.add_theme_stylebox_override("hover", style_hover)
		
		print("📱 Mobile-optimized LARGE button: 600x180")
	else:
		play_button.custom_minimum_size = Vector2(300, 80)
		play_button.add_theme_font_size_override("font_size", 32)
	
	# КРИТИЧНО: Убеждаемся что кнопка активна
	play_button.disabled = false
	play_button.visible = true
	play_button.mouse_filter = Control.MOUSE_FILTER_STOP
	play_button.focus_mode = Control.FOCUS_ALL
	
	var high_score = GameManager.get_high_score()
	if high_score > 0:
		high_score_label.text = I18n.translate("high_score") + ": " + str(high_score)
		high_score_label.visible = true
		
		if OS.has_feature("mobile") or OS.has_feature("web"):
			high_score_label.add_theme_font_size_override("font_size", 32)
		else:
			high_score_label.add_theme_font_size_override("font_size", 24)
	else:
		high_score_label.visible = false
	
	print("✅ UI setup complete, button enabled: ", !play_button.disabled)

func _on_play_pressed():
	"""ИСПРАВЛЕНО: Дополнительные проверки и логирование"""
	print("🎮 PLAY BUTTON PRESSED!")
	
	# Защита от двойного нажатия
	if not is_ready:
		print("⚠️ Game not ready yet, ignoring")
		return
	
	# Деактивируем кнопку сразу
	if play_button:
		play_button.disabled = true
		play_button.text = I18n.translate("loading")
	
	print("🎮 Starting game from menu")
	
	if OS.has_feature("web"):
		YandexGames.gameplay_start()
	
	# Небольшая задержка для стабильности
	await get_tree().create_timer(0.2).timeout
	
	print("🎮 Changing scene to game.tscn")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _input(event):
	"""ИСПРАВЛЕНО: Улучшенная глобальная обработка ввода"""
	if not is_ready:
		return
	
	# Проверяем тап по области кнопки (fallback для тач-устройств)
	if event is InputEventScreenTouch and event.pressed:
		if play_button and play_button.visible and not play_button.disabled:
			var button_rect = play_button.get_global_rect()
			# ИСПРАВЛЕНО: Добавлена небольшая зона расширения для удобства
			var expanded_rect = button_rect.grow(20)
			if expanded_rect.has_point(event.position):
				print("👆 Global touch detected on button area!")
				get_viewport().set_input_as_handled()
				_on_play_pressed()
				return
	
	# Поддержка клавиатуры для десктопа/отладки
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if play_button and play_button.visible and not play_button.disabled:
				print("⌨️ Keyboard shortcut - starting game")
				_on_play_pressed()
		elif event.keycode == KEY_ESCAPE:
			print("ESC pressed")
			GameManager.call_deferred("save_game_data")
			await get_tree().create_timer(0.5).timeout
			get_tree().quit()

func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			print("🚪 Window close request")
			GameManager.call_deferred("save_game_data")
			await get_tree().create_timer(0.5).timeout
			get_tree().quit()
		
		NOTIFICATION_WM_GO_BACK_REQUEST:
			print("🔙 Android back button")
			GameManager.call_deferred("save_game_data")
			await get_tree().create_timer(0.5).timeout
			get_tree().quit()
		
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			print("📱 App lost focus")
			if GameManager and GameManager.game_active:
				GameManager.call_deferred("save_game_data")
		
		NOTIFICATION_APPLICATION_FOCUS_IN:
			print("📱 App gained focus")

func _exit_tree():
	print("🚪 Exiting menu")
	if play_button:
		if play_button.pressed.is_connected(_on_play_pressed):
			play_button.pressed.disconnect(_on_play_pressed)
		if play_button.gui_input.is_connected(_on_play_button_gui_input):
			play_button.gui_input.disconnect(_on_play_button_gui_input)
