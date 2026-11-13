# reimagined-from: src/fx/critters/bat.js
# Bat: a bat flaps in four snappy wing frames along a figure-eight, its body bobbing on each beat.
# A critter is a body, not an effect: its frames are the original's (port/frames.py), stepped by the animation.
extends "res://addons/pixelfx_particles/core/build.gd"


func make() -> void:
	frames()
