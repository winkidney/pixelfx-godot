# reimagined-from: src/fx/moves/holy-smite.js@8afbf29ad647f73d7d5c16c59cf9d950c09390f7
# Holy smite: Both hands go up and a glint marks the target; he brings them down and a bolt of light drops like a hammer, leaving the target blanched.
# one-shot, 2.80 s, 252x182 canvas, origin [42.0, 151.0], backdrop ground, stand-in 2
# The original chains one effect: the smite on the target.
extends "res://addons/pixelfx_particles/core/build.gd"

const TX := 118.0


func make() -> void:
	cue("holy/smite", {"t": 0.0, "x": TX})
