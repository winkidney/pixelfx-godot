# reimagined-from: src/fx/lightning/lightning-strike.js
# Lightning strike: a targeted strike: a sigil charges on the floor, the scene darkens, a thick bolt slams into it,
# arcs race out along the cracks it splits, the channel crumbles to a scorch.
# Bolts are core/bolt.gd lines re-rolled off the effect's clock: a stepped leader feeling its way down, three strokes
# (a white core on the colour layer, a wide glow on the light layer) flickering on the original's beats, arcs along
# the floor; the sigil and scorch are ring shaders, a dark wash dims the scene, sparks and grit burst at each stroke.
extends "res://addons/pixelfx_particles/core/build.gd"

const TOP := -224.0
const LEAD0 := 0.48
const STROKES := [[0.76, 1.0], [1.04, 0.8], [1.26, 0.55]]
const FLICK := [1.0, 0.72, 0.3, 0.95, 0.5, 0.8, 0.22]


func make() -> void:
	ground()
	var C: PackedColorArray = root.ramps.palette
	# the scene darkens as it charges and lifts after
	var night := rect("Night", Rect2(-Vector2(root.origin), Vector2(root.canvas_size)), Color("#04030a"), {"layer": "soft", "back": true})
	key(night, "modulate:a", [[0.0, 0.0], [0.7, 0.45], [1.5, 0.35], [2.4, 0.0]])
	# the sigil charging on the floor, and the scorch it leaves
	var sigil := ring("Sigil", 30, {"radius": 28, "thickness": 1.5, "squash": 0.22, "color": C[5], "ragged": 0.35}, {"back": true})
	key(sigil, "material:shader_parameter/alpha", [[0.0, 0.0], [0.15, 0.8], [0.76, 1.0], [0.9, 0.0]])
	key(sigil, "material:shader_parameter/radius", [[0.0, 34.0], [0.76, 24.0]])
	var sigil_glow := glow("SigilGlow", 34, {"radius": 30, "squash": 0.3, "color": C[4]})
	key(sigil_glow, "material:shader_parameter/alpha", [[0.0, 0.0], [0.7, 0.6], [0.9, 0.0]])
	var scorch := ring("Scorch", 20, {"radius": 18, "squash": 0.2, "color": Color("#17121d"), "ragged": 0.4}, {"back": true})
	key(scorch, "material:shader_parameter/alpha", [[0.0, 0.0], [0.76, 0.0], [0.8, 1.0], [2.6, 1.0], [3.0, 0.0]])

	# the stepped leader feeling its way down
	var leader := bolt("Leader", Vector2(0, TOP), Vector2(0, TOP), {"width": 1, "color": C[5], "jag": 5, "segments": 10, "rate": 20, "branches": 2})
	show(leader, LEAD0, 0.76)
	key(leader, "to", [[LEAD0, Vector2(0, TOP)], [0.76, Vector2(0, -30)]])

	# the strokes: a wide glow and a white core, flickering on the original's beats
	var glow_bolt := bolt("StrokeGlow", Vector2(0, TOP), Vector2.ZERO, {"width": 9, "color": C[4] * Color(1, 1, 1, 0.5), "layer": "light", "jag": 9, "segments": 14, "rate": 12, "seed": 7})
	var core := bolt("Stroke", Vector2(0, TOP), Vector2.ZERO, {"width": 3, "color": Color.WHITE, "jag": 9, "segments": 14, "rate": 12, "seed": 7, "branches": 3, "branch_width": 1})
	var vis := [[0.0, false]]
	for s in STROKES:
		var t0: float = s[0]
		for i in FLICK.size():
			vis.append([t0 + i / 30.0, FLICK[i] * s[1] > 0.4])
		vis.append([t0 + FLICK.size() / 30.0, false])
	key(core, "visible", vis, "nearest")
	key(glow_bolt, "visible", vis, "nearest")
	core.visible = false
	glow_bolt.visible = false
	# the channel crumbling after the last stroke
	var ember := bolt("Channel", Vector2(0, TOP), Vector2.ZERO, {"width": 1, "color": C[6], "jag": 9, "segments": 14, "rate": 0, "seed": 7})
	show(ember, 1.5, 2.6)
	key(ember, "modulate:a", [[1.5, 1.0], [2.6, 0.0]])

	# arcs racing out along the cracks, both ways
	for side in [-1, 1]:
		var arc_bolt := bolt("Crack%s" % ("L" if side < 0 else "R"), Vector2.ZERO, Vector2(side * 4, -1), {"width": 1, "color": C[6], "jag": 2, "segments": 6, "rate": 20})
		show(arc_bolt, 0.76, 1.5)
		key(arc_bolt, "to", [[0.76, Vector2(side * 4, -1)], [1.0, Vector2(side * 52, -1)]])
	# the hit: light, sparks and grit at each stroke
	var hit := glow("HitLight", 70, {"radius": 64, "color": C[5]}, {"at": Vector2(0, -20)})
	var hk := [[0.0, 0.0]]
	for s in STROKES:
		hk += [[s[0] - 0.01, 0.0], [s[0], 0.9 * s[1]], [s[0] + 0.2, 0.15]]
	hk.append([2.0, 0.0])
	key(hit, "material:shader_parameter/alpha", hk)
	var i := 0
	for s in STROKES:
		var sp := particles("Sparks%d" % i, {"at": Vector2(0, -2), "amount": int(30 * s[1]), "lifetime": 0.5, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "streak3", "align": true, "dir": -90, "spread": 80,
			"speed": [60, 200], "gravity": Vector2(0, 260), "ramp": gradient(meta.options.sparks), "collide": {"bounce": 0.3}})
		emit(sp, s[0])
		i += 1
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 24, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "dot1", "dir": -90, "spread": 60, "speed": [30, 90], "gravity": Vector2(0, 220),
		"initial": gradient(["#655b7a", "#4a4263", "#342d45"]), "collide": {"bounce": 0.2}})
	emit(grit, 0.76)
	var smoke := particles("Smoke", {"layer": "soft", "at": Vector2(0, -4), "amount": 8, "lifetime": 1.4, "one_shot": true,
		"explosiveness": 0.6, "emitting": false, "texture": "disc7", "emit": {"box": Vector2(8, 2)}, "dir": -90, "spread": 30,
		"speed": [8, 20], "scale_curve": [[0, 0.6], [1, 1.4]],
		"ramp": gradient([Color("#6e6382", 0.6), Color("#5b5566", 0.4), Color("#5b5566", 0.0)], [0.0, 0.5, 0.95])})
	emit(smoke, 1.3)
