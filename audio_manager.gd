extends Node

# Аудио плееры
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Звуковые эффекты
var pop_sounds := []

# Состояние
var is_music_paused_by_visibility := false
var music_position_before_pause := 0.0
var was_music_playing_before_hide := false

func _ready():
	print("AudioManager initialized")
	_setup_audio_players()
	_load_sounds()
	
	# КРИТИЧЕСКИ ВАЖНО: Подключаемся к сигналу видимости из YandexGames
	if Engine.has_singleton("YandexGames"):
		YandexGames.visibility_changed.connect(_on_visibility_changed)
		print("✅ Connected to YandexGames visibility_changed signal")
	else:
		# Резервный вариант для десктопа
		_setup_desktop_visibility_listeners()
	
	play_music()

func _setup_desktop_visibility_listeners():
	"""Резервные слушатели для десктоп версии"""
	print("🖥️ Setting up desktop visibility listeners")
	# В десктоп версии используем Window focus события
	var window = get_window()
	if window:
		window.focus_entered.connect(func(): 
			print("🔘 Window focused")
			_on_visibility_changed(false)
		)
		window.focus_exited.connect(func(): 
			print("🔘 Window unfocused") 
			_on_visibility_changed(true)
		)

func _setup_audio_players():
	# Музыкальный плеер
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -5.0
	add_child(music_player)
	
	# SFX плеер
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	sfx_player.volume_db = 0.0
	add_child(sfx_player)

func _load_sounds():
	# Загружаем музыку
	if ResourceLoader.exists("res://assets/audio/bg.mp3"):
		var music = load("res://assets/audio/bg.mp3")
		music_player.stream = music
		print("✅ Background music loaded")
	else:
		push_warning("⚠️ Background music not found: res://assets/audio/bg.mp3")
	
	# Загружаем звуки лопания
	var pop_paths = [
		"res://assets/audio/pop1.ogg",
		"res://assets/audio/pop2.ogg",
		"res://assets/audio/pop3.ogg"
	]
	
	for path in pop_paths:
		if ResourceLoader.exists(path):
			var sound = load(path)
			if sound:
				pop_sounds.append(sound)
				print("✅ Pop sound loaded: ", path)
			else:
				push_warning("⚠️ Failed to load pop sound: " + path)
		else:
			push_warning("⚠️ Pop sound not found: " + path)
	
	print("Total pop sounds loaded: ", pop_sounds.size())

func _on_visibility_changed(is_hidden: bool):
	"""
	КРИТИЧЕСКИ ВАЖНО для Яндекс.Игр:
	При сворачивании страницы или смене вкладки - останавливаем звук
	"""
	print("👁️ AudioManager: Visibility changed to ", "hidden" if is_hidden else "visible")
	
	if is_hidden:
		# Страница скрыта - останавливаем музыку
		was_music_playing_before_hide = music_player.playing
		if was_music_playing_before_hide:
			music_position_before_pause = music_player.get_playback_position()
			music_player.stop()
			is_music_paused_by_visibility = true
			print("🔇 Music paused (page hidden), position: ", music_position_before_pause)
	else:
		# Страница видима - возобновляем музыку
		if is_music_paused_by_visibility and was_music_playing_before_hide:
			# Ждем немного чтобы убедиться что страница полностью загрузилась
			await get_tree().create_timer(0.1).timeout
			if music_player.stream:
				music_player.play(music_position_before_pause)
				is_music_paused_by_visibility = false
				was_music_playing_before_hide = false
				print("🔊 Music resumed (page visible), position: ", music_position_before_pause)
			else:
				print("❌ Cannot resume music: no stream")

func play_music():
	if music_player.stream and not music_player.playing:
		music_player.play()
		# Зацикливаем музыку
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		print("🎵 Music started")

func _on_music_finished():
	music_player.play()
	print("🎵 Music looped")

func stop_music():
	music_player.stop()
	is_music_paused_by_visibility = false
	was_music_playing_before_hide = false
	print("⏹️ Music stopped")

func pause_music():
	if music_player.playing:
		music_position_before_pause = music_player.get_playback_position()
		music_player.stop()
		print("⏸️ Music paused manually")

func resume_music():
	if music_player.stream and not music_player.playing:
		music_player.play(music_position_before_pause)
		print("▶️ Music resumed manually")

func play_pop_sound():
	if pop_sounds.is_empty():
		push_warning("⚠️ No pop sounds available")
		return
	
	# Выбираем случайный звук
	var random_sound = pop_sounds.pick_random()
	
	# Создаем временный плеер для проигрывания
	var temp_player = AudioStreamPlayer.new()
	temp_player.bus = "SFX"
	temp_player.stream = random_sound
	temp_player.volume_db = randf_range(-2.0, 2.0)
	temp_player.pitch_scale = randf_range(0.9, 1.1)
	add_child(temp_player)
	
	temp_player.play()
	
	# Удаляем после проигрывания
	temp_player.finished.connect(func(): 
		if is_instance_valid(temp_player):
			temp_player.queue_free()
	)

func set_music_volume(volume: float):
	music_player.volume_db = volume
	print("🎵 Music volume set to: ", volume)

func set_sfx_volume(volume: float):
	sfx_player.volume_db = volume
	print("🔊 SFX volume set to: ", volume)
