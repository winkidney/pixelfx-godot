# reimagined-from: src/fx/arcane/rune-circle.js@6520ffdb3ed1da3cd00a1e69677b18da3d815c05
# Rune circle: A rune circle turns on the floor in perspective: a carousel of runes lit by chasing light, a turning square, ticks, motes rising off it.
# loop, 4.00 s, 136x100 canvas, origin [68.0, 80.0], backdrop ground, stand-in 0
# The circle is a canvas shader drawn twice (fx/arcane/_runecircle.gdshader: the far half behind, the near half in
# front): rings, studs, the square and the runes, all turning off the loop's clock; the runes' light is a light
# shader (_runelight); two sparkles chase round the rim with their light on keys; motes rise off the rings and
# twinkles hang over it (particles, with a light copy of the motes); the floor glows and a soft column stands over it.
extends "res://build/fx/arcane/_arcane.gd"

const D := 4.0
const R := 46.0
const RR := 39.0
const RI := 23.0
const SY := 0.3


func pulse(t: float) -> float:
	return 0.85 + 0.15 * sin(t / D * TAU * 4)


func make() -> void:
	# the floor glows, and a soft column of light stands over it
	var floor_glow := glow("FloorGlow", R * 1.4 + 1, {"radius": R * 1.4, "color": C[4], "alpha": 0.24})
	keyf(floor_glow, "material:shader_parameter/alpha", func(t: float): return 0.24 * pulse(t))
	for s in [-1, 1]:
		var side := glow("FloorSide%d" % (s + 1), R * 0.7 + 1, {"radius": R * 0.7, "color": C[5], "alpha": 0.12}, {"at": Vector2(s * R * 0.55, 1)})
		keyf(side, "material:shader_parameter/alpha", func(t: float): return 0.12 * pulse(t))
	var column := glow_line("Column", Vector2(0, 0), Vector2(0, -60), 26, C[4], 0.11, 6.0)
	column.material.set_shader_parameter("k_end", 0.25)
	keyf(column, "material:shader_parameter/alpha", func(t: float): return pulse(t))

	var sz := Vector2(R * 2 + 12, 52)
	var back := shape("CircleBack", arcane_shader("runecircle"), sz, colours({"far": 1.0}), {"at": Vector2(0, -6), "back": true})
	loop_t(back)
	var front := shape("CircleFront", arcane_shader("runecircle"), sz, colours({"far": 0.0}), {"at": Vector2(0, -6)})
	loop_t(front)
	var runes := shape("RuneLight", arcane_shader("runelight"), Vector2(R * 2 + 24, 50), {"RR": RR, "SY": SY, "c4": C[4], "c5": C[5]}, {"at": Vector2(0, -6)})
	loop_t(runes)

	# motes rising off the rings on a slow helix, and their light
	var pts_back := PackedVector2Array()
	var pts_front := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 160:
		var g := rng.randf() * TAU
		var r: float = [R, R, RR, RR, RI][rng.randi() % 5]
		var pt := Vector2(cos(g) * r, sin(g) * r * SY - 2)
		if sin(g) < 0.0:
			pts_back.append(pt)
		else:
			pts_front.append(pt)
	var mote_cols := gradient([Color.WHITE, C[6], C[6], C[5], C[5]])
	for half in [["Back", pts_back, true], ["Front", pts_front, false]]:
		var o := {"back": half[2], "amount": 22, "lifetime": 1.9, "texture": "dot1", "emit": {"points": half[1]},
			"dir": -90, "spread": 12, "speed": [30, 52], "damping": [24, 30], "initial": mote_cols,
			"alpha_curve": [[0, 0], [0.2, 1], [0.65, 1], [1, 0]]}
		var m := particles("Motes" + half[0], o)
		life_rand(m, 0.42)
		var lo := o.duplicate()
		lo.layer = "light"
		lo.texture = "glow8"
		lo.erase("initial")
		lo.color = Color(C[6], 0.15)
		lo.scale = [0.75, 0.75]
		var ml := particles("MoteLight" + half[0], lo)
		life_rand(ml, 0.42)
		ml.seed = m.seed
	particles("Twinkles", {"at": Vector2(0, -20), "amount": 2, "lifetime": 0.45, "texture": "spark7", "emit": {"box": Vector2(R * 0.8, 14)},
		"color": C[6], "scale_curve": [[0, 0.3], [0.5, 1.0], [1, 0.3]]})
	var tw_light := particles("TwinkleLight", {"layer": "light", "at": Vector2(0, -20), "amount": 2, "lifetime": 0.45, "texture": "glow16",
		"emit": {"box": Vector2(R * 0.8, 14)}, "color": Color(C[6], 0.35), "scale_curve": [[0, 0.3], [0.5, 1.0], [1, 0.3]]})
	tw_light.seed = (root.get_node("Twinkles") as GPUParticles2D).seed

	# the two sparks of light running round the rim
	for k in 2:
		var off := k * PI
		var at0 := Vector2(cos(off) * R, sin(off) * R * SY)
		var spark := sparkle("Chase%d" % k, at0, 2.5, C[6], C[5])
		keyf(spark, "position", func(t: float):
			var g := t / D * TAU * 2 + off
			return Vector2(cos(g) * R, sin(g) * R * SY).floor() + Vector2(0.5, 0.5), 0.0, -1.0, 30.0, "nearest")
		keyf(spark, "material:shader_parameter/arm", func(t: float): return 2.5 + sin(t * 30) * 0.8, 0.0, -1.0, 30.0, "nearest")
		var sl := glow("ChaseLight%d" % k, 15, {"radius": 14, "color": C[5], "alpha": 0.4}, {"at": at0})
		keyf(sl, "position", func(t: float):
			var g := t / D * TAU * 2 + off
			return Vector2(cos(g) * R, sin(g) * R * SY))
		var sp_light := glow("ChaseSpark%d" % k, 12, {"radius": 9, "color": C[6], "alpha": 0.5}, {"at": at0})
		keyf(sp_light, "position", func(t: float):
			var g := t / D * TAU * 2 + off
			return Vector2(cos(g) * R, sin(g) * R * SY))


func colours(o: Dictionary) -> Dictionary:
	var out := {"R": R, "RR": RR, "RI": RI, "SY": SY, "c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6], "white": Color.WHITE}
	out.merge(o, true)
	return out
