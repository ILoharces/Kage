extends Node

# Efectos puntuales, audibles en la partida local.
# Sonidos CC0 de Kenney (kenney.nl).

const _BOMB_PLACE: AudioStream = preload("res://audio/sfx/bomb_place.ogg")
const _BOMB_EXPLODE: AudioStream = preload("res://audio/sfx/bomb_explode.ogg")
const _PISTOL: AudioStream = preload("res://audio/sfx/pistol_shot.ogg")
const _MACHINE_GUN: AudioStream = preload("res://audio/sfx/machinegun_shot.ogg")
const _ORBITAL_ARM: AudioStream = preload("res://audio/sfx/orbital_arm.ogg")
const _ORBITAL_BEAM: AudioStream = preload("res://audio/sfx/orbital_beam.ogg")
const _ORBITAL_IMPACT: AudioStream = preload("res://audio/sfx/orbital_impact.ogg")


func play_trap_placed() -> void:
	_play(_BOMB_PLACE, -6.0)


func play_bomb_exploded() -> void:
	_play(_BOMB_EXPLODE, -2.0)


func play_orbital_armed() -> void:
	_play(_ORBITAL_ARM, -8.0)


func play_weapon_fired(weapon_id: StringName) -> void:
	match weapon_id:
		GameState.PLACEHOLDER_PISTOL_ID:
			_play(_PISTOL, -11.0)
		GameState.MACHINE_GUN_ID:
			_play(_MACHINE_GUN, -10.0, randf_range(0.94, 1.08))
		GameState.ORBITAL_CANNON_ID:
			_play(_ORBITAL_BEAM, -4.0)
			_play(_ORBITAL_IMPACT, -6.0)
		_:
			_play(_PISTOL, -11.0)


func _play(stream: AudioStream, volume_db: float, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
