# game_manager.gd - ИСПРАВЛЕНО: убраны блокирующие await
extends Node

signal score_changed(score)
signal health_changed(health)
signal wave_changed(wave)
signal game_over
signal achievement_earned(id, name)

var score := 0
var health := 20
var max_health := 20
var wave := 0
var game_active := false
var paused := false

var achievements := {
	"first_kill": {"unlocked": false, "name": "first_kill", "desc": "first_kill_desc"},
	"wave_5": {"unlocked": false, "name": "wave_5", "desc": "wave_5_desc"},
	"wave_10": {"unlocked": false, "name": "wave_10", "desc": "wave_10_desc"},
	"score_1000": {"unlocked": false, "name": "score_1000", "desc": "score_1000_desc"},
	"score_5000": {"unlocked": false, "name": "score_5000", "desc": "score_5000_desc"},
	"boss_kill": {"unlocked": false, "name": "boss_kill", "desc": "boss_kill_desc"}
}

var save_data := {
	"high_score": 0,
	"achievements": {},
	"total_games": 0,
	"last_save_timestamp": 0
}

func _ready():
	print("GameManager initialized")
	# ИСПРАВЛЕНО: загрузка данных без блокировки
	call_deferred("load_game_data")

func start_game():
	print("🎮 Starting new game")
	score = 0
	wave = 0
	max_health = 20
	health = max_health
	game_active = true
	paused = false
	get_tree().paused = false
	
	emit_signal("score_changed", score)
	emit_signal("health_changed", health)
	emit_signal("wave_changed", wave)

func end_game():
	if not game_active:
		return
		
	print("🎮 Game over, saving data...")
	game_active = false
	
	# ИСПРАВЛЕНО: сохранение без блокировки
	save_game_data()
	
	# Обновляем рекорд в лидерборде
	if score > get_high_score():
		if OS.has_feature("web"):
			YandexGames.set_leaderboard_score("high_score", score)
	
	emit_signal("game_over")

func add_score(points: int):
	if not game_active:
		return
		
	score += points
	emit_signal("score_changed", score)
	
	# Автосохранение каждые 500 очков
	if score % 500 == 0:
		save_game_data()
	
	# Проверка достижений
	if score >= 1 and not achievements["first_kill"]["unlocked"]:
		unlock_achievement("first_kill")
	if score >= 1000 and not achievements["score_1000"]["unlocked"]:
		unlock_achievement("score_1000")
	if score >= 5000 and not achievements["score_5000"]["unlocked"]:
		unlock_achievement("score_5000")

func take_damage():
	if not game_active:
		return
		
	health -= 1
	emit_signal("health_changed", health)
	
	if health <= 0:
		end_game()

func next_wave():
	wave += 1
	max_health = max(1, 20 - wave)
	
	if health > max_health:
		health = max_health
	
	emit_signal("wave_changed", wave)
	emit_signal("health_changed", health)
	
	# Сохраняем каждые 3 волны
	if wave % 3 == 0:
		save_game_data()
	
	# Проверка достижений волн
	if wave >= 5 and not achievements["wave_5"]["unlocked"]:
		unlock_achievement("wave_5")
	if wave >= 10 and not achievements["wave_10"]["unlocked"]:
		unlock_achievement("wave_10")

func unlock_achievement(id: String):
	if achievements.has(id) and not achievements[id]["unlocked"]:
		achievements[id]["unlocked"] = true
		var achievement_name = I18n.get_achievement_name(id)
		
		# ИСПРАВЛЕНО: сначала сохраняем, потом отправляем сигнал
		save_game_data()
		
		# Отправляем сигнал БЕЗ блокировки
		emit_signal("achievement_earned", id, achievement_name)
		
		if OS.has_feature("web"):
			YandexGames.unlock_achievement(id)
		
		print("🏆 Achievement unlocked: ", achievement_name)

func toggle_pause():
	paused = !paused
	get_tree().paused = paused
	print("⏸️ Game paused: ", paused)

func save_game_data():
	"""ИСПРАВЛЕНО: правильное асинхронное сохранение"""
	var high_score = max(score, save_data.get("high_score", 0))
	
	var saved_achievements = {}
	for achievement_id in achievements:
		saved_achievements[achievement_id] = {
			"unlocked": achievements[achievement_id]["unlocked"]
		}
	
	save_data = {
		"high_score": high_score,
		"achievements": saved_achievements,
		"total_games": save_data.get("total_games", 0) + 1,
		"last_save_timestamp": Time.get_unix_time_from_system()
	}
	
	print("💾 Saving game data: high_score=", high_score)
	
	if OS.has_feature("web"):
		# КРИТИЧНО ИСПРАВЛЕНО: правильный вызов с аргументами через callable
		var data_to_save = save_data.duplicate()
		var save_callable = func(): YandexGames.save_data(data_to_save)
		save_callable.call_deferred()
	else:
		_save_local_data()
	
	print("✅ Save initiated")

func _save_local_data():
	"""Локальное сохранение для десктопа"""
	var config = ConfigFile.new()
	
	config.set_value("game", "high_score", save_data["high_score"])
	config.set_value("game", "total_games", save_data["total_games"])
	config.set_value("game", "last_save", save_data["last_save_timestamp"])
	
	var achievements_section = {}
	for achievement_id in save_data["achievements"]:
		achievements_section[achievement_id] = save_data["achievements"][achievement_id]["unlocked"]
	
	config.set_value("achievements", "unlocked", achievements_section)
	
	var error = config.save("user://game_save.cfg")
	if error == OK:
		print("💾 Local save successful")
	else:
		push_error("❌ Local save failed: ", error)

func load_game_data():
	"""ИСПРАВЛЕНО: асинхронная загрузка без блокировки"""
	print("📥 Loading game data...")
	
	if OS.has_feature("web"):
		print("🌐 Loading from Yandex Games...")
		_load_from_yandex()
	else:
		print("💻 Loading local data...")
		var loaded_data = _load_local_data()
		_apply_loaded_data(loaded_data)
	
	print("✅ Load initiated")

func _load_from_yandex():
	"""Асинхронная загрузка из Яндекс"""
	var loaded_data = await YandexGames.load_data()
	_apply_loaded_data(loaded_data)

func _apply_loaded_data(loaded_data: Dictionary):
	"""Применяет загруженные данные"""
	if loaded_data.is_empty():
		print("⚠️ No save data, using defaults (first time player)")
		save_data = {
			"high_score": 0,
			"achievements": {},
			"total_games": 0,
			"last_save_timestamp": 0
		}
	else:
		# ИСПРАВЛЕНО: Безопасное извлечение данных с проверкой типов
		save_data["high_score"] = int(loaded_data.get("high_score", 0))
		save_data["total_games"] = int(loaded_data.get("total_games", 0))
		save_data["last_save_timestamp"] = loaded_data.get("last_save_timestamp", 0)
		
		# Безопасная загрузка достижений
		var loaded_achievements = loaded_data.get("achievements", {})
		if loaded_achievements is Dictionary:
			save_data["achievements"] = loaded_achievements
		else:
			save_data["achievements"] = {}
		
		print("📦 Data loaded from cloud:")
		print("  - High Score: ", save_data["high_score"])
		print("  - Total Games: ", save_data["total_games"])
		print("  - Achievements: ", save_data["achievements"].size(), " unlocked")
	
	# Восстанавливаем достижения в игровую систему
	if save_data.has("achievements") and save_data["achievements"] is Dictionary:
		var loaded_achievements = save_data["achievements"]
		for achievement_id in loaded_achievements:
			if achievements.has(achievement_id):
				var achievement_data = loaded_achievements[achievement_id]
				# Поддержка двух форматов: bool и Dictionary
				if achievement_data is bool:
					achievements[achievement_id]["unlocked"] = achievement_data
					print("  ✓ Achievement restored: ", achievement_id)
				elif achievement_data is Dictionary and achievement_data.has("unlocked"):
					achievements[achievement_id]["unlocked"] = achievement_data["unlocked"]
					print("  ✓ Achievement restored: ", achievement_id)
	
	print("✅ Data applied successfully, ready to play")

func _load_local_data() -> Dictionary:
	"""Локальная загрузка для десктопа"""
	var config = ConfigFile.new()
	var error = config.load("user://game_save.cfg")
	
	if error != OK:
		print("⚠️ No local save file")
		return {}
	
	var loaded_data = {
		"high_score": config.get_value("game", "high_score", 0),
		"total_games": config.get_value("game", "total_games", 0),
		"last_save_timestamp": config.get_value("game", "last_save", 0),
		"achievements": {}
	}
	
	var achievements_data = config.get_value("achievements", "unlocked", {})
	for achievement_id in achievements_data:
		loaded_data["achievements"][achievement_id] = {
			"unlocked": achievements_data[achievement_id]
		}
	
	print("📥 Local load successful")
	return loaded_data

func get_high_score() -> int:
	return save_data.get("high_score", 0)

func force_save():
	"""Принудительное сохранение"""
	print("💾 Force saving...")
	save_game_data()
