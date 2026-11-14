# reimagined-from: src/fx/moves/meteor-call.js@434a9b5e14c9de8ed7ffa8e7f2b7fa7a35c6d7fe
# Meteor call: A long chant: a circle draws itself round him, it flares, he points, and a burning rock comes down on the target and flattens the scene.
# one-shot, 6.43 s, 380x240 canvas, origin [92.0, 212.0], backdrop ground, stand-in 2
# The original chains the magic circle under the caster and the meteor coming down on the target.
extends "res://addons/pixelfx_particles/core/build.gd"

const HIT := 2.05
const TX := 170.0


func make() -> void:
	cue("arcane/magic-circle-cast", {"t": 0.0})
	cue("fire/meteor", {"t": HIT - 0.62, "x": TX})
