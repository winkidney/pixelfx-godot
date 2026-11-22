# reimagined-from: src/fx/moves/dash-strike.js@9d2c7d8aeb053fd4afc94a78bae03725912b3580
# Dash strike: A crouch, then he's across the floor in a blur of after-images and already cutting: a critical hit, a beat, and he hops back to where he started.
# one-shot, 2.30 s, 372x156 canvas, origin [66.0, 136.0], backdrop ground, stand-in 2
# The original chains the sword slash where the dash ends and a critical hit on the target.
extends "res://addons/pixelfx_particles/core/build.gd"

const CUT := 0.16
const HIT := CUT + 0.06
const AT := 116.0
const TX := 176.0


func make() -> void:
	cue("melee/sword-slash", {"t": CUT, "x": AT})
	cue("impacts/crit-hit", {"t": HIT, "x": TX - 10.0, "height": 28.0})
