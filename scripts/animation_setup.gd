@tool
extends Node
class_name MixamoAnimationLoader

## Mixamo Animation Loader
##
## Bu script Mixamo FBX animasyonlarını yükler, track'leri temizler,
## in-place yapar ve AnimationPlayer'a ekler.
##
## Kullanım:
##   var loader = MixamoAnimationLoader.new()
##   loader.setup_player_animations(animation_player, skeleton)
##   loader.setup_enemy_animations(animation_player, skeleton)

# Animation library cache - loaded once, reused for all instances
static var _player_anim_cache: AnimationLibrary = null
static var _enemy_anim_cache: AnimationLibrary = null
static var _boss_anim_cache: AnimationLibrary = null

# Mixamo animasyon FBX dosyaları ve ayarları
const ANIMATION_CONFIGS := {
	"idle": {
		"uid": "uid://cj1y4sd8kxqg",  # Scary Clown Idle.fbx
		"path": "res://assets/Scary Clown Idle.fbx",
		"loop": true,
		"speed": 1.0,
		"in_place": true,
	},
	"walk": {
		"uid": "uid://dvpfjy6m1opdp",  # Scary Clown Start Walking.fbx
		"path": "res://assets/Scary Clown Start Walking.fbx",
		"loop": true,
		"speed": 1.0,
		"in_place": true,
	},
	"stop": {
		"uid": "uid://daevfqo3r6diq",  # Scary Clown Stopping.fbx
		"path": "res://assets/Scary Clown Stopping.fbx",
		"loop": false,
		"speed": 1.0,
		"in_place": true,
	},
}

# Enemy animations
const ENEMY_ANIMATION_CONFIGS := {
	"walk": {
		"uid": "uid://cwu1imo8ur8m3",  # Wheelbarrow Walk.fbx
		"path": "res://assets/Wheelbarrow Walk.fbx",
		"loop": true,
		"speed": 1.2,
		"in_place": true,
	},
	"death": {
		"uid": "uid://bogmq30ddw8rm",  # Enemy Death.fbx
		"path": "res://assets/Enemy Death.fbx",
		"loop": false,
		"speed": 1.0,
		"in_place": true,
	},
}

# Boss animations
const BOSS_ANIMATION_CONFIGS := {
	"walk": {
		"uid": "uid://c1rx4srp6yorr",  # Zombie Run.fbx
		"path": "res://assets/boss/Zombie Run.fbx",
		"loop": true,
		"speed": 0.8,
		"in_place": true,
	},
	"peck": {
		"uid": "uid://cx2fm32ldj0",  # Picking Up.fbx
		"path": "res://assets/boss/Picking Up.fbx",
		"loop": false,
		"speed": 1.0,
		"in_place": true,
	},
	"death": {
		"uid": "uid://cq2fllmguxfxr",  # Death From Right.fbx
		"path": "res://assets/boss/Death From Right.fbx",
		"loop": false,
		"speed": 1.0,
		"in_place": true,
	},
}

# Skeleton bone adları cache
var _skeleton_bones: Array[String] = []

static func setup_player_animations(anim_player: AnimationPlayer, skeleton: Skeleton3D) -> AnimationLibrary:
	# Return cached library if available
	if _player_anim_cache:
		_assign_cached_library(anim_player, _player_anim_cache, "player")
		return _player_anim_cache

	var loader := MixamoAnimationLoader.new()
	_player_anim_cache = loader._setup_animations(anim_player, skeleton, ANIMATION_CONFIGS, "player")
	return _player_anim_cache

static func setup_enemy_animations(anim_player: AnimationPlayer, skeleton: Skeleton3D) -> AnimationLibrary:
	# Return cached library if available
	if _enemy_anim_cache:
		_assign_cached_library(anim_player, _enemy_anim_cache, "enemy")
		return _enemy_anim_cache

	var loader := MixamoAnimationLoader.new()
	_enemy_anim_cache = loader._setup_animations(anim_player, skeleton, ENEMY_ANIMATION_CONFIGS, "enemy")
	return _enemy_anim_cache

static func setup_boss_animations(anim_player: AnimationPlayer, skeleton: Skeleton3D) -> AnimationLibrary:
	# Return cached library if available
	if _boss_anim_cache:
		_assign_cached_library(anim_player, _boss_anim_cache, "boss")
		return _boss_anim_cache

	var loader := MixamoAnimationLoader.new()
	_boss_anim_cache = loader._setup_animations(anim_player, skeleton, BOSS_ANIMATION_CONFIGS, "boss")
	return _boss_anim_cache

static func _assign_cached_library(anim_player: AnimationPlayer, lib: AnimationLibrary, lib_name: String) -> void:
	# Remove existing library with same name
	if anim_player.has_animation_library(lib_name):
		anim_player.remove_animation_library(lib_name)
	# Add cached library (duplicate it since AnimationLibrary can't be shared)
	anim_player.add_animation_library(lib_name, lib)

func _setup_animations(anim_player: AnimationPlayer, skeleton: Skeleton3D, configs: Dictionary, lib_name: String) -> AnimationLibrary:
	if not anim_player:
		push_error("MixamoAnimationLoader: AnimationPlayer gerekli!")
		return null

	# Skeleton bone adlarını cache'le
	_cache_skeleton_bones(skeleton)

	# AnimationPlayer'dan Skeleton'a olan yolu hesapla
	var skeleton_path := ""
	if skeleton:
		skeleton_path = str(anim_player.get_path_to(skeleton))
		print("Skeleton path (AnimationPlayer'dan): ", skeleton_path)

	print("=== MixamoAnimationLoader: Animasyonlar yükleniyor ===")
	print("Skeleton bone sayısı: ", _skeleton_bones.size())

	# Yeni AnimationLibrary oluştur
	var lib := AnimationLibrary.new()

	# Her animasyon config için
	for anim_name in configs:
		var config: Dictionary = configs[anim_name]
		var anim := _load_and_process_animation(config, skeleton, skeleton_path)

		if anim:
			lib.add_animation(anim_name, anim)
			print("✓ Animasyon eklendi: ", anim_name)
		else:
			push_warning("✗ Animasyon yüklenemedi: ", anim_name)

	# Mevcut kütüphaneleri temizle ve yenisini ekle
	for existing_lib in anim_player.get_animation_library_list():
		anim_player.remove_animation_library(existing_lib)

	anim_player.add_animation_library(lib_name, lib)

	print("=== MixamoAnimationLoader: Tamamlandı ===")
	print("Toplam animasyon: ", lib.get_animation_list().size())

	return lib

func _cache_skeleton_bones(skeleton: Skeleton3D) -> void:
	_skeleton_bones.clear()
	if skeleton:
		for i in range(skeleton.get_bone_count()):
			_skeleton_bones.append(skeleton.get_bone_name(i))
		print("Skeleton bones: ", _skeleton_bones)

func _load_and_process_animation(config: Dictionary, skeleton: Skeleton3D, skeleton_path: String) -> Animation:
	var anim_lib: AnimationLibrary = null

	# Önce UID ile yüklemeyi dene
	if config.has("uid") and not config.uid.is_empty():
		anim_lib = load(config.uid)

	# UID başarısız olursa path ile dene
	if not anim_lib and config.has("path"):
		anim_lib = load(config.path)

	if not anim_lib:
		push_error("Animasyon kütüphanesi yüklenemedi: ", config)
		return null

	# AnimationLibrary'den ilk animasyonu al
	var anim_names := anim_lib.get_animation_list()
	if anim_names.is_empty():
		push_error("Animasyon kütüphanesi boş!")
		return null

	var source_anim: Animation = anim_lib.get_animation(anim_names[0])
	if not source_anim:
		push_error("Kaynak animasyon alınamadı!")
		return null

	# Animasyonu kopyala ve işle
	var processed_anim := _process_animation(source_anim.duplicate(), config, skeleton, skeleton_path)

	return processed_anim

func _process_animation(anim: Animation, config: Dictionary, skeleton: Skeleton3D, skeleton_path: String) -> Animation:
	# 1. Track path'lerini düzelt (skeleton yolunu güncelle)
	_fix_track_paths(anim, skeleton_path)
	
	# 2. Geçersiz track'leri temizle
	_clean_tracks(anim, skeleton)
	
	# 3. In-place yap (root motion kaldır)
	if config.get("in_place", true):
		_force_animation_in_place(anim, skeleton, skeleton_path)
	
	# 4. Hız ayarla
	var speed: float = config.get("speed", 1.0)
	if speed != 1.0:
		_adjust_animation_speed(anim, speed)
	
	# 5. Loop modu ayarla
	var should_loop: bool = config.get("loop", false)
	anim.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
	
	return anim

func _fix_track_paths(anim: Animation, skeleton_path: String) -> void:
	# AnimationPlayer'ın root_node'u CharacterModel olarak ayarlandı
	# Bu yüzden track path'leri sadece "Skeleton3D:bone_name" formatında olmalı
	
	var fixed_count := 0
	
	for i in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(i))
		
		# Skeleton track mi kontrol et (format: "NodePath:bone_name")
		if ":" in track_path:
			var parts := track_path.split(":")
			if parts.size() >= 2:
				var node_path := parts[0]
				var bone_name := parts[1]
				
				# Sadece "Skeleton3D" olarak değiştir (root_node CharacterModel olduğu için)
				if node_path != "Skeleton3D":
					var new_path := "Skeleton3D:" + bone_name
					anim.track_set_path(i, NodePath(new_path))
					fixed_count += 1
	
	if fixed_count > 0:
		print("  - ", fixed_count, " track path düzeltildi")

func _clean_tracks(anim: Animation, skeleton: Skeleton3D) -> void:
	if not skeleton:
		return
	
	var tracks_to_remove: Array[int] = []
	
	# Geriye doğru iterate et (silme sırasında index kayması önlenir)
	for i in range(anim.get_track_count() - 1, -1, -1):
		var track_path := str(anim.track_get_path(i))
		
		# Skeleton track mi kontrol et (format: "NodePath:bone_name")
		if ":" in track_path:
			var parts := track_path.split(":")
			if parts.size() >= 2:
				var bone_name := parts[1]
				
				# Bu bone skeleton'da var mı?
				if bone_name not in _skeleton_bones:
					# Bone bulunamadı, track'i kaldırmak için işaretle
					tracks_to_remove.append(i)
	
	# Track'leri kaldır
	for track_idx in tracks_to_remove:
		anim.remove_track(track_idx)
	
	if tracks_to_remove.size() > 0:
		print("  - ", tracks_to_remove.size(), " geçersiz track kaldırıldı")

func _force_animation_in_place(anim: Animation, skeleton: Skeleton3D, skeleton_path: String) -> void:
	if not skeleton:
		return
	
	# Root bone'u bul (genellikle Hips veya ilk bone)
	var root_bone_names := ["Hips", "mixamorig_Hips", "pelvis", "Pelvis", "Root", "root"]
	var root_bone_idx := -1
	var root_bone_name := ""
	
	for bone_name in root_bone_names:
		root_bone_idx = skeleton.find_bone(bone_name)
		if root_bone_idx >= 0:
			root_bone_name = bone_name
			break
	
	# Root bone bulunamazsa, ilk bone'u kullan
	if root_bone_idx < 0 and skeleton.get_bone_count() > 0:
		root_bone_idx = 0
		root_bone_name = skeleton.get_bone_name(0)
	
	if root_bone_idx < 0:
		return
	
	# Beklenen track path'i oluştur
	var expected_track := skeleton_path + ":" + root_bone_name if not skeleton_path.is_empty() else root_bone_name
	
	# Root bone'un position track'ini bul ve XZ hareketini sıfırla
	for i in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(i))
		var track_type := anim.track_get_type(i)
		
		# Position track mi ve root bone mu?
		if track_type == Animation.TYPE_POSITION_3D and root_bone_name in track_path:
			_zero_root_motion(anim, i)
			print("  - Root motion kaldırıldı: ", track_path)

func _zero_root_motion(anim: Animation, track_idx: int) -> void:
	var key_count := anim.track_get_key_count(track_idx)
	if key_count == 0:
		return
	
	# İlk frame'deki pozisyonu referans al
	var first_pos: Vector3 = anim.track_get_key_value(track_idx, 0)
	
	# Tüm key'lerde pozisyonu ilk frame'e sabitle (XYZ tamamen sabit)
	# Bu sayede karakter animasyon sırasında hareket etmez ve yükselmez
	for i in range(key_count):
		# Pozisyonu ilk frame'in değerine sabitle
		anim.track_set_key_value(track_idx, i, first_pos)

func _adjust_animation_speed(anim: Animation, speed: float) -> void:
	if speed <= 0.0 or speed == 1.0:
		return
	
	# Animasyon süresini ayarla
	anim.length = anim.length / speed
	
	# Tüm key zamanlarını ölçekle
	for track_idx in range(anim.get_track_count()):
		var key_count := anim.track_get_key_count(track_idx)
		
		# Key'leri geçici olarak sakla
		var keys: Array[Dictionary] = []
		for i in range(key_count):
			keys.append({
				"time": anim.track_get_key_time(track_idx, i) / speed,
				"value": anim.track_get_key_value(track_idx, i),
				"transition": anim.track_get_key_transition(track_idx, i)
			})
		
		# Track'i temizle ve yeni key'leri ekle
		for i in range(key_count - 1, -1, -1):
			anim.track_remove_key(track_idx, i)
		
		for key_data in keys:
			anim.track_insert_key(track_idx, key_data.time, key_data.value, key_data.transition)

## Debug: Skeleton bone adlarını yazdır
static func print_skeleton_bones(skeleton: Skeleton3D) -> void:
	if not skeleton:
		print("Skeleton yok!")
		return
	
	print("\n=== SKELETON BONES ===")
	print("Bone sayısı: ", skeleton.get_bone_count())
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		var parent_idx := skeleton.get_bone_parent(i)
		var parent_name := skeleton.get_bone_name(parent_idx) if parent_idx >= 0 else "ROOT"
		print("  [", i, "] ", bone_name, " <- ", parent_name)
	print("======================\n")

## Debug: Animasyon track'lerini yazdır
static func print_animation_tracks(anim: Animation, name: String = "") -> void:
	print("\n=== ANIMATION: ", name, " ===")
	print("Süre: ", anim.length, "s")
	print("Loop: ", anim.loop_mode)
	print("Track sayısı: ", anim.get_track_count())
	for i in range(anim.get_track_count()):
		var track_type := anim.track_get_type(i)
		var type_name := _get_track_type_name(track_type)
		print("  [", i, "] ", type_name, " -> ", anim.track_get_path(i))
	print("======================\n")

static func _get_track_type_name(type: int) -> String:
	match type:
		Animation.TYPE_VALUE: return "VALUE"
		Animation.TYPE_POSITION_3D: return "POSITION_3D"
		Animation.TYPE_ROTATION_3D: return "ROTATION_3D"
		Animation.TYPE_SCALE_3D: return "SCALE_3D"
		Animation.TYPE_BLEND_SHAPE: return "BLEND_SHAPE"
		Animation.TYPE_METHOD: return "METHOD"
		Animation.TYPE_BEZIER: return "BEZIER"
		Animation.TYPE_AUDIO: return "AUDIO"
		Animation.TYPE_ANIMATION: return "ANIMATION"
		_: return "UNKNOWN"
