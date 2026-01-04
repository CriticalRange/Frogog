extends Node
class_name WeaponManager

# Reference to player
var player: Node3D = null

# Weapon instances
var _slime_ball: Node = null
var _tongue_lash: Node = null
var _tadpole_swarm: Node = null
var _croak_blast: Node = null
var _fly_cloud: Node = null
var _amphibian_rage: Node = null

# Preloads
const TongueLashWeapon = preload("res://scripts/weapons/tongue_lash.gd")
const TadpoleSwarmWeapon = preload("res://scripts/weapons/tadpole_swarm.gd")
const CroakBlastWeapon = preload("res://scripts/weapons/croak_blast.gd")
const FlyCloudWeapon = preload("res://scripts/weapons/fly_cloud.gd")
const AmphibianRageWeapon = preload("res://scripts/weapons/amphibian_rage.gd")

func _ready() -> void:
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func unlock_weapon(weapon_id: String) -> void:
	match weapon_id:
		"unlock_tongue_lash":
			if not _tongue_lash:
				_tongue_lash = TongueLashWeapon.new()
				_tongue_lash.player = player
				add_child(_tongue_lash)
				print("🐸 Unlocked: Tongue Lash!")
		
		"unlock_tadpole_swarm":
			if not _tadpole_swarm:
				_tadpole_swarm = TadpoleSwarmWeapon.new()
				_tadpole_swarm.player = player
				add_child(_tadpole_swarm)
				print("🐸 Unlocked: Tadpole Swarm!")
		
		"unlock_croak_blast":
			if not _croak_blast:
				_croak_blast = CroakBlastWeapon.new()
				_croak_blast.player = player
				add_child(_croak_blast)
				print("🐸 Unlocked: Croak Blast!")
		
		"unlock_fly_cloud":
			if not _fly_cloud:
				_fly_cloud = FlyCloudWeapon.new()
				_fly_cloud.player = player
				add_child(_fly_cloud)
				print("🐸 Unlocked: Fly Cloud!")
		
		"unlock_amphibian_rage":
			if not _amphibian_rage:
				_amphibian_rage = AmphibianRageWeapon.new()
				_amphibian_rage.player = player
				add_child(_amphibian_rage)
				print("🐸 Unlocked: Amphibian Rage!")

func is_weapon_unlocked(weapon_id: String) -> bool:
	match weapon_id:
		"unlock_tongue_lash": return _tongue_lash != null
		"unlock_tadpole_swarm": return _tadpole_swarm != null
		"unlock_croak_blast": return _croak_blast != null
		"unlock_fly_cloud": return _fly_cloud != null
		"unlock_amphibian_rage": return _amphibian_rage != null
	return false

func get_unlocked_weapon_count() -> int:
	var count := 0
	if _tongue_lash: count += 1
	if _tadpole_swarm: count += 1
	if _croak_blast: count += 1
	if _fly_cloud: count += 1
	if _amphibian_rage: count += 1
	return count
