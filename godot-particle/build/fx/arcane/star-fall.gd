# reimagined-from: src/fx/arcane/star-fall.js@cb62831324b95e0ffcbdd2aa718fabe8c5bf0f0e
# Star fall: Stars streak down on long trails across an area, each landing with a white flash, a ring across the floor and a kick of sparks.
# one-shot, 2.50 s, 172 px tall canvas, origin [124.0, 150.0], backdrop ground
# Eleven stars on the original's slanted, accelerating paths (keyed every frame): a head that twinkles (the sparkle or
# flare shader), a tapering trail (lines re-keyed every frame) with light along it, glittering bits shed as it falls
# (an emitter riding the head). Each landing: a white flash and flare, a ring rolling out across the floor (ring
# shader, far half behind and near half in front), sparks that bounce off the floor and kicked-up stars (one-shot
# emitters), a cooling mark and a burst of light.
extends "res://build/fx/arcane/_arcane.gd"

const N := 11
const SPREAD := 46.0
const H := 124.0
const SLANT := 0.38
const TRAIL := 0.17

var stars := []


func make() -> void:
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var xs := []
	for i in N:
		xs.append(-SPREAD + (i + rng.randf_range(0.2, 0.8)) * 2.0 * SPREAD / N)
	for i in range(N - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: float = xs[i]
		xs[i] = xs[j]
		xs[j] = tmp
	for i in N:
		var x: float = xs[i]
		var y := rng.randf_range(-3, 2)
		var h := H * rng.randf_range(0.85, 1.0)
		stars.append({"x": x, "y": y, "sx": x - h * SLANT, "sy": y - h, "t0": 0.04 + i * 0.105 + rng.randf_range(0, 0.05),
			"T": rng.randf_range(0.3, 0.4), "big": rng.randf() < 0.35, "ph": rng.randf_range(0, TAU)})

	# the area lit beneath while they fall
	for x in [-36, 0, 36]:
		var a := glow("Area%d" % (x + 36), 41, {"radius": 40, "color": C[4], "alpha": 0.0}, {"at": Vector2(x, -1)})
		keyf(a, "material:shader_parameter/alpha", func(t: float): return 0.14 * seg(t, 0.0, 0.3) * (1.0 - seg(t, 1.7, 2.4)))

	for i in N:
		star(i, stars[i], rng)


func at(s: Dictionary, tt: float) -> Vector2:
	var q := clampf((tt - s.t0) / s.T, 0.0, 1.0)
	var e := q * (0.35 + 0.65 * q)
	return Vector2(s.sx + (s.x - s.sx) * e, s.sy + (s.y - s.sy) * e)


func trail_points(s: Dictionary, t: float, upto: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 21:
		var u := k / 20.0
		if u > upto + 1e-4:
			break
		var tk := t - k * TRAIL / 20.0
		if k > 0 and tk < s.t0:
			break
		out.append(at(s, tk) + Vector2(0.5, 0.5))
	if out.size() < 2:
		out.append(out[0] + Vector2(0, -0.01))
	return out


func star(i: int, s: Dictionary, rng: RandomNumberGenerator) -> void:
	var g := group("Star%d" % i)
	var t0: float = s.t0
	var land: float = s.t0 + s.T
	var big: bool = s.big
	var land_at := Vector2(s.x, s.y)

	# the trail: a long tapered streak back up its path, white at the head thinning into violet, a second line
	# beside it near the head for body, light along it
	var tr := line("Trail", PackedVector2Array([Vector2.ZERO, Vector2(0, -1)]), {"parent": g,
		"gradient": gradient([Color.WHITE, C[6], Color(C[5], 0.85), Color(C[4], 0.6), Color(C[4], 0.4)], [0.0, 0.15, 0.4, 0.7, 0.85])})
	keyf(tr, "points", func(t: float): return trail_points(s, t, 1.0), t0, land, 30.0, "nearest")
	show(tr, t0, land)
	var body_len := 0.55 if big else 0.35
	var bd := line("Body", PackedVector2Array([Vector2.ZERO, Vector2(0, -1)]), {"parent": g, "at": Vector2(1, 0),
		"gradient": gradient([C[6], C[5], Color(C[5], 0.6)], [0.0, 0.2 / body_len, 0.6])})
	keyf(bd, "points", func(t: float): return trail_points(s, t, body_len), t0, land, 30.0, "nearest")
	show(bd, t0, land)
	var tl := glow_path("TrailLight", Vector2(minf(s.sx, s.x), s.sy), Vector2(maxf(s.sx, s.x), s.y), 7, C[5], 0.3, 3.0 * TRAIL / 20.0 * 330.0, {"parent": g})
	tl.material.set_shader_parameter("k_end", 0.0)
	keyf(tl, "material:shader_parameter/a", func(t: float): return at(s, t), t0, land, 30.0, "nearest")
	keyf(tl, "material:shader_parameter/b", func(t: float): return at(s, maxf(t0, t - TRAIL)), t0, land, 30.0, "nearest")
	show(tl, t0, land)

	# the head: a twinkling star, a white heart, light
	var head := group("Head", {"parent": g, "at": at(s, t0)})
	keyf(head, "position", func(t: float): return at(s, t).floor(), t0, land, 30.0, "nearest")
	show(head, t0, land)
	var tw: ColorRect
	if big:
		tw = flare("Twinkle", Vector2.ZERO, 7, 0.8, {"parent": head})
		keyf(tw, "material:shader_parameter/len", func(t: float): return 7 + 1.5 * sin(t * 40 + s.ph), t0, land, 30.0, "nearest")
	else:
		tw = sparkle("Twinkle", Vector2.ZERO, 3.5, C[6], C[5], {"parent": head})
		keyf(tw, "material:shader_parameter/arm", func(t: float): return 3.5 + sin(t * 40 + s.ph), t0, land, 30.0, "nearest")
	ring("Heart", 3, {"radius": 1.6 if big else 1.1, "color": Color.WHITE}, {"parent": head, "at": Vector2(0.5, 0.5)})
	glow("HeadLight", 19, {"radius": 18 if big else 13, "color": C[5], "alpha": 0.6}, {"parent": head, "at": Vector2(0.5, 0.5)})
	glow("HeadHot", 6, {"radius": 5, "color": Color.WHITE, "alpha": 0.35}, {"parent": head, "at": Vector2(0.5, 0.5)})

	# glittering bits shed as it falls: single twinkling pixels and a few tiny crosses
	var shed := particles("Shed", {"parent": g, "at": at(s, t0), "amount": 28, "lifetime": 0.7, "texture": "dot1", "emitting": false,
		"emit": {"box": Vector2(1.5, 1.5)}, "spread": 180, "speed": [3, 12], "damping": [6, 10], "gravity": Vector2(0, -5),
		"initial": gradient([Color.WHITE, C[6], C[5]]), "alpha_curve": [[0, 1], [0.5, 0.8], [0.8, 0.6], [1, 0]]})
	life_rand(shed, 0.5)
	var shed2 := particles("ShedStars", {"parent": g, "at": at(s, t0), "amount": 5, "lifetime": 0.7, "texture": "plus3", "emitting": false,
		"emit": {"box": Vector2(1.5, 1.5)}, "spread": 180, "speed": [3, 12], "damping": [6, 10], "gravity": Vector2(0, -5),
		"initial": gradient([Color.WHITE, C[6], C[5]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(shed2, 0.5)
	for e in [shed, shed2]:
		keyf(e, "position", func(t: float): return at(s, t), t0, land, 30.0)
		emit(e, t0, land)

	# the landing
	var hit := group("Hit", {"parent": g, "at": land_at})
	# the ring rolling out across the floor: white rim, violet inside; far half behind, near half in front
	for half in [[1.0, true, "RingBack"], [-1.0, false, "RingFront"]]:
		var reach := 3.0 + (22.0 if big else 16.0)
		for layer in [["Rim", Color.WHITE, 0.0], ["Band", C[6], 1.0]]:
			var rr := ring(half[2] + layer[0], reach + 2, {"radius": 3, "thickness": 1, "squash": 0.26, "color": layer[1], "side": half[0]},
				{"parent": hit, "back": half[1]})
			var inset: float = layer[2]
			keyf(rr, "material:shader_parameter/radius", func(t: float): return 3.0 + (reach - 3.0) * out_cubic((t - land) / 0.45) - inset, land, land + 0.45)
			keyf(rr, "material:shader_parameter/thickness", func(t: float):
				var th := maxf(1.0, 2.5 * (1.0 - (t - land) / 0.45))
				return 1.0 if inset == 0.0 else maxf(0.6, th - 1.0), land, land + 0.45)
			keyf(rr, "material:shader_parameter/alpha", func(t: float): return clampf(1.15 - (t - land) / 0.45, 0.0, 1.0) * 1.2, land, land + 0.45)
			show(rr, land, land + 0.45)
	# a white flash and a flare
	var flash := ring("Flash", 7, {"radius": 6, "color": Color.WHITE}, {"parent": hit, "at": Vector2(0.5, -1.5)})
	keyf(flash, "material:shader_parameter/radius", func(t: float): return 5.0 * (1.0 - (t - land) / 0.22 / 0.35) + 1.0, land, land + 0.077)
	show(flash, land, land + 0.077)
	var fl := flare("Flare", Vector2(0, -2), 14, 1.0, {"parent": hit})
	keyf(fl, "material:shader_parameter/len", func(t: float): return (16.0 if big else 12.0) * pow(1.0 - seg(t, land, land + 0.22), 1.5) + 2.0, land, land + 0.22)
	keyf(fl, "material:shader_parameter/k", func(t: float): return 1.0 - seg(t, land, land + 0.22), land, land + 0.22)
	show(fl, land, land + 0.22)
	# the mark where it landed, cooling away
	var mark := group("Mark", {"parent": hit, "back": true})
	var mc := rect("Core", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": mark, "back": true})
	key(mc, "color", [[0.0, Color.WHITE], [land + 0.28, C[6]]], "nearest")
	var ms := []
	for dx in [-1, 1]:
		ms.append(rect("Side%d" % (dx + 1), Rect2(dx, 0, 1, 1), C[5], {"parent": mark, "back": true}))
	keyf(mark, "modulate:a", func(t: float): return clampf((1.0 - (t - land) / 0.7) * 1.5, 0.0, 1.0), land, land + 0.7)
	show(mark, land, land + 0.7)
	var ml := glow("MarkLight", 11, {"radius": 10, "color": C[5], "alpha": 0.35}, {"parent": hit, "at": Vector2(0, -1)})
	keyf(ml, "material:shader_parameter/alpha", func(t: float): return 0.35 * maxf(0.0, 1.0 - (t - land) / 0.7), land, land + 0.7)
	show(ml, land, land + 0.7)
	# light bursting off it
	var R0 := 46.0 if big else 38.0
	var burst := glow("Burst", R0 + 1, {"radius": R0, "color": C[5], "alpha": 0.9}, {"parent": hit, "at": Vector2(0, -12)})
	keyf(burst, "material:shader_parameter/radius", func(t: float): return R0 * (0.55 + 0.45 * (1.0 - seg(t, land, land + 0.32))), land, land + 0.32)
	keyf(burst, "material:shader_parameter/alpha", func(t: float): return 0.9 * pow(1.0 - seg(t, land, land + 0.32), 2.0), land, land + 0.32)
	show(burst, land, land + 0.32)
	var hot := glow("BurstHot", 17, {"radius": 16, "color": Color.WHITE, "alpha": 0.8}, {"parent": hit, "at": Vector2(0, -3)})
	keyf(hot, "material:shader_parameter/alpha", func(t: float): return 0.8 * pow(1.0 - seg(t, land, land + 0.08), 2.0), land, land + 0.08)
	show(hot, land, land + 0.08)
	# sparks that bounce off the floor, stars kicked up
	var sparks := particles("Sparks", {"parent": hit, "at": Vector2(0, minf(-1.0, s.y - 1.0) - s.y), "amount": 14 if big else 9,
		"lifetime": 0.5, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "streak3", "align": true, "dir": -90,
		"spread": 77, "speed": [50, 150], "damping": [80, 160], "gravity": Vector2(0, 428),
		"ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
	life_rand(sparks, 0.6)
	emit(sparks, land)
	var kick := particles("Kick", {"parent": hit, "at": Vector2(0, -5), "amount": 4, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "plus3", "emit": {"box": Vector2(4, 3)}, "dir": -90, "spread": 30, "speed": [12, 38], "damping": [15, 25],
		"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(kick, 0.5)
	emit(kick, land)
