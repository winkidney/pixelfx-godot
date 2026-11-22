# reimagined-from: src/fx/moves/earth-stomp.js@a4353ca12e4f51b6c6f0cb1f1e5978cbe6c0c877
# Earth stomp: A knee comes up, the boot slams down, the floor heaves under the target and a stone spike rams up through it.
# one-shot, 3.46 s, 290x142 canvas, origin [50.0, 128.0], backdrop ground, stand-in 2
# The original chains one effect: the earth spike under the target, as the boot comes down.
extends "res://addons/pixelfx_particles/core/build.gd"

const STOMP := 0.06
const TX := 112.0


func make() -> void:
	cue("nature/earth-spike", {"t": STOMP, "x": TX})
