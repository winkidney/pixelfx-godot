# reimagined-from: src/fx/moves/lightning-call.js@c931c21461aa00a1a0f56ddef5edcd47d819ab55
# Lightning call: An arm goes up, a sigil lights under the target, and on the downswing a thick bolt comes down on it; the target jolts through the aftershocks.
# one-shot, 3.00 s, 290x266 canvas, origin [42.0, 231.0], backdrop ground, stand-in 2
# The original chains one effect: the lightning strike on the target.
extends "res://addons/pixelfx_particles/core/build.gd"

const TX := 130.0


func make() -> void:
	cue("lightning/lightning-strike", {"t": 0.0, "x": TX})
