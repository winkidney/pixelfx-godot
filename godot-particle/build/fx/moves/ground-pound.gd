# reimagined-from: src/fx/moves/ground-pound.js@5b8414e5deea0c57deae3ac3ac5817f6b368371c
# Ground pound: He coils, leaps out of frame height, hangs, and comes down like a rock: the floor cracks, shock waves race out and throw the target about as they pass.
# one-shot, 3.82 s, 304x204 canvas, origin [152.0, 168.0], backdrop ground, stand-in 2
# The original chains one effect: the ground slam where he lands.
extends "res://addons/pixelfx_particles/core/build.gd"

const LAND := 0.62


func make() -> void:
	cue("impacts/ground-slam", {"t": LAND})
