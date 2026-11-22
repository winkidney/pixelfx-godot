# reimagined-from: src/fx/arcane/blink-out.js@d905aa3977e9461ec92b829d19a005dbdae43b71
# Blink out: The caster crackles with gathering light, flashes white, squeezes into a line of light that collapses and pops away in sparks.
# one-shot, 1.60 s, 136x96 canvas, origin [68.0, 80.0], backdrop ground, stand-in 2
# The stand-in (the effect's Actor) fills with light as an outline crackles round it (fx/arcane/_silhouette.gdshader,
# re-rolled every frame) and streaks rush in; it flashes white and squeezes into a line (the silhouette squeezed off
# its own pixels), the line shrinks to a point (rects keyed), pops in a flare, a ring rolling out across the floor and
# a burst of bits, sparks and stars (one-shot emitters), leaving a violet ghost that thins away.
extends "res://build/fx/arcane/_arcane.gd"

const OUT := 0.32
const SQUEEZE := 0.12
const COLLAPSE := 0.08
const POP := OUT + SQUEEZE + COLLAPSE

var MX := 0.0
var MY := 0.0
var AH := 38.0


func make() -> void:
	ground()
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	AH = tex.get_height()
	MY = -AH + AH * 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	var fl := glow("FloorLight", 27, {"radius": 26, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -1), "back": true})
	keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.3 * (t / OUT if t < OUT else 1.0 - seg(t, POP, POP + 0.3)) if t < POP + 0.3 else 0.0, 0.0, POP + 0.34)

	# the afterimage it leaves: a translucent violet ghost that thins away
	var ghost := silhouette("Ghost", 2, C[4], C[3], {"at": Vector2(0, -AH / 2.0), "back": true})
	keyf(ghost, "material:shader_parameter/alpha", func(t: float): return 0.5 * (1.0 - seg(t, POP, POP + 0.6)), POP, POP + 0.6)
	show(ghost, POP, POP + 0.6)
	ring_out(POP)

	# the body fills with light and an outline of light crackles round it, thicker as it gathers
	var body := actor_node()
	key(body, "visible", [[0.0, true], [OUT - 0.002, false]], "nearest")
	body.material.set_shader_parameter("flash_color", C[6].lerp(Color.WHITE, 0.5))
	keyf(body, "material:shader_parameter/flash", func(t: float): return minf(1.0, 1.8 * pow(t / OUT, 2.0)), 0.0, OUT, 30.0)
	var crackle := silhouette("Crackle", 1, C[6], C[6], {"at": Vector2(0, -AH / 2.0)})
	keyf(crackle, "material:shader_parameter/chance", func(t: float): return 0.25 + 0.65 * t / OUT, 0.0, OUT, 30.0, "nearest")
	keyf(crackle, "material:shader_parameter/grain", func(t: float): return floorf(t * 30.0 + 0.001), 0.0, OUT, 30.0, "nearest")
	keyf(crackle, "material:shader_parameter/hot", func(t: float): return 1.0 if t / OUT > 0.6 else 0.0, 0.0, OUT, 30.0, "nearest")
	show(crackle, 0.0, OUT)
	var gather := glow("GatherLight", 31, {"radius": 30, "color": C[5], "alpha": 0.0}, {"at": Vector2(MX, MY)})
	keyf(gather, "material:shader_parameter/alpha", func(t: float): return 0.5 * t / OUT, 0.0, OUT)
	show(gather, 0.0, OUT)
	# streaks rushing in to the chest
	var pts := PackedVector2Array()
	for i in 100:
		var a := rng.randf() * TAU
		var d := rng.randf_range(22, 44)
		pts.append(Vector2(cos(a) * d, minf(-2.0 - MY, sin(a) * d)))
	var rush := particles("Rush", {"at": Vector2(MX, MY), "amount": 16, "lifetime": 0.18, "texture": "streak6", "align": true, "emitting": false,
		"emit": {"points": pts}, "radial": [-1300, -900], "initial": gradient([C[6], C[5]]), "ramp": gradient([C[5], C[6], Color.WHITE], [0.0, 0.5, 0.85])})
	radial_speed(rush, -50, -25)
	life_rand(rush, 0.33)
	emit(rush, 0.0, OUT - 0.04)

	# it flashes white and squeezes into a line
	var sil := silhouette("Silhouette", 0, Color.WHITE, C[6])
	keyf(sil, "material:shader_parameter/sx", func(t: float): return 1.0 if t < OUT + 0.05 else 1.0 - in_cubic((t - OUT - 0.05) / (SQUEEZE - 0.05)), OUT, OUT + SQUEEZE, 60.0, "nearest")
	show(sil, OUT, OUT + SQUEEZE)
	var sl := glow("SqueezeLight", 41, {"radius": 40, "color": C[5], "alpha": 0.8}, {"at": Vector2(MX, MY)})
	keyf(sl, "material:shader_parameter/radius", func(t: float): return 40.0 if t < OUT + 0.05 else 34.0, OUT, OUT + 0.1, 30.0, "nearest")
	show(sl, OUT, OUT + SQUEEZE)
	light_burst("Out", OUT, Vector2(MX, MY - 6), 54, C[5], 0.9, 0.3)
	light_burst("OutHot", OUT, Vector2(MX, MY), 26, Color.WHITE, 0.8, 0.1)

	# the line shrinks to a point
	var line_g := group("Line", {"at": Vector2(MX, MY)})
	show(line_g, OUT + SQUEEZE, POP)
	var hh := func(t: float) -> float: return (AH / 2.0 + 2.0) * (1.0 - in_quad((t - OUT - SQUEEZE) / COLLAPSE))
	var tips := rect("Tips", Rect2(0, 0, 1, 1), C[6], {"parent": line_g})
	tips.modulate.a = 0.7
	var core := rect("Core", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": line_g})
	keyf(tips, "position", func(t: float): return Vector2(0, -floorf(hh.call(t)) - 3), OUT + SQUEEZE, POP, 60.0, "nearest")
	keyf(tips, "size", func(t: float): return Vector2(1, 2 * floorf(hh.call(t)) + 7), OUT + SQUEEZE, POP, 60.0, "nearest")
	keyf(core, "position", func(t: float): return Vector2(0, -ceilf(hh.call(t)) + 1), OUT + SQUEEZE, POP, 60.0, "nearest")
	keyf(core, "size", func(t: float): return Vector2(1, maxf(1.0, 2 * ceilf(hh.call(t)) - 1)), OUT + SQUEEZE, POP, 60.0, "nearest")
	for sx in [-1, 1]:
		var sd := rect("Side%d" % (sx + 1), Rect2(sx, 0, 1, 1), C[5], {"parent": line_g})
		sd.modulate.a = 0.6
		keyf(sd, "position", func(t: float): return Vector2(sx, -floorf(hh.call(t) * 0.7)), OUT + SQUEEZE, POP, 60.0, "nearest")
		keyf(sd, "size", func(t: float): return Vector2(1, 2 * floorf(hh.call(t) * 0.7) + 1), OUT + SQUEEZE, POP, 60.0, "nearest")
		keyf(sd, "visible", func(t: float): return hh.call(t) > 4.0, OUT + SQUEEZE, POP, 60.0, "nearest")
	var ll := glow("LineLight", 31, {"radius": 30, "color": C[5], "alpha": 0.9}, {"at": Vector2(MX, MY)})
	show(ll, OUT + SQUEEZE, POP)
	var lw := glow("LineHot", 9, {"radius": 8, "color": Color.WHITE, "alpha": 0.5}, {"at": Vector2(MX, MY)})
	show(lw, OUT + SQUEEZE, POP)

	# the pop: a flare, a white point, a glint, light; bits of the character fly off and drift up, sparks, stars
	var fl2 := flare("Flare", Vector2(MX, MY), 24, 1.0)
	keyf(fl2, "material:shader_parameter/len", func(t: float): return 22.0 * pow(1.0 - seg(t, POP, POP + 0.22), 1.5) + 2.0, POP, POP + 0.22)
	keyf(fl2, "material:shader_parameter/k", func(t: float): return 1.0 - seg(t, POP, POP + 0.22), POP, POP + 0.22)
	show(fl2, POP, POP + 0.22)
	var dot := ring("PopCore", 6, {"radius": 5, "color": Color.WHITE}, {"at": Vector2(MX, MY)})
	keyf(dot, "material:shader_parameter/radius", func(t: float): return 4.0 * (1.0 - (t - POP) / 0.22 / 0.3) + 1.0, POP, POP + 0.066)
	show(dot, POP, POP + 0.066)
	var gl := sparkle("Glint", Vector2(MX, MY - 1), 3, C[6], C[5])
	show(gl, POP, POP + 0.3)
	light_burst("Pop", POP, Vector2(MX, MY - 6), 58, C[5], 0.9, 0.35)
	light_burst("PopHot", POP, Vector2(MX, MY), 24, Color.WHITE, 0.9, 0.08)
	var cols := gradient([Color.WHITE, C[6], C[6], C[5], C[4]])
	for s in [-1, 1]:
		for kind in [["", "dot1", 38], ["Big", "dot2", 17]]:
			var e := particles("Bits%s%s" % [kind[0], "L" if s < 0 else "R"], {"at": Vector2(MX, -AH / 2.0), "amount": kind[2], "lifetime": 0.95,
				"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": kind[1], "emit": {"box": Vector2(1, AH / 2.0 - 2)},
				"dir": 90 - s * 90 - s * 20, "spread": 30, "speed": [25, 105], "damping": [30, 60], "gravity": Vector2(0, -30), "initial": cols,
				"alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})
			life_rand(e, 0.47)
			emit(e, POP)
	var sparks := particles("Sparks", {"at": Vector2(MX, MY), "amount": 18, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak4", "align": true, "spread": 180, "speed": [80, 240], "damping": [150, 300], "gravity": Vector2(0, 428),
		"ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
	life_rand(sparks, 0.6)
	emit(sparks, POP)
	var stars := particles("Stars", {"at": Vector2(MX, MY), "amount": 14, "lifetime": 0.9, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "spread": 180, "speed": [20, 110], "damping": [40, 90], "gravity": Vector2(0, -20),
		"initial": gradient([Color.WHITE, C[6], C[5]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(stars, 0.55)
	emit(stars, POP)
