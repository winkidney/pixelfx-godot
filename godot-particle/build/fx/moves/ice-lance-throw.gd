# reimagined-from: src/fx/moves/ice-lance-throw.js@08361a8fd7dc4188445161a1cf07b32b01f85825
# Ice lance throw: Frost gathers into a spear in his hand, he throws it like a javelin, and the target ices over in a burst of snowflakes and shivers.
# one-shot, 4.34 s, 310x136 canvas, origin [86.0, 134.0], backdrop ground, stand-in 2
# A chain of three, as in the original: the spell charge in ice colours, the lance in flight, a snowflake burst
# on the target.
extends "res://addons/pixelfx_particles/core/build.gd"

const PAL := preload("res://addons/pixelfx_particles/core/palettes.gd").PAL
const THROW := 0.8
const FLY := 0.34
const HIT := THROW + FLY
const TX := 170.0
const SPEED := (TX - 34.0) / FLY


func make() -> void:
	cue("arcane/spell-charge", {"t": 0.06, "until": THROW, "palette": PAL.ice})
	cue("ice/ice-lance", {"t": THROW, "until": HIT, "x": func(t: float) -> float: return 34.0 + (t - THROW) * SPEED, "y": -24.0})
	cue("ice/snowflake-burst", {"t": HIT, "x": TX, "y": -26.0})
