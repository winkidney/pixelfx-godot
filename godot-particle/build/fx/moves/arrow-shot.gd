# reimagined-from: src/fx/moves/arrow-shot.js@e1c4ae18c7e9234709f936ed31a8790c47f35100
# Arrow shot: He raises the bow, draws to his cheek, holds his breath and looses: the string snaps forward, the arrow crosses the floor and thuds home.
# one-shot, 1.90 s, 300x74 canvas, origin [38.0, 66.0], backdrop ground, stand-in 2
# The original chains the arrow in flight to the target and a hit spark there.
extends "res://addons/pixelfx_particles/core/build.gd"

const LOOSE := 0.56
const FLY := 0.24
const HIT := LOOSE + FLY
const TX := 180.0
const SPEED := (TX - 30.0) / FLY


func make() -> void:
	cue("projectiles/arrow", {"t": LOOSE, "until": HIT, "x": func(t: float) -> float: return 30.0 + (t - LOOSE) * SPEED, "y": -28.0})
	cue("impacts/hit-spark", {"t": HIT, "x": TX - 10.0, "height": 30.0})
