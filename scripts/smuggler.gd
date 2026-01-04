extends Interactable
class_name Smuggler

## Shady merchant that trades items with the player

enum TradeType {
	HEALTH_FOR_XP,
	MONEY_FOR_BUFF,
	XP_FOR_SPEED,
	RANDOM_TRADE
}

var _can_use: bool = true
var _trade_cooldown: float = 30.0

# Current trade offer
var _current_trade: Dictionary = {}

func _ready() -> void:
	super._ready()
	interaction_prompt = "Press E to Trade"
	_generate_new_trade()
	_create_visual()

func _create_visual() -> void:
	# Scale up the entire interactible
	scale = Vector3(1.2, 1.2, 1.2)

	# Load and instantiate the Look Around animated character
	var look_around_scene = load("res://assets/Look Around.fbx")
	if look_around_scene:
		var character = look_around_scene.instantiate()
		character.name = "SmugglerModel"
		character.position = Vector3(0, 0.1, 0)  # Raise slightly to avoid sinking
		add_child(character)

		# Find and play the animation
		var anim_player = character.find_child("AnimationPlayer", true, false)
		if anim_player:
			# Get animation list and play the first one (usually the look around animation)
			var anims = anim_player.get_animation_list()
			if anims.size() > 0:
				anim_player.play(anims[0])
				anim_player.get_animation(anims[0]).loop_mode = Animation.LOOP_LINEAR

func _process(delta: float) -> void:
	super._process(delta)

	# Update trade prompt when in range
	if _can_use and _in_range and _prompt_label:
		_update_trade_prompt()

func _update_trade_prompt() -> void:
	if _current_trade.is_empty():
		return

	var prompt_text = "Press E to Trade\n"
	prompt_text += "Give: " + _current_trade.give + "\n"
	prompt_text += "Get: " + _current_trade.get
	_prompt_label.text = prompt_text

func _generate_new_trade() -> void:
	var trade_type := randi() % 4

	match trade_type:
		0:  # HEALTH_FOR_XP
			_current_trade = {
				"type": "HEALTH_FOR_XP",
				"give": "25 HP",
				"get": "150 XP"
			}

		1:  # MONEY_FOR_BUFF
			var buffs = ["+10% Damage", "+10% Speed", "+15% Fire Rate"]
			var buff = buffs[randi() % buffs.size()]
			_current_trade = {
				"type": "MONEY_FOR_BUFF",
				"give": "Some HP",
				"get": buff + " for 30s"
			}

		2:  # XP_FOR_SPEED
			_current_trade = {
				"type": "XP_FOR_SPEED",
				"give": "50 XP",
				"get": "+20% Speed for 20s"
			}

		3:  # RANDOM_TRADE - good deal!
			var rewards = ["Full Heal", "300 XP", "Permanent +5% All Stats", "Random Upgrade"]
			var reward = rewards[randi() % rewards.size()]
			_current_trade = {
				"type": "RANDOM_TRADE",
				"give": "Nothing (Lucky!)",
				"get": reward
			}

func _perform_interaction(player: Node3D) -> void:
	if not _can_use:
		return

	_can_use = false
	_play_activate_effect()

	# Execute trade
	_execute_trade(player)

	# Smuggler leaves after trade
	_remove_after_delay()

func _remove_after_delay() -> void:
	# Fade out and disappear
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.4)
	tween.tween_property(self, "global_position", global_position + Vector3(0, 2, 0), 0.4)
	tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.4)
	tween.tween_callback(func(): queue_free()).set_delay(0.4)

func _execute_trade(player: Node3D) -> void:
	if _current_trade.is_empty():
		return

	match _current_trade.type:
		"HEALTH_FOR_XP":
			if player.has_method("take_damage"):
				player.take_damage(25)  # Cost HP
			if player.has_method("add_xp"):
				player.add_xp(150)
			_show_trade_result("-25 HP  +150 XP", Color.CYAN)

		"MONEY_FOR_BUFF":
			if player.has_method("take_damage"):
				player.take_damage(20)
			var buff_type = randi() % 3
			match buff_type:
				0:
					if player.has_method("apply_damage_boost"):
						player.apply_damage_boost(10.0)
					_show_trade_result("-20 HP  +10% DAMAGE!", Color.ORANGE)
				1:
					if player.has_method("apply_speed_boost"):
						player.apply_speed_boost(30.0)
					_show_trade_result("-20 HP  +10% SPEED!", Color.GREEN)
				2:
					if player.has_method("apply_rapid_fire"):
						player.apply_rapid_fire(30.0)
					_show_trade_result("-20 HP  +15% FIRE RATE!", Color.YELLOW)

		"XP_FOR_SPEED":
			if player.has_method("stats"):
				player.stats.xp_value -= 50
				if player.stats.xp_value < 0:
					player.stats.xp = 0
					player.stats.xp_value = player.stats.xp_required - player.stats.xp
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(20.0)
			_show_trade_result("-50 XP  +20% SPEED!", Color.LIME_GREEN)

		"RANDOM_TRADE":
			var reward_type = randi() % 4
			match reward_type:
				0:  # Full Heal
					if player.has_method("heal"):
						player.heal(999)
					_show_trade_result("FULL HEAL!", Color.GREEN)
				1:  # Big XP
					if player.has_method("add_xp"):
						player.add_xp(300)
					_show_trade_result("+300 XP!", Color.CYAN)
				2:  # Permanent buff
					if player.has_method("grant_upgrade"):
						player.grant_upgrade("all", 0.05)
					_show_trade_result("+5% ALL STATS!", Color.GOLD)
				3:  # Random upgrade
					if player.has_method("show_upgrade_selection"):
						player.show_upgrade_selection()
					_show_trade_result("CHOOSE YOUR UPGRADE!", Color.GOLD)

func _show_trade_result(text: String, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
