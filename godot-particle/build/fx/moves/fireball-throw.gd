# reimagined-from: src/fx/moves/fireball-throw.js@d65a6201b1e6ca516865e3cbe47ccfc6e7e9d8e5
# Fireball throw: He gathers fire in his hand, leans back and hurls it: the ball flies, the target takes it in a blast and comes out charred.
# one-shot, 6.81 s, 356x244 canvas, origin [64.0, 198.0], backdrop ground, stand-in 2
# A chain of three effects, as in the original: the spell charge in fire colours in his hand, the fireball flying
# to the target, the blast there.
extends "res://addons/pixelfx_particles/core/build.gd"

const PAL := preload("res://addons/pixelfx_particles/core/palettes.gd").PAL
const THROW := 0.95
const FLY := 0.46
const HIT := THROW + FLY
const SPEED := 340.0
const TX := 190.0


func make() -> void:
	cue("arcane/spell-charge", {"t": 0.08, "until": THROW, "palette": PAL.fire})
	cue("fire/fireball", {"t": THROW, "until": HIT, "x": func(t: float) -> float: return 28.0 + (t - THROW) * SPEED, "y": -22.0})
	cue("explosions/small-explosion", {"t": HIT, "x": TX})
