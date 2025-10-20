# game.gd - ИСПРАВЛЕНО: убраны зависания при достижениях
extends Node2D

enum SlimeType { SMALL, MEDIUM, BOSS }

@export_category("Game Settings")
@export var max_slimes_on_screen: int = 15
@export var base_slimes_per_wave: int = 25
@export var base_wave_duration: float = 30.0
@export var base_min_spawn_interval: float = 0.5
@export var base_max_spawn_interval: float = 1.0

@export_category("Visual Effects")
@export var enable_fireflies: bool = true
@export var enable_fog: bool = true
@export var fireflies_intensity: float = 1.0
@export var fog_intensity: float = 1.0

@export_category("Difficulty Scaling")
@export var wave_slime_count_multiplier: float = 1.1
@export var wave_speed_multiplier: float = 1.05
@export var wave_spawn_rate_multiplier: float = 0.95

var slime_scene = preload("res://scenes/slime.tscn")

@onready var spawn_timer = $SpawnTimer
@onready var wave_timer = $WaveTimer
@onready var ui = $UI
@onready var camera = $Camera2D
@onready var background = $Background
@onready var fireflies_effect = $FirefliesEffect
@onready var fog_effect = $FogEffect

var slimes_spawned := 0
var current_slimes_on_screen := 0
var slimes_missed := 0
var current_slimes_per_wave: int
var current_wave_duration: float
var current_min_spawn_interval: float
var current_max_spawn_interval: float
var spawn_zone_width := 0.0
var spawn_zone_start_x := 0.0
var spawn_zone_end_x := 0.0
var instructions_shown := false

# Фиксированные размеры игрового мира
var GAME_WIDTH := 1280
var GAME_HEIGHT := 720

# Safe Area для iOS
var safe_area_top := 0
var safe_area_bottom := 0

func _ready():
	add_to_group("game_node")
	
	_setup_display_mode()
	_setup_fullscreen()
	_setup_safe_area() # iOS Safe Area
	_setup_camera()
	_setup_adaptive_background()
	_setup_effects()
	_setup_wave_timer_ui()
	_calculate_spawn_zone()
	
	# ИСПРАВЛЕНО: Ждем готовности языка перед стартом игры
	if not I18n.is_ready:
		await I18n.language_ready
	
	GameManager.start_game()
	_connect_signals()
	
	# ИСПРАВЛЕНО: Принудительное обновление всех UI элементов с правильным языком
	_update_all_ui_texts()
	
	call_deferred("_show_instructions")

func _setup_display_mode():
	"""Настройка режима отображения"""
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		GAME_WIDTH = 720
		GAME_HEIGHT = 1280
		print("📱 Mobile portrait mode: ", GAME_WIDTH, "x", GAME_HEIGHT)
	elif OS.has_feature("web"):
		var screen_size = DisplayServer.screen_get_size()
		if screen_size.x < screen_size.y:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
			GAME_WIDTH = 720
			GAME_HEIGHT = 1280
			print("🌐 Web mobile portrait mode")
		else:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
			GAME_WIDTH = 1280
			GAME_HEIGHT = 720
			print("🌐 Web desktop landscape mode")
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		GAME_WIDTH = 1280
		GAME_HEIGHT = 720
		print("💻 Desktop landscape mode")

func _setup_safe_area():
	"""Настройка Safe Area для iOS"""
	if OS.has_feature("mobile"):
		var safe_rect = DisplayServer.get_display_safe_area()
		safe_area_top = safe_rect.position.y
		safe_area_bottom = DisplayServer.screen_get_size().y - (safe_rect.position.y + safe_rect.size.y)
		
		print("📱 Safe Area - Top: ", safe_area_top, " Bottom: ", safe_area_bottom)
		
		# Сдвигаем UI элементы
		if safe_area_top > 0:
			var top_bar = ui.get_node_or_null("TopBar")
			if top_bar:
				top_bar.offset_top = safe_area_top
				print("✅ TopBar adjusted for safe area")

func _setup_fullscreen():
	var window = get_window()
	if window:
		if OS.has_feature("mobile") or OS.has_feature("web"):
			window.mode = Window.MODE_FULLSCREEN
		else:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(GAME_WIDTH, GAME_HEIGHT)
		
		window.unresizable = true
		print("🎮 Game window size: ", window.size)
		
		if OS.has_feature("web"):
			_apply_web_fullscreen_fix()
		
		print("✅ Game display setup complete")

func _apply_web_fullscreen_fix():
	var js_code = """
	(function() {
		var style = document.createElement('style');
		style.textContent = `
			* { margin: 0; padding: 0; box-sizing: border-box; }
			html, body { 
				width: 100%; height: 100%; 
				overflow: hidden; 
				background: #000;
				position: fixed;
				touch-action: manipulation;
				-webkit-tap-highlight-color: transparent;
			}
			canvas { 
				width: 100% !important; 
				height: 100% !important; 
				display: block;
				position: fixed;
				top: 0; left: 0;
			}
		`;
		document.head.appendChild(style);
		
		document.addEventListener('touchstart', function(e) {
			if (e.touches.length > 1) e.preventDefault();
		}, { passive: false });
		
		console.log('✅ Web fullscreen fix applied');
	})();
	"""
	JavaScriptBridge.eval(js_code)

func _setup_camera():
	if camera:
		camera.position = Vector2(GAME_WIDTH / 2.0, GAME_HEIGHT / 2.0)
		camera.zoom = Vector2.ONE
		camera.make_current()
		print("📷 Camera setup complete")

func _setup_adaptive_background():
	"""ИСПРАВЛЕНО: фон без полос"""
	if not background:
		return
		
	print("🎨 Setting up adaptive background...")
	
	if background is TextureRect:
		# Полноэкранный фон
		background.size = Vector2(GAME_WIDTH, GAME_HEIGHT)
		background.position = Vector2.ZERO
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		# Центрируем фон
		background.anchor_left = 0
		background.anchor_top = 0
		background.anchor_right = 1
		background.anchor_bottom = 1
		background.grow_horizontal = Control.GROW_DIRECTION_BOTH
		background.grow_vertical = Control.GROW_DIRECTION_BOTH
		
		print("✅ Background adapted (no borders)")
		
	elif background is Sprite2D:
		background.centered = true
		background.position = Vector2(GAME_WIDTH / 2.0, GAME_HEIGHT / 2.0)
		
		if background.texture:
			var texture_size = background.texture.get_size()
			var scale_x = GAME_WIDTH / texture_size.x
			var scale_y = GAME_HEIGHT / texture_size.y
			# Увеличиваем масштаб чтобы покрыть весь экран
			var scale_factor = max(scale_x, scale_y) * 1.2
			background.scale = Vector2(scale_factor, scale_factor)
		
		print("✅ Background (Sprite2D) scaled to cover")

func _setup_effects():
	if fireflies_effect:
		fireflies_effect.visible = enable_fireflies
		fireflies_effect.set_process(enable_fireflies)
		if enable_fireflies and fireflies_effect.has_method("set_effect_intensity"):
			fireflies_effect.set_effect_intensity(fireflies_intensity)
		
		if camera and camera.has_method("set_fireflies_effect"):
			camera.set_fireflies_effect(fireflies_effect)
	
	if fog_effect:
		fog_effect.visible = enable_fog
		fog_effect.set_process(enable_fog)
		if enable_fog and fog_effect.has_method("set_fog_intensity"):
			fog_effect.set_fog_intensity(fog_intensity)

func _setup_wave_timer_ui():
	var vbox = ui.get_node_or_null("TopBar/VBoxContainer")
	if vbox:
		var existing_timer = vbox.get_node_or_null("WaveTimerLabel")
		if existing_timer:
			return
			
		var wave_timer_label = Label.new()
		wave_timer_label.name = "WaveTimerLabel"
		wave_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wave_timer_label.add_theme_font_size_override("font_size", 20)
		wave_timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
		vbox.add_child(wave_timer_label)

func _calculate_spawn_zone():
	spawn_zone_width = GAME_WIDTH * 0.8
	spawn_zone_start_x = (GAME_WIDTH - spawn_zone_width) / 2.0
	spawn_zone_end_x = spawn_zone_start_x + spawn_zone_width
	print("🎯 Spawn zone: %.1f to %.1f" % [spawn_zone_start_x, spawn_zone_end_x])

func _show_instructions():
	print("📋 Showing instructions panel...")
	var instructions_panel = ui.get_node_or_null("InstructionsPanel")
	if instructions_panel:
		instructions_panel.visible = true
		instructions_shown = true
		
		var title = instructions_panel.get_node_or_null("Panel/VBoxContainer/Title")
		if title:
			title.text = I18n.translate("how_to_play")
		
		var instructions_text = instructions_panel.get_node_or_null("Panel/VBoxContainer/InstructionsText")
		if instructions_text:
			instructions_text.text = I18n.get_instructions_text()
		
		var start_button = instructions_panel.get_node_or_null("Panel/VBoxContainer/StartButton")
		if start_button:
			start_button.text = I18n.translate("start_game")
			
			# ИСПРАВЛЕНО: увеличенная область нажатия для мобильных
			if OS.has_feature("mobile") or OS.has_feature("web"):
				start_button.custom_minimum_size = Vector2(500, 120)
				start_button.add_theme_font_size_override("font_size", 42)
			
			if start_button.pressed.is_connected(_on_start_game_pressed):
				start_button.pressed.disconnect(_on_start_game_pressed)
			start_button.pressed.connect(_on_start_game_pressed)
			print("✅ Start button connected")

func _on_start_game_pressed():
	print("🎮 START GAME BUTTON PRESSED!")
	var instructions_panel = ui.get_node_or_null("InstructionsPanel")
	if instructions_panel:
		instructions_panel.visible = false
	_start_wave()

func _connect_signals():
	print("🔗 Connecting signals...")
	
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	GameManager.game_over.connect(_on_game_over)
	# ИСПРАВЛЕНО: убран await из обработчика сигнала
	GameManager.achievement_earned.connect(_on_achievement_earned)
	
	# ИСПРАВЛЕНО: Подписываемся на изменение языка
	if I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.disconnect(_on_language_changed)
	I18n.language_changed.connect(_on_language_changed)
	
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	
	var pause_button = ui.get_node_or_null("PauseButton")
	if pause_button:
		if pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.disconnect(_on_pause_pressed)
		pause_button.pressed.connect(_on_pause_pressed)
		
		# ИСПРАВЛЕНО: увеличена кнопка для мобильных
		if OS.has_feature("mobile") or OS.has_feature("web"):
			pause_button.custom_minimum_size = Vector2(100, 100)
			pause_button.add_theme_font_size_override("font_size", 48)
	
	var pause_panel = ui.get_node_or_null("PausePanel/Panel")
	if pause_panel:
		var resume_btn = pause_panel.get_node_or_null("VBoxContainer/ResumeButton")
		if resume_btn:
			if resume_btn.pressed.is_connected(_on_resume_pressed):
				resume_btn.pressed.disconnect(_on_resume_pressed)
			resume_btn.pressed.connect(_on_resume_pressed)
			
			if OS.has_feature("mobile") or OS.has_feature("web"):
				resume_btn.custom_minimum_size = Vector2(500, 120)
				resume_btn.add_theme_font_size_override("font_size", 42)
		
		# ИСПРАВЛЕНО: Добавлена локализация и обработка кнопки Menu в паузе
		var menu_btn_pause = pause_panel.get_node_or_null("VBoxContainer/MenuButton")
		if menu_btn_pause:
			menu_btn_pause.text = I18n.translate("main_menu")
			if menu_btn_pause.pressed.is_connected(_on_pause_menu_pressed):
				menu_btn_pause.pressed.disconnect(_on_pause_menu_pressed)
			menu_btn_pause.pressed.connect(_on_pause_menu_pressed)
			
			if OS.has_feature("mobile") or OS.has_feature("web"):
				menu_btn_pause.custom_minimum_size = Vector2(500, 120)
				menu_btn_pause.add_theme_font_size_override("font_size", 42)
	
	var game_over_panel = ui.get_node_or_null("GameOverPanel/Panel")
	if game_over_panel:
		var restart_btn = game_over_panel.get_node_or_null("VBoxContainer/RestartButton")
		if restart_btn:
			if restart_btn.pressed.is_connected(_on_restart_pressed):
				restart_btn.pressed.disconnect(_on_restart_pressed)
			restart_btn.pressed.connect(_on_restart_pressed)
			
			if OS.has_feature("mobile") or OS.has_feature("web"):
				restart_btn.custom_minimum_size = Vector2(500, 120)
				restart_btn.add_theme_font_size_override("font_size", 42)
		
		# ИСПРАВЛЕНО: Добавлена локализация и обработка кнопки Menu в game over
		var menu_btn_gameover = game_over_panel.get_node_or_null("VBoxContainer/MenuButton")
		if menu_btn_gameover:
			menu_btn_gameover.text = I18n.translate("main_menu")
			if menu_btn_gameover.pressed.is_connected(_on_gameover_menu_pressed):
				menu_btn_gameover.pressed.disconnect(_on_gameover_menu_pressed)
			menu_btn_gameover.pressed.connect(_on_gameover_menu_pressed)
			
			if OS.has_feature("mobile") or OS.has_feature("web"):
				menu_btn_gameover.custom_minimum_size = Vector2(500, 120)
				menu_btn_gameover.add_theme_font_size_override("font_size", 42)
	
	print("✅ All signals connected")

func _start_wave():
	print("🌊 Starting wave...")
	GameManager.next_wave()
	slimes_spawned = 0
	slimes_missed = 0
	current_slimes_on_screen = 0
	
	var wave = GameManager.wave
	
	current_slimes_per_wave = int(base_slimes_per_wave * pow(wave_slime_count_multiplier, wave - 1))
	current_wave_duration = base_wave_duration * pow(wave_spawn_rate_multiplier, wave - 1)
	current_min_spawn_interval = base_min_spawn_interval * pow(wave_spawn_rate_multiplier, wave - 1)
	current_max_spawn_interval = base_max_spawn_interval * pow(wave_spawn_rate_multiplier, wave - 1)
	
	current_min_spawn_interval = max(0.1, current_min_spawn_interval)
	current_max_spawn_interval = max(0.2, current_max_spawn_interval)
	
	spawn_timer.wait_time = randf_range(current_min_spawn_interval, current_max_spawn_interval)
	spawn_timer.start()
	
	wave_timer.wait_time = current_wave_duration
	wave_timer.start()
	
	_update_wave_ui()

func _update_wave_ui():
	var wave_timer_label = ui.get_node_or_null("TopBar/VBoxContainer/WaveTimerLabel")
	if wave_timer_label and wave_timer:
		var time_left = wave_timer.time_left
		var minutes = int(floor(time_left / 60.0))
		var seconds = int(floor(time_left)) % 60
		wave_timer_label.text = "%02d:%02d" % [minutes, seconds]

func _process(_delta):
	if not GameManager.game_active or GameManager.paused:
		return
	_update_wave_ui()

func _on_spawn_timer_timeout():
	if not GameManager.game_active or GameManager.paused:
		return
	
	if current_slimes_on_screen >= max_slimes_on_screen:
		spawn_timer.wait_time = randf_range(0.1, 0.3)
		spawn_timer.start()
		return
	
	if slimes_spawned < current_slimes_per_wave:
		_spawn_slime()
		slimes_spawned += 1
		current_slimes_on_screen += 1
		spawn_timer.wait_time = randf_range(current_min_spawn_interval, current_max_spawn_interval)
		spawn_timer.start()

func _spawn_slime():
	var slime = slime_scene.instantiate()
	
	var wave = GameManager.wave
	var rand = randf()
	
	if wave >= 6 and rand < 0.25:
		slime.slime_type = SlimeType.BOSS
	elif wave >= 3 and rand < 0.5:
		slime.slime_type = SlimeType.MEDIUM
	else:
		slime.slime_type = SlimeType.SMALL
	
	var speed_multiplier = pow(wave_speed_multiplier, wave - 1)
	slime.wave_speed_multiplier = speed_multiplier
	
	slime.position = Vector2(
		randf_range(spawn_zone_start_x, spawn_zone_end_x),
		-100
	)
	
	slime.reached_bottom.connect(_on_slime_reached_bottom)
	slime.slime_killed.connect(_on_slime_killed)
	
	add_child(slime)

func _on_slime_reached_bottom():
	slimes_missed += 1
	current_slimes_on_screen -= 1
	GameManager.take_damage()

func _on_slime_killed(type: int, _pos: Vector2):
	current_slimes_on_screen -= 1
	
	if camera:
		match type:
			SlimeType.SMALL:
				if camera.has_method("small_shake"):
					camera.small_shake()
			SlimeType.MEDIUM:
				if camera.has_method("medium_shake"):
					camera.medium_shake()
			SlimeType.BOSS:
				if camera.has_method("big_shake"):
					camera.big_shake()

func _on_wave_timer_timeout():
	if not GameManager.game_active:
		return
	_start_wave()

func _on_score_changed(score):
	var label = ui.get_node_or_null("TopBar/VBoxContainer/ScoreLabel")
	if label:
		label.text = I18n.translate("score") + ": " + str(score)

func _on_health_changed(health):
	var label = ui.get_node_or_null("TopBar/VBoxContainer/HealthLabel")
	if label:
		label.text = I18n.translate("health") + ": " + str(health) + "/" + str(GameManager.max_health)

func _on_wave_changed(wave):
	var label = ui.get_node_or_null("TopBar/VBoxContainer/WaveLabel")
	if label:
		label.text = I18n.translate("wave") + ": " + str(wave)

func _on_language_changed(_lang: String):
	"""НОВОЕ: Обновление всех UI элементов при смене языка"""
	print("🌍 Language changed, updating all UI texts")
	_update_all_ui_texts()

func _update_all_ui_texts():
	"""НОВОЕ: Принудительное обновление всех текстов UI"""
	# Обновляем основные лейблы
	var score_label = ui.get_node_or_null("TopBar/VBoxContainer/ScoreLabel")
	if score_label:
		score_label.text = I18n.translate("score") + ": " + str(GameManager.score)
	
	var health_label = ui.get_node_or_null("TopBar/VBoxContainer/HealthLabel")
	if health_label:
		health_label.text = I18n.translate("health") + ": " + str(GameManager.health) + "/" + str(GameManager.max_health)
	
	var wave_label = ui.get_node_or_null("TopBar/VBoxContainer/WaveLabel")
	if wave_label:
		wave_label.text = I18n.translate("wave") + ": " + str(GameManager.wave)
	
	# Обновляем кнопки
	var pause_button = ui.get_node_or_null("PauseButton")
	if pause_button:
		pause_button.text = "||"  # Pause всегда символ
	
	print("✅ All UI texts updated with current language")

func _on_game_over():
	spawn_timer.stop()
	wave_timer.stop()
	
	# ИСПРАВЛЕНО: сохранение без блокировки
	GameManager.save_game_data()
	
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.stop_music()
	
	_display_game_over_screen()

func _display_game_over_screen():
	var panel_container = ui.get_node_or_null("GameOverPanel")
	if panel_container:
		panel_container.visible = true
		
		var panel = panel_container.get_node_or_null("Panel/VBoxContainer")
		if panel:
			var title = panel.get_node_or_null("Title")
			if title:
				title.text = I18n.translate("game_over")
			
			var final_score = panel.get_node_or_null("FinalScore")
			if final_score:
				final_score.text = I18n.translate("score") + ": " + str(GameManager.score)
			
			var high_score = panel.get_node_or_null("HighScore")
			if high_score:
				high_score.text = I18n.translate("high_score") + ": " + str(GameManager.get_high_score())
			
			var restart_btn = panel.get_node_or_null("RestartButton")
			if restart_btn:
				restart_btn.text = I18n.translate("restart")
				if OS.has_feature("mobile") or OS.has_feature("web"):
					restart_btn.custom_minimum_size = Vector2(500, 120)
					restart_btn.add_theme_font_size_override("font_size", 42)

func _on_achievement_earned(_achievement_id, achievement_name):
	"""ИСПРАВЛЕНО: без await - не блокирует игру"""
	print("🏆 Achievement earned: ", achievement_name)
	
	var notif = ui.get_node_or_null("AchievementNotification")
	if not notif:
		print("⚠️ Achievement notification node not found")
		return
	
	var label = notif.get_node_or_null("Panel/Label")
	if label:
		label.text = I18n.translate("achievement") + "\n" + achievement_name
	
	notif.visible = true
	
	# Используем таймер вместо await
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(notif):
			notif.visible = false
	)

func _on_pause_pressed():
	print("⏸️ Pause pressed")
	GameManager.toggle_pause()
	
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.pause_music()
	
	var panel = ui.get_node_or_null("PausePanel")
	if panel:
		panel.visible = GameManager.paused
		
		if GameManager.paused:
			_update_pause_panel_texts()

func _update_pause_panel_texts():
	var pause_panel = ui.get_node_or_null("PausePanel/Panel/VBoxContainer")
	if pause_panel:
		var title = pause_panel.get_node_or_null("Title")
		if title:
			title.text = I18n.translate("game_paused")
		
		var resume_btn = pause_panel.get_node_or_null("ResumeButton")
		if resume_btn:
			resume_btn.text = I18n.translate("resume")
			if OS.has_feature("mobile") or OS.has_feature("web"):
				resume_btn.custom_minimum_size = Vector2(500, 120)
				resume_btn.add_theme_font_size_override("font_size", 42)
		
		# ИСПРАВЛЕНО: Локализация кнопки Menu
		var menu_btn = pause_panel.get_node_or_null("MenuButton")
		if menu_btn:
			menu_btn.text = I18n.translate("main_menu")
			if OS.has_feature("mobile") or OS.has_feature("web"):
				menu_btn.custom_minimum_size = Vector2(500, 120)
				menu_btn.add_theme_font_size_override("font_size", 42)

func _on_resume_pressed():
	print("▶️ Resume pressed")
	GameManager.toggle_pause()
	
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.resume_music()
	
	var panel = ui.get_node_or_null("PausePanel")
	if panel:
		panel.visible = false

func _on_pause_menu_pressed():
	"""НОВОЕ: Обработка кнопки Menu в окне паузы"""
	print("🏠 Menu button pressed from pause")
	GameManager.save_game_data()
	GameManager.game_active = false
	get_tree().paused = false
	
	if OS.has_feature("web"):
		YandexGames.gameplay_stop()
	
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_gameover_menu_pressed():
	"""НОВОЕ: Обработка кнопки Menu в окне game over"""
	print("🏠 Menu button pressed from game over")
	GameManager.save_game_data()
	GameManager.game_active = false
	get_tree().paused = false
	
	if OS.has_feature("web"):
		YandexGames.gameplay_stop()
	
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_restart_pressed():
	print("🔄 Restart pressed")
	
	# ИСПРАВЛЕНО: сохранение без блокировки
	GameManager.save_game_data()
	
	if OS.has_feature("web"):
		print("📺 Showing ad before restart...")
		
		var audio_manager = get_node_or_null("/root/AudioManager")
		if audio_manager:
			audio_manager.stop_music()
		
		YandexGames.show_fullscreen_ad()
		await get_tree().create_timer(2.0).timeout
	
	print("🔄 Restarting game...")
	get_tree().paused = false
	get_tree().reload_current_scene()
