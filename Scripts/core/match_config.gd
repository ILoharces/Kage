class_name MatchConfig
extends Resource

# Parámetros de balance de una partida 1v1.

@export var match_duration: float = 300.0
## Si es false, el reloj solo baja por las penalizaciones de muerte.
@export var match_timer_enabled: bool = true
@export var starting_traps_per_kind: int = 1
@export var traps_infinite: bool = true
@export var starting_counters_per_kind: int = 1
@export var counters_infinite: bool = true
@export var respawn_base_duration: float = 2.0
@export var respawn_streak_increment: float = 2.0
