# reimagined-from: src/fx/moves/rocket-launcher.js@2ac031c97efbfeb715d2b796911b3c0e86bcea23
# Rocket launcher: He drops to one knee, shoulders the tube and fires: the kick shoves him back along the floor, the rocket crawls out on its jet and the target goes up.
# one-shot, 6.56 s, 480x244 canvas, origin [178.0, 198.0], backdrop ground, stand-in 2
# The original chains the launch blast, the rocket speeding up to the target, and the explosion there.
extends "res://addons/pixelfx_particles/core/build.gd"

const FIRE := 0.6
const FLY := 0.56
const HIT := FIRE + FLY
const TX := 200.0
const MY := -21.0
const MX := 34.0


func make() -> void:
	cue("projectiles/muzzle-shotgun", {"t": FIRE, "x": MX, "height": -MY})
	cue("projectiles/rocket", {"t": FIRE, "until": HIT, "y": MY,
		"x": func(t: float) -> float: return MX + 10.0 + pow(maxf(0.0, t - FIRE), 1.5) * ((TX - MX - 16.0) / pow(FLY, 1.5))})
	cue("explosions/small-explosion", {"t": HIT, "x": TX})
