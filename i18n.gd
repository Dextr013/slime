extends Node

var current_language := "ru"

var translations := {
	"ru": {
		"play": "Играть",
		"pause": "Пауза",
		"resume": "Продолжить",
		"menu": "Меню",
		"main_menu": "Главное меню",
		"restart": "Заново",
		"game_over": "Игра окончена",
		"score": "Очки",
		"high_score": "Рекорд",
		"wave": "Волна",
		"health": "Здоровье",
		"achievement": "Достижение разблокировано",
		"tap_to_kill": "Нажимайте на слаймов!",
		"small_slime": "Маленький слайм: 1 тап",
		"medium_slime": "Средний слайм: 2 тапа",
		"boss_slime": "Босс: 5 тапов",
		"how_to_play": "Как играть",
		"start_game": "Начать игру",
		"title_label": "СЛАЙМ ПОП!",
		"instructions_text": "Нажимайте на слаймов, чтобы уничтожить их!\n\n🟢 Маленькие: 1 клик\n🟡 Средние: 2 клика\n🔴 Боссы: 5 кликов\n\nНе дайте им достичь низа экрана!",
		"loading": "Загрузка...",
		"game_paused": "Игра на паузе",
		"settings": "Настройки",
		"sound": "Звук",
		"music": "Музыка",
		"effects": "Эффекты",
		"back": "Назад",
		"continue": "Продолжить",
		# Достижения на русском
		"first_kill": "Первая кровь",
		"first_kill_desc": "Убейте первого слайма",
		"wave_5": "Выживший",
		"wave_5_desc": "Достигните 5 волны",
		"wave_10": "Ветеран",
		"wave_10_desc": "Достигните 10 волны",
		"score_1000": "Убийца",
		"score_1000_desc": "Наберите 1000 очков",
		"score_5000": "Мастер",
		"score_5000_desc": "Наберите 5000 очков",
		"boss_kill": "Охотник на боссов",
		"boss_kill_desc": "Убейте босса-слайма"
	},
	"en": {
		"play": "Play",
		"pause": "Pause",
		"resume": "Resume",
		"menu": "Menu",
		"main_menu": "Main Menu",
		"restart": "Restart",
		"game_over": "Game Over",
		"score": "Score",
		"high_score": "High Score",
		"wave": "Wave",
		"health": "Health",
		"achievement": "Achievement Unlocked",
		"tap_to_kill": "Tap to kill slimes!",
		"small_slime": "Small Slime: 1 tap",
		"medium_slime": "Medium Slime: 2 taps",
		"boss_slime": "Boss: 5 taps",
		"how_to_play": "How to Play",
		"start_game": "Start Game",
		"title_label": "SLIME POP!",
		"instructions_text": "Tap slimes to destroy them!\n\n🟢 Small: 1 tap\n🟡 Medium: 2 taps\n🔴 Boss: 5 taps\n\nDon't let them reach the bottom!",
		"loading": "Loading...",
		"game_paused": "Game Paused",
		"settings": "Settings",
		"sound": "Sound",
		"music": "Music",
		"effects": "Effects",
		"back": "Back",
		"continue": "Continue",
		# Достижения на английском
		"first_kill": "First Blood",
		"first_kill_desc": "Kill your first slime",
		"wave_5": "Survivor",
		"wave_5_desc": "Reach wave 5",
		"wave_10": "Veteran",
		"wave_10_desc": "Reach wave 10",
		"score_1000": "Slayer",
		"score_1000_desc": "Score 1000 points",
		"score_5000": "Master",
		"score_5000_desc": "Score 5000 points",
		"boss_kill": "Boss Hunter",
		"boss_kill_desc": "Kill a boss slime"
	},
	"tr": {
		"play": "Oyna",
		"pause": "Duraklat",
		"resume": "Devam",
		"menu": "Menü",
		"main_menu": "Ana Menü",
		"restart": "Yeniden Başlat",
		"game_over": "Oyun Bitti",
		"score": "Puan",
		"high_score": "En Yüksek Puan",
		"wave": "Dalga",
		"health": "Can",
		"achievement": "Başarı Kilidi Açıldı",
		"tap_to_kill": "Slaymları yok et!",
		"small_slime": "Küçük Slaym: 1 tıklama",
		"medium_slime": "Orta Slaym: 2 tıklama",
		"boss_slime": "Boss: 5 tıklama",
		"how_to_play": "Nasıl Oynanır",
		"start_game": "Oyuna Başla",
		"title_label": "SLIME POP!",
		"instructions_text": "Slaymları yok etmek için dokunun!\n\n🟢 Küçük: 1 dokunuş\n🟡 Orta: 2 dokunuş\n🔴 Boss: 5 dokunuş\n\nAlta ulaşmalarına izin vermeyin!",
		"loading": "Yükleniyor...",
		"game_paused": "Oyun Duraklatıldı",
		"settings": "Ayarlar",
		"sound": "Ses",
		"music": "Müzik",
		"effects": "Efektler",
		"back": "Geri",
		"continue": "Devam Et",
		# Достижения на турецком
		"first_kill": "İlk Kan",
		"first_kill_desc": "İlk slaymı öldür",
		"wave_5": "Hayatta Kalan",
		"wave_5_desc": "5. dalgaya ulaş",
		"wave_10": "Veteran",
		"wave_10_desc": "10. dalgaya ulaş",
		"score_1000": "Katil",
		"score_1000_desc": "1000 puan topla",
		"score_5000": "Usta",
		"score_5000_desc": "5000 puan topla",
		"boss_kill": "Boss Avcısı",
		"boss_kill_desc": "Bir boss slaymı öldür"
	}
}

func _ready():
	print("I18n autoload initialized")
	detect_language()

func detect_language():
	if OS.has_feature("web"):
		var code = """
		(function() {
			var lang = 'ru';
			if (window.ysdk && window.ysdk.environment) {
				lang = window.ysdk.environment.i18n.lang;
			} else {
				lang = navigator.language.substring(0, 2);
			}
			return lang;
		})();
		"""
		var result = JavaScriptBridge.eval(code)
		if result and translations.has(result):
			current_language = result
		else:
			current_language = "en"
	else:
		current_language = "ru"
	
	print("Language detected: ", current_language)

func translate(key: String) -> String:
	if translations.has(current_language) and translations[current_language].has(key):
		return translations[current_language][key]
	return key

func get_instructions_text() -> String:
	"""Возвращает текст инструкций для текущего языка"""
	return translate("instructions_text")

func set_language(lang: String):
	if translations.has(lang):
		current_language = lang

func get_achievement_name(achievement_id: String) -> String:
	"""Возвращает локализованное название достижения"""
	return translate(achievement_id)

func get_achievement_desc(achievement_id: String) -> String:
	"""Возвращает локализованное описание достижения"""
	return translate(achievement_id + "_desc")
