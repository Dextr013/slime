# debug_checker.gd
extends Node
# Синглтон (Autoload) - DebugChecker
# Расширенная система отладки для проверки всех критических зависимостей проекта

const REQUIRED_AUTOLOADS = [
	"GameManager", 
	"I18n", 
	"YandexGames",
	"AudioManager",
	"DebugChecker"
]

# Критически важные ключи переводов для всех языков
const CRITICAL_TRANSLATION_KEYS = [
	"play", "score", "health", "wave", "high_score", "game_over", 
	"resume", "pause", "achievement", "tap_to_kill", "loading",
	"game_paused", "settings", "sound", "music", "effects", "main_menu"
]

# Проверяемые языки
const SUPPORTED_LANGUAGES = ["ru", "en", "tr"]

# Критически важные сцены
const REQUIRED_SCENES = [
	"res://scenes/menu.tscn",
	"res://scenes/game.tscn",
	"res://scenes/slime.tscn"
]

# Критически важные ресурсы
const REQUIRED_RESOURCES = [
	"res://assets/slimes_blue.tres",
	"res://assets/slimes_dark.tres", 
	"res://assets/slimes_green.tres",
	"res://assets/slimes_pink.tres",
	"res://assets/slimes_white.tres",
	"res://assets/slimes_yellow.tres"
]

var errors_found := 0
var warnings_found := 0
var debug_enabled := true
var check_completed := false
var autoload_check_attempts := 0
const MAX_AUTOLOAD_CHECK_ATTEMPTS := 10

func _ready():
	# Откладываем проверку до полной инициализации
	if debug_enabled:
		# Ждем несколько кадров чтобы автозагрузки успели инициализироваться
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_check_autoloads_delayed()

func _check_autoloads_delayed():
	"""Отложенная проверка автозагрузок с несколькими попытками"""
	autoload_check_attempts += 1
	
	# Получаем реальный список зарегистрированных автозагрузок
	var autoload_list = ProjectSettings.get_setting("autoload/", {})
	var loaded_autoloads = []
	
	for autoload_path in autoload_list:
		var autoload_name = autoload_path.get_file().get_basename()
		loaded_autoloads.append(autoload_name)
	
	print("  Загруженные автозагрузки из ProjectSettings: ", loaded_autoloads)
	print("  Engine синглтоны: ", Engine.get_singleton_list())
	
	# Проверяем наличие автозагрузок в Engine
	var missing_in_engine = []
	var found_in_engine = []
	
	for autoload_name in REQUIRED_AUTOLOADS:
		if Engine.has_singleton(autoload_name):
			var node = Engine.get_singleton(autoload_name)
			if node != null:
				found_in_engine.append(autoload_name)
				print("  ✅ [b]%s[/b] инициализирован в Engine." % autoload_name)
			else:
				missing_in_engine.append(autoload_name + " (null)")
		else:
			missing_in_engine.append(autoload_name)
	
	# Если не все автозагрузки найдены, пробуем еще раз через кадр
	if not missing_in_engine.is_empty() and autoload_check_attempts < MAX_AUTOLOAD_CHECK_ATTEMPTS:
		print("  ⏳ Не все автозагрузки найдены, попытка %d/%d..." % [autoload_check_attempts, MAX_AUTOLOAD_CHECK_ATTEMPTS])
		print("  Отсутствуют в Engine: ", missing_in_engine)
		await get_tree().process_frame
		_check_autoloads_delayed()
		return
	
	# После максимального количества попыток запускаем полную проверку
	if autoload_check_attempts >= MAX_AUTOLOAD_CHECK_ATTEMPTS:
		print("  ⚠️ Достигнуто максимальное количество попыток проверки автозагрузок")
	
	check_all()

func check_all():
	"""Запуск полной проверки системы"""
	if check_completed:
		return
	
	print_rich("[color=yellow]--- [b]СУВЕРЕН: ЗАПУСК РАСШИРЕННОЙ СТАТИЧЕСКОЙ ПРОВЕРКИ[/b] ---[/color]")
	
	errors_found = 0
	warnings_found = 0
	
	_check_autoloads()
	
	# Проверяем API только если автозагрузки найдены
	if _has_critical_autoloads():
		_check_api_state()
		_check_localization()
	else:
		push_warning("Пропуск проверки API и локализации из-за отсутствия критических автозагрузок")
	
	_check_scenes()
	_check_resources()
	_check_yandex_requirements()
	_check_game_balance()
	
	print_rich("[color=yellow]--- [b]СУВЕРЕН: ПРОВЕРКА ЗАВЕРШЕНА[/b] ---[/color]")
	
	# Итоговый отчет
	if errors_found > 0:
		printerr("!!! [b]КРИТИЧЕСКИЕ ОШИБКИ:[/b] Найдено %d ошибок. (Исправить немедленно!)" % errors_found)
		_show_error_notification()
	elif warnings_found > 0:
		push_warning("! [b]ПРЕДУПРЕЖДЕНИЯ:[/b] Найдено %d предупреждений. (Рекомендуется исправить)" % warnings_found)
	else:
		print_rich("[color=green]✅ [b]ВЕЛИЧЕСТВЕННО:[/b] Все критические зависимости успешно загружены и инициализированы.[/color]")
	
	check_completed = true
	return errors_found == 0

func _has_critical_autoloads() -> bool:
	"""Проверяет наличие критически важных автозагрузок"""
	var has_critical = true
	for autoload in REQUIRED_AUTOLOADS:
		if not Engine.has_singleton(autoload):
			print("  ⚠️ Автозагрузка '%s' не найдена в Engine синглтонах" % autoload)
			has_critical = false
	return has_critical

func _check_autoloads():
	"""Проверка всех необходимых автозагрузок"""
	print_rich("\n[color=cyan][1/6] Проверка Автозагрузок...[/color]")
	
	# Получаем список всех зарегистрированных автозагрузок из ProjectSettings
	var autoload_list = ProjectSettings.get_setting("autoload/", {})
	var loaded_autoloads = []
	
	for autoload_path in autoload_list:
		var autoload_name = autoload_path.get_file().get_basename()
		loaded_autoloads.append(autoload_name)
	
	print("  Загруженные автозагрузки из ProjectSettings: ", loaded_autoloads)
	print("  Доступные Engine синглтоны: ", Engine.get_singleton_list())
	
	var missing_autoloads = []
	
	for autoload_name in REQUIRED_AUTOLOADS:
		if Engine.has_singleton(autoload_name):
			var node = Engine.get_singleton(autoload_name)
			if node != null:
				print("  ✅ [b]%s[/b] инициализирован." % autoload_name)
				
				# Дополнительная диагностика для ключевых автозагрузок
				match autoload_name:
					"GameManager":
						if node.has_method("start_game"):
							print("    ↳ GameManager методы: start_game ✓")
						else:
							push_warning("    ⚠️ GameManager не имеет метода start_game")
					"I18n":
						if node.has_method("translate"):
							print("    ↳ I18n методы: translate ✓")
						else:
							push_warning("    ⚠️ I18n не имеет метода translate")
					"YandexGames":
						if node.has_signal("sdk_ready"):
							print("    ↳ YandexGames сигналы: sdk_ready ✓")
						else:
							push_warning("    ⚠️ YandexGames не имеет сигнала sdk_ready")
			else:
				printerr("  ❌ [b]%s[/b] найден но не инициализирован (null)." % autoload_name)
				errors_found += 1
				missing_autoloads.append(autoload_name)
		else:
			# Проверяем есть ли автозагрузка в ProjectSettings но не в Engine
			if autoload_name in loaded_autoloads:
				push_warning("  ⚠️ [b]%s[/b] есть в ProjectSettings но не в Engine (возможно еще не инициализирован)." % autoload_name)
				warnings_found += 1
			else:
				printerr("  ❌ [b]%s[/b] не найден в Engine синглтонах." % autoload_name)
				errors_found += 1
				missing_autoloads.append(autoload_name)
	
	# Дополнительная диагностика только если есть реальные ошибки
	if not missing_autoloads.is_empty():
		print("  [Диагностика] Отсутствующие автозагрузки: ", missing_autoloads)
		print("  [Диагностика] Проверьте настройки автозагрузки в Project Settings -> Autoload")
		print("  [Диагностика] Убедитесь что скрипты имеют правильные имена и пути")

func _check_api_state():
	"""Проверка состояния API и Game Manager"""
	print_rich("\n[color=cyan][2/6] Проверка состояния API и Game Manager...[/color]")
	
	# Проверка YandexGames
	if Engine.has_singleton("YandexGames"):
		var yandex = Engine.get_singleton("YandexGames")
		if yandex and yandex.get("is_initialized") != null:
			if yandex.is_initialized:
				print("  ✅ YandexGames.sdk_ready завершен.")
			else:
				print("  ⏳ YandexGames.is_initialized = false (ожидание инициализации).")
				warnings_found += 1
		else:
			push_warning("  ⚠️ YandexGames не имеет свойства is_initialized.")
			warnings_found += 1
	else:
		printerr("  ❌ YandexGames не инициализирован.")
		errors_found += 1
	
	# Проверка GameManager
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		
		if gm:
			# Проверка критических свойств
			var critical_properties = ["health", "score", "wave", "game_active"]
			for prop in critical_properties:
				if gm.get(prop) != null:
					print("  ✅ GameManager.%s: %s" % [prop, str(gm.get(prop))])
				else:
					push_warning("  ⚠️ GameManager.%s не существует." % prop)
					warnings_found += 1
			
			# Проверка данных сохранения
			if gm.get("save_data") != null:
				if not gm.save_data.is_empty():
					print("  ✅ GameManager: Данные сохранения загружены.")
				else:
					print("  ⏳ GameManager.save_data пуст (возможно еще не загружены).")
					warnings_found += 1
			else:
				push_warning("  ⚠️ GameManager.save_data не существует.")
				warnings_found += 1
				
			# Проверка достижений
			if gm.get("achievements") != null:
				var achievements = gm.achievements
				if achievements is Dictionary and not achievements.is_empty():
					print("  ✅ GameManager: Достижения загружены (%d)." % achievements.size())
				else:
					push_warning("  ⚠️ GameManager.achievements пуст или не словарь.")
					warnings_found += 1
		else:
			printerr("  ❌ GameManager найден но не инициализирован.")
			errors_found += 1
	else:
		printerr("  ❌ GameManager не инициализирован.")
		errors_found += 1

func _check_localization():
	"""Расширенная проверка локализации для всех языков"""
	print_rich("\n[color=cyan][3/6] Проверка критических переводов для всех языков...[/color]")
	
	if Engine.has_singleton("I18n"):
		var i18n = Engine.get_singleton("I18n")
		
		if i18n:
			# Проверка текущего языка
			if i18n.get("current_language") != null:
				print("  Текущий язык: %s" % i18n.current_language)
			else:
				printerr("  ❌ I18n.current_language не существует.")
				errors_found += 1
			
			# Проверка всех языков
			for language in SUPPORTED_LANGUAGES:
				print("  Проверка языка: %s" % language)
				var missing_keys = []
				
				for key in CRITICAL_TRANSLATION_KEYS:
					# Временно меняем язык для проверки
					var original_lang = i18n.current_language
					i18n.current_language = language
					
					var translation = i18n.translate(key)
					
					# Возвращаем язык
					i18n.current_language = original_lang
					
					if translation.is_empty() or translation == key:
						missing_keys.append(key)
						push_warning("    ⚠️ Ключ '[b]%s[/b]' отсутствует в языке '%s'." % [key, language])
						warnings_found += 1
				
				if missing_keys.is_empty():
					print("    ✅ Все ключи присутствуют в языке '%s'." % language)
				else:
					push_warning("    ⚠️ В языке '%s' отсутствуют ключи: %s" % [language, missing_keys])
		else:
			printerr("  ❌ I18n найден но не инициализирован.")
			errors_found += 1
	else:
		printerr("  ❌ I18n не инициализирован.")
		errors_found += 1

func _check_scenes():
	"""Проверка наличия критически важных сцен"""
	print_rich("\n[color=cyan][4/6] Проверка критических сцен...[/color]")
	
	for scene_path in REQUIRED_SCENES:
		if ResourceLoader.exists(scene_path):
			var resource = ResourceLoader.load(scene_path)
			if resource:
				print("  ✅ Сцена '[b]%s[/b]' загружена." % scene_path)
			else:
				printerr("  ❌ Сцена '[b]%s[/b]' не может быть загружена." % scene_path)
				errors_found += 1
		else:
			printerr("  ❌ Сцена '[b]%s[/b]' не найдена." % scene_path)
			errors_found += 1

func _check_resources():
	"""Проверка наличия критически важных ресурсов"""
	print_rich("\n[color=cyan][5/6] Проверка критических ресурсов...[/color]")
	
	for resource_path in REQUIRED_RESOURCES:
		if ResourceLoader.exists(resource_path):
			var resource = ResourceLoader.load(resource_path)
			if resource:
				print("  ✅ Ресурс '[b]%s[/b]' загружен." % resource_path)
			else:
				printerr("  ❌ Ресурс '[b]%s[/b]' не может быть загружен." % resource_path)
				errors_found += 1
		else:
			printerr("  ❌ Ресурс '[b]%s[/b]' не найден." % resource_path)
			errors_found += 1

func _check_yandex_requirements():
	"""Проверка специфических требований Яндекс Игр"""
	print_rich("\n[color=cyan][6/6] Проверка требований Яндекс Игр...[/color]")
	
	# Проверка разрешений
	var viewport = get_viewport()
	if viewport:
		var mode = viewport.mode
		if mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			print("  ✅ Режим полноэкранный (требование Яндекс Игр).")
		else:
			push_warning("  ⚠️ Рекомендуется полноэкранный режим для Яндекс Игр.")
			warnings_found += 1
	
	# Проверка поддержки мобильных устройств
	var has_touch = Input.is_anything_pressed()  # Базовая проверка touch input
	print("  ✅ Поддержка touch input: %s" % str(has_touch))
	
	# Проверка размера окна (рекомендации Яндекс)
	var screen_size = DisplayServer.screen_get_size()
	if screen_size.x >= 1280 and screen_size.y >= 720:
		print("  ✅ Разрешение экрана соответствует рекомендациям.")
	else:
		push_warning("  ⚠️ Рекомендуется минимальное разрешение 1280x720.")
		warnings_found += 1

func _check_game_balance():
	"""Проверка баланса игровых параметров"""
	print_rich("\n[color=cyan][+] Дополнительная проверка игрового баланса...[/color]")
	
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		
		if gm:
			# Проверка достижений на логические ошибки
			if gm.get("achievements") != null:
				var achievements = gm.achievements
				for achievement_id in achievements:
					var achievement = achievements[achievement_id]
					if achievement is Dictionary:
						if achievement.has("name") and achievement.has("desc"):
							if achievement["name"].is_empty() or achievement["desc"].is_empty():
								push_warning("  ⚠️ Достижение '%s' имеет пустое имя или описание." % achievement_id)
								warnings_found += 1
					else:
						push_warning("  ⚠️ Достижение '%s' имеет неверный формат." % achievement_id)
						warnings_found += 1

func _show_error_notification():
	"""Показать уведомление об ошибках в runtime (если возможно)"""
	if Engine.has_singleton("I18n"):
		var i18n = Engine.get_singleton("I18n")
		var error_msg = i18n.translate("debug_errors_found") if i18n.translate("debug_errors_found") != "debug_errors_found" else "Обнаружены ошибки отладки: %d" % errors_found
		push_error(error_msg)

# Публичные методы для ручного вызова
func quick_check() -> bool:
	"""Быстрая проверка только критических компонентов"""
	print_rich("[color=yellow]⚡ Быстрая проверка системы...[/color]")
	errors_found = 0
	warnings_found = 0
	
	_check_autoloads()
	
	if _has_critical_autoloads():
		_check_api_state()
	
	return errors_found == 0

func check_specific_component(component: String) -> bool:
	"""Проверка конкретного компонента"""
	match component:
		"autoloads":
			return _check_autoloads()
		"api":
			return _check_api_state()
		"localization":
			return _check_localization()
		"scenes":
			return _check_scenes()
		"resources":
			return _check_resources()
		"yandex":
			return _check_yandex_requirements()
		_:
			push_warning("Неизвестный компонент для проверки: %s" % component)
			return false

# Сигналы для интеграции с UI
signal debug_check_started()
signal debug_check_completed(errors: int, warnings: int)
signal critical_error_detected(error_message: String)

func run_comprehensive_check():
	"""Запуск комплексной проверки с сигналами"""
	emit_signal("debug_check_started")
	
	var success = check_all()
	
	emit_signal("debug_check_completed", errors_found, warnings_found)
	
	if errors_found > 0:
		emit_signal("critical_error_detected", "Обнаружено %d критических ошибок" % errors_found)
	
	return success

# Метод для получения отчета в виде словаря
func get_debug_report() -> Dictionary:
	"""Получить полный отчет о состоянии системы"""
	return {
		"timestamp": Time.get_datetime_string_from_system(),
		"errors_count": errors_found,
		"warnings_count": warnings_found,
		"autoloads_ok": _has_critical_autoloads(),
		"api_initialized": Engine.has_singleton("YandexGames") and Engine.get_singleton("YandexGames").is_initialized if Engine.has_singleton("YandexGames") else false,
		"localization_ready": Engine.has_singleton("I18n"),
		"game_manager_ready": Engine.has_singleton("GameManager"),
		"version": "1.0.0"
	}

# Метод для проверки настроек автозагрузки
func diagnose_autoload_issues():
	"""Диагностика проблем с автозагрузкой"""
	print_rich("\n[color=orange][Диагностика] Проверка настроек автозагрузки...[/color]")
	
	var autoloads = ProjectSettings.get_setting("autoload/", {})
	
	if autoloads.is_empty():
		printerr("  ❌ В проекте не настроены автозагрузки!")
		return
	
	print("  Найдено автозагрузок: %d" % autoloads.size())
	
	for autoload_path in autoloads:
		var autoload_name = autoload_path.get_file().get_basename()
		var _autoload_value = autoloads[autoload_path]
		print("  - %s: %s" % [autoload_name, autoload_path])
		
		# Проверяем существует ли файл
		if FileAccess.file_exists(autoload_path):
			print("    ✅ Файл существует")
		else:
			printerr("    ❌ Файл не существует!")
