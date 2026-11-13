# reimagined-from: src/fx/arcane/blink-in.js@ae7ec5071adacf19538e28d2d6022cd00315d1b6
# Blink in: Glittering bits spiral in to a point of light that opens into a line, then into a white silhouette that cools into the caster.
# one-shot, 1.40 s, 136x96 canvas, origin [68.0, 80.0], backdrop ground, stand-in 2
# Glittering bits spiral in: emitters in local space under groups that shrink and turn onto points down the line (the
# original's outCubic pull and swirl, keyed), streaks rush in; a point of light (sparkle), a line opening top to bottom
# (rects keyed), the line opening sideways into a white silhouette (fx/arcane/_silhouette.gdshader squeezed off the
# stand-in's own pixels); the stand-in (the effect's Actor) appears flashed with light and cools, an outline crackling
# round it; a flare, a ring rolling out across the floor (ring shader, far half behind), stars, motes and sparks.
extends "res://build/fx/arcane/_arcane.gd"

const LINE := 0.26
const GROW := 0.1
const OPEN := 0.12
const ARRIVE := LINE + GROW + OPEN

var MX := 0.0
var MY := 0.0
var AH := 38.0
var AY := -38.0


func make() -> void:
	ground()
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	AH = tex.get_height()
	AY = -AH
	MY = AY + AH * 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = 12

	# the floor beneath, lit as it gathers and fading after
	var fl := glow("FloorLight", 27, {"radius": 26, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -1), "back": true})
	keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.3 * (t / ARRIVE if t < ARRIVE else 1.0 - seg(t, ARRIVE, ARRIVE + 0.5)), 0.0, ARRIVE + 0.55)
	ring_out(ARRIVE - 0.03)

	# the stand-in: hidden until the silhouette has opened, then flashed with light, cooling
	var body := actor_node()
	key(body, "visible", [[0.0, false], [ARRIVE - 0.002, true]], "nearest")
	body.visible = false
	body.material.set_shader_parameter("flash_color", C[6].lerp(Color.WHITE, 0.5))
	keyf(body, "material:shader_parameter/flash", func(t: float):
		var k := 1.0 - (t - ARRIVE) / 0.42
		return 0.0 if t < ARRIVE or k <= 0.0 else (1.0 if k > 0.86 else minf(1.0, 1.8 * k * k)), ARRIVE - 0.04, ARRIVE + 0.45, 30.0, "nearest")
	var crackle := silhouette("Crackle", 1, C[6], C[6], {"at": Vector2(0, -AH / 2.0)})
	crackle.material.set_shader_parameter("hot", 1.0)
	keyf(crackle, "material:shader_parameter/chance", func(t: float): return 0.85 * (1.0 - (t - ARRIVE) / 0.42), ARRIVE, ARRIVE + 0.42, 30.0, "nearest")
	keyf(crackle, "material:shader_parameter/grain", func(t: float): return floorf(t * 30.0 + 0.001), ARRIVE, ARRIVE + 0.42, 30.0, "nearest")
	keyf(crackle, "material:shader_parameter/hot", func(t: float): return 1.0 if 1.0 - (t - ARRIVE) / 0.42 > 0.5 else 0.0, ARRIVE, ARRIVE + 0.42, 30.0, "nearest")
	show(crackle, ARRIVE, ARRIVE + 0.42)
	var cool := glow("CoolLight", 35, {"radius": 34, "color": C[5], "alpha": 0.6}, {"at": Vector2(MX, MY)})
	keyf(cool, "material:shader_parameter/alpha", func(t: float): return 0.6 * (1.0 - (t - ARRIVE) / 0.42), ARRIVE, ARRIVE + 0.42)
	show(cool, ARRIVE, ARRIVE + 0.42)

	bits(rng)
	# streaks rushing in to the middle while it gathers
	var pts := PackedVector2Array()
	for i in 100:
		var a := rng.randf() * TAU
		var d := rng.randf_range(22, 44)
		pts.append(Vector2(cos(a) * d, minf(-2.0 - MY, sin(a) * d)))
	var rush := particles("Rush", {"at": Vector2(MX, MY), "amount": 14, "lifetime": 0.18, "texture": "streak6", "align": true, "emitting": false,
		"emit": {"points": pts}, "radial": [-1300, -900], "initial": gradient([C[6], C[5]]), "ramp": gradient([C[5], C[6], Color.WHITE], [0.0, 0.5, 0.85])})
	radial_speed(rush, -50, -25)
	life_rand(rush, 0.33)
	emit(rush, 0.0, LINE)

	# a point of light where it gathers
	var point := sparkle("Point", Vector2(MX, MY), 2, C[6], C[5])
	keyf(point, "material:shader_parameter/arm", func(t: float): return 2.0 + 3.0 * seg(t, LINE - 0.04, LINE), LINE - 0.04, LINE, 60.0, "nearest")
	show(point, LINE - 0.04, LINE)
	# it opens into a line, top to bottom
	var line_g := group("Line", {"at": Vector2(MX, MY)})
	show(line_g, LINE, LINE + GROW)
	var hh := func(t: float) -> float: return (AH / 2.0 + 3.0) * out_cubic((t - LINE) / GROW)
	var tips := rect("Tips", Rect2(0, 0, 1, 1), C[6], {"parent": line_g})
	tips.modulate.a = 0.7
	var core := rect("Core", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": line_g})
	var sides := []
	for s in [-1, 1]:
		var sd := rect("Side%d" % (s + 1), Rect2(s, 0, 1, 1), C[5], {"parent": line_g})
		sd.modulate.a = 0.6
		sides.append(sd)
	keyf(tips, "position", func(t: float): return Vector2(0, -floorf(hh.call(t)) - 2), LINE, LINE + GROW, 60.0, "nearest")
	keyf(tips, "size", func(t: float): return Vector2(1, 2 * floorf(hh.call(t)) + 5), LINE, LINE + GROW, 60.0, "nearest")
	keyf(core, "position", func(t: float): return Vector2(0, -ceilf(hh.call(t)) + 1), LINE, LINE + GROW, 60.0, "nearest")
	keyf(core, "size", func(t: float): return Vector2(1, maxf(1.0, 2 * ceilf(hh.call(t)) - 1)), LINE, LINE + GROW, 60.0, "nearest")
	for j in 2:
		var sd: ColorRect = sides[j]
		var sx := -1 if j == 0 else 1
		keyf(sd, "position", func(t: float): return Vector2(sx, -floorf(hh.call(t) * 0.7)), LINE, LINE + GROW, 60.0, "nearest")
		keyf(sd, "size", func(t: float): return Vector2(1, 2 * floorf(hh.call(t) * 0.7) + 1), LINE, LINE + GROW, 60.0, "nearest")
	var ll := glow("LineLight", 31, {"radius": 30, "color": C[5], "alpha": 0.9}, {"at": Vector2(MX, MY)})
	show(ll, LINE, LINE + GROW)
	var lw := glow("LineHot", 9, {"radius": 8, "color": Color.WHITE, "alpha": 0.5}, {"at": Vector2(MX, MY)})
	show(lw, LINE, LINE + GROW)
	# the line opens sideways into the silhouette, white hot; then a white flash of the whole body
	var sil := silhouette("Silhouette", 0, Color.WHITE, C[6])
	keyf(sil, "material:shader_parameter/sx", func(t: float): return out_cubic((t - LINE - GROW) / OPEN) if t < ARRIVE else 1.0, LINE + GROW, ARRIVE + 0.06, 60.0, "nearest")
	show(sil, LINE + GROW, ARRIVE + 0.42 * 0.14)
	var ol := glow("OpenLight", 37, {"radius": 36, "color": C[5], "alpha": 0.8}, {"at": Vector2(MX, MY)})
	show(ol, LINE + GROW, ARRIVE)

	# the arrival: a flare, light, stars and motes thrown out, sparks along the floor
	var fl2 := flare("Flare", Vector2(MX, MY - 4), 20, 1.0)
	keyf(fl2, "material:shader_parameter/len", func(t: float): return 18.0 * pow(1.0 - seg(t, ARRIVE, ARRIVE + 0.2), 1.5) + 2.0, ARRIVE, ARRIVE + 0.2)
	keyf(fl2, "material:shader_parameter/k", func(t: float): return 1.0 - seg(t, ARRIVE, ARRIVE + 0.2), ARRIVE, ARRIVE + 0.2)
	show(fl2, ARRIVE, ARRIVE + 0.2)
	light_burst("Arrive", ARRIVE, Vector2(MX, MY - 6), 56, C[5], 0.9, 0.35)
	light_burst("ArriveHot", ARRIVE, Vector2(MX, MY), 24, Color.WHITE, 0.8, 0.1)
	var cols := gradient([Color.WHITE, C[6], C[6], C[5], C[4]])
	var stars := particles("Stars", {"at": Vector2(MX, MY), "amount": 18, "lifetime": 0.85, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "spread": 180, "speed": [35, 110], "damping": [50, 100], "gravity": Vector2(0, -25), "initial": cols,
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(stars, 0.5)
	emit(stars, ARRIVE)
	var motes := particles("Motes", {"at": Vector2(MX, MY), "amount": 12, "lifetime": 0.85, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "align": true, "spread": 180, "speed": [35, 110], "damping": [20, 50], "gravity": Vector2(0, -25), "initial": cols,
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(motes, 0.5)
	emit(motes, ARRIVE)
	for s in [-1, 1]:
		var sp := particles("Sparks%s" % ("L" if s < 0 else "R"), {"at": Vector2(MX + s * 5, -1), "amount": 6, "lifetime": 0.45, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "streak3", "align": true, "emit": {"box": Vector2(3, 0.5)}, "dir": -90 + s * 60,
			"spread": 25, "speed": [70, 200], "damping": [150, 300], "gravity": Vector2(0, 428), "ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]),
			"collide": {"bounce": 0.45, "friction": 0.3}})
		life_rand(sp, 0.55)
		emit(sp, ARRIVE)


## 230 glittering bits spiralling in to points down the line: each group holds an emitter in its own space and shrinks
## onto its point as the original's bits close in (1 - outCubic), turning as they swirl.
func bits(rng: RandomNumberGenerator) -> void:
	var cols := gradient([Color.WHITE, C[6], C[6], C[5], C[4]])
	var bands := 12
	for i in bands:
		for spin in [-1.0, 1.0]:
			var ty := AY + 3.0 + (AH - 5.0) * (i + 0.5) / bands
			var t1 := LINE + rng.randf_range(-0.02, GROW) * 0.6
			var t0 := 0.0
			var g := group("Bits%d%s" % [i, "L" if spin < 0 else "R"], {"at": Vector2(MX, ty)})
			var pts := PackedVector2Array()
			for k in 60:
				var a := rng.randf() * TAU
				var d := rng.randf_range(16, 46)
				var oy := sin(a) * d * 0.8 - 6.0
				if ty + oy > -2.0:
					oy = -absf(oy) - 2.0
				pts.append(Vector2(cos(a) * d, oy))
			var turn: float = spin * rng.randf_range(0.8, 1.8) * 1.2
			var p := particles("Bits", {"parent": g, "local": true, "amount": 10, "lifetime": t1 - t0 + 0.02, "one_shot": true, "explosiveness": 1.0,
				"texture": "dot1", "emit": {"points": pts}, "initial": cols,
								"alpha_curve": [[0, 0.4], [0.3, 1.0], [1, 1.0]]})
			# the group's shrinking would shrink the bits too: grow them back (1 / r over their life)
			var sc := []
			for j in 21:
				var u := j / 20.0
				sc.append([u, 1.0 / maxf(0.05, 1.0 - out_cubic(u * (t1 - t0 + 0.02) / (t1 - t0)))])
			(p.process_material as ParticleProcessMaterial).scale_curve = curve(sc, 20.0)
			emit(p, 0.0)
			keyf(g, "scale", func(t: float):
				var r := maxf(0.05, 1.0 - out_cubic(seg(t, t0, t1)))
				return Vector2(r, r), t0, t1 + 0.02, 30.0)
			keyf(g, "rotation", func(t: float): return turn * (1.0 - out_cubic(seg(t, t0, t1))), t0, t1, 30.0)
			show(g, 0.0, t1 + 0.02)
			var bl := glow("Light", 4, {"radius": 3, "color": C[6], "alpha": 0.0}, {"parent": g})
			keyf(bl, "material:shader_parameter/alpha", func(t: float): return 0.6 if seg(t, t0, t1) > 0.8 else 0.0, t0, t1, 30.0, "nearest")

