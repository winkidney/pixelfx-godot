# reimagined-from: src/fx/explosions/cartoon-pow.js@69d44c838179847dea45c527d62156cbc682fcbd
# Cartoon POW: a comic-book hit: a jagged two-tone burst star slams in with a shake and boiling edges, POW! drops in
# letter by letter, action lines fly, then it all snaps away.
# The star is a shader of its own (_burst.gdshader: the original's spike profile, ink edge, halftone, heart and
# core) whose size, turn, shake and boil are keyed from the original's slam / settle / snap curve; the word is four
# PixelText letters (an ink edge, a deep red extrusion, a white face going warm) dropping in on the original's
# outBack; action lines are Line2Ds keyed every frame, the impact ring the ring shader; sparks burst at the slam,
# little stars at the snap, a glint flashes at the star's shoulder.
extends "res://addons/pixelfx_particles/core/build.gd"

const PFont := preload("res://addons/pixelfx_particles/core/pixel_font.gd")

const N := 14
const IN := 0.05
const GO := 0.66
const END := 0.8
const SC := 3.0


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func in_back(x: float, s: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else (s + 1.0) * x * x * x - s * x * x)


static func out_back(x: float, s: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0))


static func size_at(t: float) -> float:
	if t < IN:
		return 0.25 + 0.95 * out_cubic(clampf(t / IN, 0.0, 1.0))
	if t < GO:
		return 1.0 + 0.18 * exp(-(t - IN) * 18.0) * cos((t - IN) * 40.0)
	return 1.0 - in_back(clampf((t - GO) / (END - GO), 0.0, 1.0), 2.0)


static func shake_at(t: float) -> Vector2:
	var k := (1.0 - t / 0.3) * 2.2 if t < 0.3 else 0.0
	return Vector2(roundf(sin(t * 97.0) * k), roundf(cos(t * 83.0) * k))


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var INK := C[0]
	var D: float = meta.duration
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sp := PackedFloat32Array()
	for i in N * 2:
		sp.append(rng.randf_range(0.5, 0.6) if i % 2 else rng.randf_range(0.85, 1.05))
	var frames := int(ceil(D * 60.0))

	# the warm light round it
	var shine := glow("Shine", 80, {"radius": 65, "color": C[5], "alpha": 0.3})
	# the burst star
	var star := shape("Star", load("res://addons/pixelfx_particles/fx/explosions/_burst.gdshader"), Vector2(150, 130),
		{"spikes": sp, "ink": INK, "heart": C[3], "body": C[4], "light": C[5], "outer": 12.5})
	var outer := []
	var rots := []
	var shakes := []
	var boils := []
	var sh_r := []
	var sh_a := []
	var sh_p := []
	for i in frames + 1:
		var t := i / 60.0
		var s := size_at(t)
		outer.append([t, 50.0 * s if s > 0.02 else 0.0])
		rots.append([t, -0.1 + ((t - GO) * 3.0 if t > GO else 0.0)])
		shakes.append([t, shake_at(t)])
		boils.append([t, floorf(t * 12.0)])
		sh_r.append([t, maxf(1.0, 65.0 * s)])
		sh_a.append([t, 0.3 * minf(1.0, maxf(0.0, s)) if s > 0.02 else 0.0])
		sh_p.append([t, shake_at(t)])
	key(star, "material:shader_parameter/outer", outer)
	key(star, "material:shader_parameter/rot", rots)
	key(star, "material:shader_parameter/shake", shakes, "nearest")
	key(star, "material:shader_parameter/boil", boils, "nearest")
	key(shine, "material:shader_parameter/radius", sh_r)
	key(shine, "material:shader_parameter/alpha", sh_a)
	key(shine, "position", sh_p, "nearest")

	# action lines flying out, and a ring of impact
	var lg := gradient([Color.WHITE, C[5]], [0.0, 0.5])
	for i in 16:
		var a := ((i + rng.randf_range(0.2, 0.8)) / 16.0) * TAU
		var rr := rng.randf_range(0.92, 1.08)
		var L := rng.randf_range(10, 17)
		var t0 := rng.randf_range(0, 0.06)
		var ln := line("Action%d" % i, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"width": 1, "gradient": lg})
		var pts := []
		var on := IN + t0
		for k in 21:
			var t := on + k * 0.32 / 20.0
			var u := (t - on) / 0.32
			var r0 := (46.0 + 22.0 * out_cubic(u)) * rr
			var l := L * 0.7 * (1.0 - u)
			var dv := Vector2(cos(a), sin(a) * 0.82)
			pts.append([t, PackedVector2Array([dv * r0, dv * (r0 + maxf(l, 0.6))])])
		key(ln, "points", pts)
		show(ln, on, on + 0.32)
	var ring_n := ring("Impact", 66, {"radius": 30, "thickness": 2.5, "color": Color.WHITE})
	var rk := []
	var tk := []
	var ak := []
	for k in 16:
		var t := IN + k * 0.24 / 15.0
		var ru := (t - IN) / 0.24
		rk.append([t, 30.0 + 34.0 * out_cubic(ru)])
		tk.append([t, maxf(1.0, 2.5 * (1.0 - ru))])
		ak.append([t, minf(1.0, 1.1 - ru)])
	key(ring_n, "material:shader_parameter/radius", rk)
	key(ring_n, "material:shader_parameter/thickness", tk)
	key(ring_n, "material:shader_parameter/alpha", ak)
	key(ring_n, "material:shader_parameter/color", [[0.0, Color.WHITE], [IN + 0.4 * 0.24, C[5]]], "nearest")
	show(ring_n, IN, IN + 0.24)

	# the word: letters dropping in one after another, inked, with a deep red extrusion, a white face going warm
	var word := String(meta.options.text)
	var widths := []
	var total := -SC
	for ch in word:
		var w := PFont.textWidth(ch, "big") * SC
		widths.append(w)
		total += w + SC
	var x := -total / 2.0
	var face := [C[4], C[5], C[5], C[6], C[6], C[6], C[6]]
	for i in word.length():
		var ch := word[i]
		var w: float = widths[i]
		var g := group("Letter%d" % i)
		var anchor := Vector2(ceilf(w / 2.0), 7.0 * SC)
		for d in [4, 3, 2, 1]:
			var o := {"font": "big", "sx": SC, "sy": SC, "fill": [INK if d >= 3 else C[1]], "at": anchor + Vector2(d, d), "parent": g}
			if d == 4:
				o.outline = INK
			text("Ext%d" % d, ch, o)
		var offs := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
		for j in offs.size():
			var off: Vector2 = offs[j]
			text("Ink%d" % j, ch, {"font": "big", "sx": SC, "sy": SC, "fill": [INK], "outline": INK, "at": anchor + off, "parent": g})
		text("Face", ch, {"font": "big", "sx": SC, "sy": SC, "fill": face, "at": anchor, "parent": g})
		var pos := []
		var al := []
		var on := IN + 0.04 + i * 0.05
		var off_t := GO + (END - GO - 0.04)
		for k in frames + 1:
			var t := k / 60.0
			var u := (t - on) / 0.12
			var away := clampf((t - GO) / (END - GO - 0.04), 0.0, 1.0)
			var drop := (1.0 - out_back(clampf(u, 0.0, 1.0), 2.4)) * -14.0
			var sh := shake_at(t)
			pos.append([t, Vector2(roundf(x + sh.x), roundf(-11.0 + drop - i * 1.5 + sh.y + away * 6.0))])
			al.append([t, 1.0 - away])
		key(g, "position", pos, "nearest")
		key(g, "modulate:a", al)
		show(g, on + 0.001, off_t)
		x += w + SC

	# sparks at the slam, little stars as it snaps away: flung straight out from round the star
	var sparks := particles("Sparks", {"amount": 22, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0, "randomness": 0.6,
		"emitting": false, "texture": "streak6", "align": true, "speed": [180, 360], "drag": 2.2, "gravity": Vector2(0, 430),
		"ramp": gradient([C[6], C[5], C[4], C[3]], [0.0, 0.4, 0.7, 0.85])})
	directed(sparks, Vector2(14, 10))
	emit(sparks, IN)
	var tw := [[0, 1], [0.8, 1], [1, 0]]
	for k in 2:
		var stars := particles("Stars%d" % k, {"amount": 7, "lifetime": 0.42, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
			"emitting": false, "texture": ["plus3", "spark5"][k], "speed": [60, 150], "drag": 1.6,
			"initial": gradient([C[6], C[5], C[4]]), "alpha_curve": tw})
		directed(stars, Vector2(26, 18))
		emit(stars, GO)
		# each star's light: the same particles (same material and seed) drawn as a soft glow on the light layer
		var lit := particles("StarLight%d" % k, {"layer": "light", "amount": 7, "lifetime": 0.42, "one_shot": true, "explosiveness": 1.0,
			"randomness": 0.4, "emitting": false, "texture": "glow16", "modulate": Color(1, 1, 1, 0.2)})
		lit.process_material = stars.process_material
		lit.seed = stars.seed
		emit(lit, GO)
	# a glint on the star's shoulder as it lands
	var glint := sprite("Glint", "star5", {"at": Vector2(34, -22), "modulate": Color.WHITE})
	show(glint, IN, IN + 0.12)
	key(glint, "scale", [[IN, Vector2(2.4, 2.4)], [IN + 0.12, Vector2(0.4, 0.4)]])
	var glint_light := glow("GlintLight", 18, {"radius": 16, "color": C[6], "alpha": 0.6}, {"at": Vector2(34, -22)})
	key(glint_light, "material:shader_parameter/alpha", [[0.0, 0.0], [IN, 0.6], [IN + 0.12, 0.0]])


## Burst particles flung straight out from an ellipse (rx, ry) round the origin: directed emission points whose
## normals point away from the middle.
func directed(p: GPUParticles2D, r: Vector2, n := 48) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in n:
		var a := i / float(n) * TAU
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
		nor.append(Vector2(cos(a), sin(a)))
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(pts)
	m.emission_normal_texture = _points_texture(nor)
	m.emission_point_count = n
	m.direction = Vector3(1, 0, 0)
	m.spread = 0.0
