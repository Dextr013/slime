extends Node

var is_initialized := false
var is_game_ready := false
var player_data := {}
var js_callback = null 

signal sdk_ready
signal game_ready_sent
signal player_data_loaded(data)
signal achievement_unlocked(id)
signal gameplay_started
signal gameplay_stopped
signal visibility_changed(hidden: bool)

func _ready():
	print("YandexGames autoload initialized")
	
	if OS.has_feature("web"):
		print("🌐 Web platform detected, initializing Yandex Games SDK...")
		js_callback = JavaScriptBridge.create_callback(_on_js_callback)
		_setup_js_bridge()
		_setup_visibility_listeners()
		_init_sdk()
	else:
		print("💻 Desktop platform, using mock SDK")
		is_initialized = true
		is_game_ready = true
		emit_signal("sdk_ready")
		emit_signal("game_ready_sent")

func _setup_js_bridge():
	"""Настройка моста между JavaScript и Godot"""
	var code = """
	(function() {
		// Глобальная функция для обратного вызова
		window.godotYandexCallback = function(args) {
			if (window.godotInstance && typeof window.godotInstance.call === 'function') {
				window.godotInstance.call('YandexGames', '_on_js_callback', args);
			} else {
				console.warn('Godot instance not ready yet');
			}
		};
		console.log('✅ Godot-JS bridge setup complete');
	})();
	"""
	JavaScriptBridge.eval(code)

func _init_sdk():
	"""Инициализация SDK Яндекс Игр"""
	var code = """
	(function() {
		console.log('🚀 Starting Yandex Games SDK initialization...');
		
		if (typeof YaGames === 'undefined') {
			console.error('❌ YaGames SDK not found!');
			window.godotYandexCallback(['sdk_error', 'YaGames not defined']);
			return;
		}
		
		try {
			YaGames.init().then(ysdk => {
				console.log('✅ YaGames SDK initialized successfully');
				window.ysdk = ysdk;
				
				// Загружаем данные игрока
				return ysdk.getPlayer({ signed: false });
			}).then(player => {
				console.log('✅ Player loaded');
				window.player = player;
				
				// Загружаем данные игрока
				return player.getData();
			}).then(data => {
				console.log('✅ Player data loaded:', data);
				window.godotYandexCallback(['sdk_initialized', data || {}]);
			}).catch(error => {
				console.error('❌ SDK initialization error:', error);
				window.godotYandexCallback(['sdk_error', error.toString()]);
			});
		} catch (error) {
			console.error('❌ SDK initialization exception:', error);
			window.godotYandexCallback(['sdk_error', error.toString()]);
		}
	})();
	"""
	
	JavaScriptBridge.eval(code)

func _setup_visibility_listeners():
	"""Настройка слушателей видимости страницы"""
	var code = """
	(function() {
		console.log('👁️ Setting up visibility listeners...');
		
		var handleVisibilityChange = function(isHidden) {
			console.log('📄 Visibility changed:', isHidden);
			if (window.godotYandexCallback) {
				window.godotYandexCallback(['visibility_changed', isHidden]);
			}
		};
		
		// Стандартное событие видимости
		document.addEventListener('visibilitychange', function() {
			handleVisibilityChange(document.hidden);
		});
		
		// События фокуса для браузеров
		window.addEventListener('blur', function() {
			handleVisibilityChange(true);
		});
		
		window.addEventListener('focus', function() {
			handleVisibilityChange(false);
		});
		
		// iOS события
		window.addEventListener('pagehide', function() {
			handleVisibilityChange(true);
		});
		
		window.addEventListener('pageshow', function() {
			handleVisibilityChange(false);
		});
		
		console.log('✅ Visibility listeners setup complete');
	})();
	"""
	JavaScriptBridge.eval(code)

func _on_js_callback(args):
	"""Обработчик callback из JavaScript"""
	if args.size() == 0:
		return
	
	var event_type = args[0]
	print("📞 JS Callback received: ", event_type)
	
	match event_type:
		"sdk_initialized":
			if args.size() > 1:
				player_data = args[1] if args[1] != null else {}
				print("📦 Player data loaded: ", player_data)
			is_initialized = true
			emit_signal("sdk_ready")
			print("✅ SDK fully initialized and ready")
			
		"sdk_error":
			var error_msg = args[1] if args.size() > 1 else "Unknown error"
			push_error("❌ SDK initialization failed: " + error_msg)
			# Все равно помечаем как инициализированный для продолжения работы
			is_initialized = true
			emit_signal("sdk_ready")
			
		"player_data_loaded":
			if args.size() > 1:
				player_data = args[1] if args[1] != null else {}
				emit_signal("player_data_loaded", player_data)
				
		"save_completed":
			print("✅ Save completed successfully")
			
		"save_error":
			push_error("❌ Save failed")
			
		"visibility_changed":
			if args.size() > 1:
				var is_hidden = args[1]
				print("👁️ Visibility changed: ", is_hidden)
				emit_signal("visibility_changed", is_hidden)
				
				if AudioManager:
					AudioManager._on_visibility_changed(is_hidden)
					
		"ad_closed":
			print("📺 Ad closed")
			if AudioManager:
				AudioManager.play_music()
				
		"ad_error":
			print("❌ Ad error")
			if AudioManager:
				AudioManager.play_music()

func send_game_ready():
	"""Отправка сигнала о готовности игры"""
	if not OS.has_feature("web"):
		is_game_ready = true
		emit_signal("game_ready_sent")
		print("✅ Game Ready sent (desktop)")
		return
	
	if not is_initialized:
		print("⏳ Waiting for SDK initialization before sending GameReady...")
		await sdk_ready
	
	var code = """
	(function() {
		console.log('🎮 Sending GameReady...');
		
		if (window.ysdk && window.ysdk.features && window.ysdk.features.LoadingAPI) {
			try {
				window.ysdk.features.LoadingAPI.ready();
				console.log('✅ GameReady sent successfully');
				return true;
			} catch (error) {
				console.error('❌ GameReady error:', error);
				return false;
			}
		} else {
			console.warn('⚠️ LoadingAPI not available, game will continue anyway');
			return true;
		}
	})();
	"""
	
	var result = JavaScriptBridge.eval(code)
	if result:
		is_game_ready = true
		emit_signal("game_ready_sent")
		print("✅ Game Ready sent to Yandex")
	else:
		print("⚠️ GameReady failed, but continuing game anyway")
		is_game_ready = true
		emit_signal("game_ready_sent")

func gameplay_start():
	"""Уведомление о начале геймплея"""
	if not OS.has_feature("web"):
		emit_signal("gameplay_started")
		return
	
	var code = """
	(function() {
		if (window.ysdk && window.ysdk.features && window.ysdk.features.GameplayAPI) {
			window.ysdk.features.GameplayAPI.start();
			console.log('🎮 Gameplay started');
		}
	})();
	"""
	JavaScriptBridge.eval(code)
	emit_signal("gameplay_started")
	print("🎮 Gameplay started")

func gameplay_stop():
	"""Уведомление о остановке геймплея"""
	if not OS.has_feature("web"):
		emit_signal("gameplay_stopped")
		return
	
	var code = """
	(function() {
		if (window.ysdk && window.ysdk.features && window.ysdk.features.GameplayAPI) {
			window.ysdk.features.GameplayAPI.stop();
			console.log('⏸️ Gameplay stopped');
		}
	})();
	"""
	JavaScriptBridge.eval(code)
	emit_signal("gameplay_stopped")
	print("⏸️ Gameplay stopped")

func save_data(data: Dictionary):
	"""Сохранение данных игрока"""
	if not OS.has_feature("web"):
		print("💾 Save data (desktop): ", data)
		return
	
	if not is_initialized:
		print("⏳ Waiting for SDK before save...")
		await sdk_ready
	
	var json_data = JSON.stringify(data)
	var code = """
	(function() {
		console.log('💾 Attempting to save data...');
		
		if (window.player && window.player.setData) {
			window.player.setData(%s, true)
				.then(() => {
					console.log('✅ Data saved successfully');
					window.godotYandexCallback(['save_completed']);
				})
				.catch(error => {
					console.error('❌ Save error:', error);
					window.godotYandexCallback(['save_error']);
				});
		} else {
			console.warn('⚠️ Player API not available for saving');
			window.godotYandexCallback(['save_completed']); // Все равно считаем успешным
		}
	})();
	""" % [json_data]
	
	JavaScriptBridge.eval(code)

func load_data() -> Dictionary:
	"""Загрузка данных игрока"""
	if not OS.has_feature("web"):
		print("📥 Load data (desktop)")
		return {}
	
	if not is_initialized:
		print("⏳ Waiting for SDK before load...")
		await sdk_ready
	
	print("📥 Loading data from Yandex...")
	
	# Если данные уже загружены, возвращаем их
	if not player_data.is_empty():
		print("📦 Using cached player data: ", player_data)
		return player_data
	
	# Пытаемся загрузить данные через JS
	var code = """
	(function() {
		console.log('📥 Loading player data...');
		
		if (window.player && window.player.getData) {
			window.player.getData()
				.then(data => {
					console.log('✅ Player data loaded:', data);
					window.godotYandexCallback(['player_data_loaded', data || {}]);
				})
				.catch(error => {
					console.error('❌ Load error:', error);
					window.godotYandexCallback(['player_data_loaded', {}]);
				});
		} else {
			console.warn('⚠️ Player API not available for loading');
			window.godotYandexCallback(['player_data_loaded', {}]);
		}
	})();
	"""
	
	JavaScriptBridge.eval(code)
	
	# Ждем загрузки данных
	var wait_time = 0.0
	while player_data.is_empty() and wait_time < 3.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	
	if player_data.is_empty():
		print("⚠️ No player data received after waiting, using empty dict")
		player_data = {}
	
	print("📦 Final loaded data: ", player_data)
	return player_data

func set_leaderboard_score(leaderboard_name: String, score: int):
	"""Установка рекорда в таблице лидеров"""
	if not OS.has_feature("web"):
		print("🏆 Leaderboard (desktop): ", leaderboard_name, " = ", score)
		return
	
	var code = """
	(function() {
		if (window.ysdk && window.ysdk.getLeaderboards) {
			window.ysdk.getLeaderboards().then(lb => {
				lb.setLeaderboardScore('%s', %d)
					.then(() => console.log('🏆 Score set to leaderboard'))
					.catch(err => console.error('❌ Leaderboard error:', err));
			});
		}
	})();
	""" % [leaderboard_name, score]
	JavaScriptBridge.eval(code)

func unlock_achievement(achievement_id: String):
	"""Разблокировка достижения"""
	if not OS.has_feature("web"):
		print("🏅 Achievement unlocked (desktop): ", achievement_id)
		emit_signal("achievement_unlocked", achievement_id)
		return
	
	var code = """
	(function() {
		if (window.player && window.player.setAchievements) {
			window.player.setAchievements([{id: '%s', progress: 100}])
				.then(() => console.log('🏅 Achievement unlocked:', '%s'))
				.catch(err => console.error('❌ Achievement error:', err));
		}
	})();
	""" % [achievement_id, achievement_id]
	JavaScriptBridge.eval(code)
	emit_signal("achievement_unlocked", achievement_id)

func show_fullscreen_ad():
	"""Показ полноэкранной рекламы"""
	if not OS.has_feature("web"):
		print("📺 Fullscreen ad (desktop)")
		return
	
	gameplay_stop()
	
	var code = """
	(function() {
		if (window.ysdk && window.ysdk.adv) {
			window.ysdk.adv.showFullscreenAdv({
				callbacks: {
					onClose: function(wasShown) {
						console.log('📺 Ad closed, wasShown:', wasShown);
						window.godotYandexCallback(['ad_closed', wasShown]);
					},
					onError: function(error) {
						console.error('❌ Ad error:', error);
						window.godotYandexCallback(['ad_error']);
					}
				}
			});
		} else {
			console.warn('⚠️ Adv API not available');
			window.godotYandexCallback(['ad_closed', false]);
		}
	})();
	"""
	JavaScriptBridge.eval(code)

func show_rewarded_ad():
	"""Показ рекламы за вознаграждение"""
	if not OS.has_feature("web"):
		print("🎁 Rewarded ad (desktop)")
		return
	
	gameplay_stop()
	
	var code = """
	(function() {
		if (window.ysdk && window.ysdk.adv) {
			window.ysdk.adv.showRewardedVideo({
				callbacks: {
					onRewarded: function() {
						console.log('🎁 Reward granted');
						window.godotYandexCallback(['ad_rewarded']);
					},
					onClose: function() {
						console.log('📺 Rewarded ad closed');
						window.godotYandexCallback(['ad_closed', false]);
					},
					onError: function(error) {
						console.error('❌ Rewarded ad error:', error);
						window.godotYandexCallback(['ad_error']);
					}
				}
			});
		} else {
			console.warn('⚠️ Adv API not available');
			window.godotYandexCallback(['ad_closed', false]);
		}
	})();
	"""
	JavaScriptBridge.eval(code)
