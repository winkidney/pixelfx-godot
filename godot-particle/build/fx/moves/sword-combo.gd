# reimagined-from: src/fx/moves/sword-combo.js@4a0fbb1dad7d3c3fd063370c8cbcc01b84f981a7
# Sword combo: Three strokes walking forward: a slash, a crossing double cut, and a two-handed cleave into the floor that throws the target about.
# one-shot, 2.98 s, 264x150 canvas, origin [72.0, 130.0], backdrop ground, stand-in 2
# Three cuts, as the original chains them: a slash, a double slash a step on, a heavy cleave another step on.
extends "res://addons/pixelfx_particles/core/build.gd"

const B := 0.5
const C := 1.04
const STEP := 10.0


func make() -> void:
	cue("melee/sword-slash", {"t": 0.0})
	cue("melee/double-slash", {"t": B, "x": STEP})
	cue("melee/heavy-cleave", {"t": C, "x": STEP * 2.0})
