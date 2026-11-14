# reimagined-from: src/fx/moves/pistol-shots.js@c735d9726d214b98a0e209652823d290d52c4f22
# Pistol shots: Three aimed shots: the gun kicks up each time and settles, tracers cross the floor, and the target staggers under each hit.
# one-shot, 2.60 s, 378x76 canvas, origin [111.0, 72.0], backdrop ground, stand-in 2
# Three shots, as the original chains them: a muzzle flash, a tracer to the target, a hit spark there.
extends "res://addons/pixelfx_particles/core/build.gd"

const SHOTS := [0.14, 0.42, 0.7]
const FLY := 0.12
const TX := 180.0
const BY := -32.0
const MX := 28.0


func make() -> void:
	for t0: float in SHOTS:
		cue("projectiles/muzzle-pistol", {"t": t0, "x": MX, "height": -BY})
		cue("projectiles/bullet-tracer", {"t": t0, "until": t0 + FLY, "y": BY,
			"x": func(u: float) -> float: return MX + 4.0 + (u - t0) * ((TX - MX - 14.0) / FLY)})
		cue("impacts/hit-spark", {"t": t0 + FLY, "x": TX - 10.0, "height": 28.0})
