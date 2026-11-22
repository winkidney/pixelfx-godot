# reimagined-from: src/fx/nature/earth-spike.js@a7db3009fc362158c31ec6c73c2cf4e7d183f887
# Earth spike: The floor cracks with light and heaves, a faceted stone spike rams up with two side shards in a burst of
# chips, grit and dust; rubble rains, then it splits and crumbles.
# The spikes are a shader of their own (fx/nature/_spike.gdshader, the original's faceted spike: ridge, strata,
# notches, cracks that glow and cool, a white flash, a sweeping glint; split into halves that part, tip out, crumble
# from the top and sink), its uniforms keyed frame by frame from the original's curves; the heaving mound is another
# small shader. The floor cracks are Line2Ds growing out with their heat; the shoved-up slabs are faceted stones
# drawn the way the original draws them (build-time textures). Chips, grit, sparks, dust skirts, rising dust, rubble
# rain, the crumbling rubble and the stump's dust are emitters on the original's beats over a collision floor; the
# light is glows and soft lines on the light layer.
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const E := preload("res://build/fx/nature/_lib_earth.gd")
const UP := 0.34
const RISE := 0.09
const CRACK := 1.18
const SPLIT := 1.5
const PART := 0.1
const FALL := 0.42
const SINK := 0.55

var S: PackedColorArray
var GL: PackedColorArray
var H := 62.0
var dust: Color
var dust2: Color
var rng := RandomNumberGenerator.new()


static func out_back(x: float, s: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


## keys at the original's frames (30 a second) of fn(t), held (nearest), only where the value changes
func frames_key(node: Node, prop: String, fn: Callable, t0 := 0.0, t1 := -1.0) -> void:
	var keys := []
	var last: Variant = null
	var n := int(roundf((meta.duration if t1 < 0.0 else t1) * 30.0))
	if t0 > 0.0:
		# a held track applies nothing before its first key: start it at 0
		last = fn.call(t0)
		keys.append([0.0, last])
	for i in range(int(t0 * 30.0), n + 1):
		var t := i / 30.0
		var v: Variant = fn.call(t)
		if last == null or v != last:
			keys.append([t, v])
			last = v
	key(node, prop, keys, "nearest")


## one of the original's Lights: radius r * (0.55 + 0.45 q), strength k q^2 over its life
func light_at(name: String, at: Vector2, r: float, c: Color, k: float, t0: float, life: float) -> void:
	var g := glow(name, r + 2, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	var al := [[0.0, 0.0], [maxf(0.0, t0 - 0.001), 0.0]]
	var rad := []
	for i in 7:
		var q := 1.0 - i / 6.0
		al.append([t0 + life * i / 6.0, k * q * q])
		rad.append([t0 + life * i / 6.0, r * (0.55 + 0.45 * q)])
	key(g, "material:shader_parameter/alpha", al)
	key(g, "material:shader_parameter/radius", rad)


func burst(name: String, at: Vector2, t0: float, o: Dictionary) -> GPUParticles2D:
	var oo := {"at": at, "one_shot": true, "explosiveness": 1.0, "emitting": false}
	oo.merge(o, true)
	var p := particles(name, oo)
	if o.has("life_random"):
		p.process_material.lifetime_randomness = o.life_random
	emit(p, t0)
	return p


func make() -> void:
	ground()
	S = root.ramps.palette
	GL = root.ramps.glow
	H = meta.options.height
	rng.seed = 5
	dust = S[6].lerp(Color("#8c8494"), 0.45)
	dust2 = S[5].lerp(Color("#6c6474"), 0.4)
	keep_colour(Color.WHITE)
	var spikes := [
		{"name": "Left", "x": -H * 0.17, "H": H * 0.52, "w": H * 0.22, "lean": -H * rng.randf_range(0.13, 0.18), "at": UP + 0.045, "split": SPLIT - 0.1, "back": true, "main": false},
		{"name": "Right", "x": H * 0.18, "H": H * 0.4, "w": H * 0.2, "lean": H * rng.randf_range(0.11, 0.15), "at": UP + 0.085, "split": SPLIT + 0.08, "back": false, "main": false},
		{"name": "Spike", "x": 0.0, "H": H, "w": H * 0.36, "lean": rng.randf_range(-2, 2), "at": UP, "split": SPLIT, "back": false, "main": true},
	]
	for s in spikes:
		s.look = E.spike_look(rng)
		s.cracks = [E.spike_crack(rng, rng.randf_range(0.04, 0.16), rng.randf_range(-0.6, -0.1), 1),
			E.spike_crack(rng, rng.randf_range(0.22, 0.4), rng.randf_range(0.1, 0.6), -1),
			E.spike_crack(rng, rng.randf_range(0.42, 0.58), rng.randf_range(-0.4, 0.4), -1.0 if rng.randf() < 0.5 else 1.0)]
		s.cut = rng.randf_range(0.24, 0.32)
	var cracks := [E.floor_crack(rng, -1, rng.randf_range(34, 44)), E.floor_crack(rng, 1, rng.randf_range(34, 44)),
		E.floor_crack(rng, -1, rng.randf_range(14, 20)), E.floor_crack(rng, 1, rng.randf_range(14, 20))]
	var D: float = meta.duration
	var heat := func(t: float) -> float: return N.smooth(0, UP, t) if t < UP else 1.0 - N.smooth(UP, UP + 0.9, t)
	var opened := func(t: float) -> float: return N.out_cubic((t - 0.02) / 0.24)

	# the floor splits open: glowing seams that cool to dark scars and fade
	var fade := [[0.0, 1.0], [D - 1.1, 1.0], [D - 0.3, 0.0]]
	var ci := 0
	for c in cracks:
		var pts := PackedVector2Array()
		for q in c:
			pts.append(q + Vector2(0.5, 0.5))
		var dark := line("CrackShadow%d" % ci, pts, {"color": S[0], "back": true, "at": Vector2(0, 1)})
		var seam := line("Crack%d" % ci, pts, {"color": GL[4], "back": true})
		for l in [dark, seam]:
			frames_key(l, "points", func(t: float) -> PackedVector2Array: return pts.slice(0, maxi(2, ceili(pts.size() * opened.call(t)))), 0.0, 0.4)
			key(l, "modulate:a", fade)
		var seam_col := func(t: float) -> Color:
			var hk: float = heat.call(t)
			return GL[4] if hk > 0.65 else GL[3] if hk > 0.35 else GL[2] if hk > 0.12 else GL[1] if hk > 0.03 else S[1]
		frames_key(seam, "default_color", seam_col, 0.0, 1.4)
		for k in range(2, c.size(), 2):
			var g := glow("CrackLight%d_%d" % [ci, k], 8, {"radius": 6, "color": GL[2], "alpha": 0.0}, {"at": c[k] + Vector2(0.5, 0.5)})
			var idx := k
			var ga := func(t: float) -> float: return 0.3 * heat.call(t) if idx < ceili(pts.size() * opened.call(t)) else 0.0
			frames_key(g, "material:shader_parameter/alpha", ga, 0.0, 1.4)
		ci += 1
	var core := glow("HeatLight", 28, {"radius": 26, "color": GL[2], "alpha": 0.0}, {"at": Vector2(0, -3)})
	frames_key(core, "material:shader_parameter/alpha", func(t: float) -> float: return 0.35 * heat.call(t), 0.0, 1.4)

	# back layer: the back shard behind the rest
	_spike_node(spikes[0])

	# the floor heaving into a trembling mound before it breaks
	var mound := shape("Mound", load("res://addons/pixelfx_particles/fx/nature/_spike_mound.gdshader"), Vector2(36, 14),
		{"stone": ramp("palette", {"stops": 8})}, {"at": Vector2(0, -5)})
	frames_key(mound, "material:shader_parameter/hm", func(t: float) -> float: return 8.0 * N.smooth(0.06, UP, t) if t < UP + 0.02 else 0.0, 0.0, 0.5)
	frames_key(mound, "material:shader_parameter/jx", func(t: float) -> float: return sin(t * 95.0) * 0.8 * N.smooth(0.06, UP, t), 0.0, 0.5)
	show(mound, 0.0, UP + 0.02)

	# slabs of floor shoved up round the base, sinking back as the spike crumbles
	for sd in [-1, 1]:
		var x: float = sd * rng.randf_range(13, 16)
		var pts := [[-1.2, -0.32], [1.1, -0.42], [1.2, 0.36], [-1.1, 0.4]]
		var sz := rng.randf_range(5.5, 7)
		var a: float = sd * rng.randf_range(0.45, 0.65)
		var slab := sprite("Slab%s" % ("L" if sd < 0 else "R"), E.rock_from(pts, sz, a, S), {"at": Vector2(x, -1.5)})
		var flash := sprite("SlabFlash%s" % ("L" if sd < 0 else "R"), E.rock_from(pts, sz, a, S, true), {"parent": slab})
		flash.z_index = 0
		show(flash, 0.0, UP + 0.04)
		show(slab, UP)
		var sc := []
		for i in 9:
			var t := UP + i / 60.0
			var g := out_back(clampf((t - UP) / 0.1, 0.0, 1.0), 2.0)
			sc.append([t, Vector2(g, g)])
		key(slab, "scale", sc)
		var sink := []
		for i in 9:
			var t := SPLIT + FALL + SINK * i / 8.0
			var k := N.smooth(SPLIT + FALL, SPLIT + FALL + SINK, t)
			sink.append([t, Vector2(x, -1.5 + roundf(k * 7.0))])
		key(slab, "position", sink, "nearest")
		key(slab, "modulate:a", [[0.0, 1.0], [SPLIT + FALL, 1.0], [SPLIT + FALL + SINK, 0.0]])

	_spike_node(spikes[1])
	_spike_node(spikes[2])
	var m: Dictionary = spikes[2]
	# light leaking out of the cracks as it's about to split
	var leak := glow("LeakLight", 20, {"radius": 20, "squash": (H * 0.6 - 4.0 + 40.0) / 40.0, "color": GL[2], "alpha": 0.0},
		{"at": Vector2(roundf(m.lean * 0.3), -roundf(H * 0.3 + 2.0))})
	frames_key(leak, "material:shader_parameter/alpha", func(t: float) -> float: return 0.22 * N.smooth(CRACK, SPLIT, t) * (1.0 - N.smooth(SPLIT, SPLIT + 0.5, t)), 1.0, 2.1)

	for s in spikes:
		_erupt(s)
		_crumble(s)

	# the hero frame: a sparkle where the tip breaks through, light running up the spike
	var star := gradient([GL[3], S[7], S[7], GL[3]], [0.0, 0.2, 0.8, 1.0])
	var hl := line("HeroH", PackedVector2Array([Vector2.ZERO, Vector2.ONE]), {"gradient": star})
	var vl := line("HeroV", PackedVector2Array([Vector2.ZERO, Vector2.ONE]), {"gradient": star})
	var hero_light := glow("HeroLight", 10, {"radius": 10, "squash": (H * 1.3 + 20.0) / 20.0, "color": GL[3], "alpha": 0.0})
	var tip_light := glow("TipLight", 26, {"radius": 24, "color": S[7], "alpha": 0.0})
	var hp := []
	var vp := []
	var la := [[0.0, 0.0], [UP - 0.001, 0.0]]
	var lp := []
	var sq := []
	var tp := []
	var ta := [[0.0, 0.0], [UP - 0.001, 0.0]]
	for i in range(int(ceilf(UP * 30.0)), int(ceilf((UP + 0.2) * 30.0)) + 1):
		var t := i / 30.0
		var e := t - UP
		var g := out_back(clampf(e / RISE, 0.0, 1.0), 2.2)
		var tipp := Vector2(floorf(m.lean) + 0.5, floorf(-H * g) + 0.5)
		var arm := roundf(10.0 * (1.0 - e / 0.2))
		hp.append([t, PackedVector2Array([tipp - Vector2(arm, 0), tipp + Vector2(arm + 1, 0)])])
		vp.append([t, PackedVector2Array([tipp - Vector2(0, arm), tipp + Vector2(0, arm + 1)])])
		la.append([t, maxf(0.0, 0.3 * (1.0 - e / 0.2))])
		lp.append([t, Vector2(m.lean * 0.5, -H * g * 0.5)])
		sq.append([t, (H * g + 20.0) / 20.0])
		tp.append([t, tipp])
		ta.append([t, maxf(0.0, 0.5 * (1.0 - e / 0.2))])
	key(hl, "points", hp, "nearest")
	key(vl, "points", vp, "nearest")
	key(hero_light, "position", lp, "nearest")
	key(hero_light, "material:shader_parameter/squash", sq, "nearest")
	key(hero_light, "material:shader_parameter/alpha", la)
	key(tip_light, "position", tp, "nearest")
	key(tip_light, "material:shader_parameter/alpha", ta)
	for n in [hl, vl]:
		show(n, UP, UP + 0.2)

	# stones that land hard kick up a little dust along the floor
	var settle := particles("Settle", {"layer": "soft", "at": Vector2(0, -1), "amount": 14, "lifetime": 0.5, "emitting": false,
		"texture": "disc5", "emit": {"box": Vector2(80, 0.5)}, "dir": -90, "spread": 80, "speed": [8, 35], "damping": [30, 60],
		"scale_curve": [[0, 0.5], [1, 1.1]], "ramp": gradient([Color(dust2, 0.6), Color(dust2, 0.4), Color(dust2, 0.2)])})
	emit(settle, 0.6, 1.7)


## a spike: the shader, its uniforms keyed frame by frame
func _spike_node(s: Dictionary) -> void:
	var tipmax: float = 0.12 * s.H
	var x0: float = s.x - s.w / 2.0 - absf(s.lean) - tipmax - 5.0
	var x1: float = s.x + s.w / 2.0 + absf(s.lean) + tipmax + 5.0
	var y0: float = -s.H * 1.3 - 4.0
	var y1 := 3.0
	var c := Vector2(roundf((x0 + x1) / 2.0), roundf((y0 + y1) / 2.0))
	var sz := Vector2(ceilf((x1 - x0) / 2.0) * 2.0, ceilf((y1 - y0) / 2.0) * 2.0)
	var params := E.spike_params(s.look, s.cracks)
	params.notches = PackedVector3Array(params.notches)
	params.merge({"stone": ramp("palette", {"stops": 8}), "glow_ramp": ramp("glow", {"stops": 5}), "x0": s.x, "h": 0.0,
		"w": s.w, "lean": s.lean, "white": 0.0, "glint": -1.0, "clip": 1.0, "split": 0.0, "gap": 0.0, "tip": 0.0, "sink": 0.0,
		"crack": 0.0, "heat": 0.0}, true)
	var node := shape(s.name, load("res://addons/pixelfx_particles/fx/nature/_spike.gdshader"), sz, params, {"at": c, "back": s.back})
	var at: float = s.at
	var sp: float = s.split
	var main: bool = s.main
	var HH: float = s.H
	var cut: float = s.cut
	var grown := func(t: float) -> float: return 0.0 if t < at else out_back(clampf((t - at) / RISE, 0.0, 1.0), 2.2)
	var u := "material:shader_parameter/"
	frames_key(node, u + "h", func(t: float) -> float: return HH * grown.call(t) if t < sp else HH)
	frames_key(node, u + "lean", func(t: float) -> float: return s.lean * minf(1.0, grown.call(t)) if t < sp else s.lean)
	frames_key(node, u + "white", func(t: float) -> float: return 1.0 if t < sp and t >= at and (t - at < 0.04 or t > sp - 0.045) else 0.0)
	var glint := func(t: float) -> float:
		var sw := (t - at) * 0.9 - 0.15
		return fmod(sw, 1.2) / 0.55 if (t < sp and sw > 0.0 and fmod(sw, 1.2) < 0.55) else -1.0
	frames_key(node, u + "glint", glint)
	frames_key(node, u + "crack", func(t: float) -> float: return N.smooth(CRACK + (0.0 if main else 0.05), sp - 0.03, t) if t < sp else 1.0)
	frames_key(node, u + "heat", func(t: float) -> float: return N.smooth(CRACK, sp, t) if t < sp else 1.0 - N.smooth(sp, sp + 0.45, t))
	frames_key(node, u + "split", func(t: float) -> float: return 1.0 if t >= sp else 0.0)
	frames_key(node, u + "gap", func(t: float) -> float: return N.smooth(sp, sp + PART, t) * (3.0 if main else 2.0))
	frames_key(node, u + "tip", func(t: float) -> float: return N.smooth(sp, sp + PART + FALL, t) * 0.12 * HH)
	frames_key(node, u + "clip", func(t: float) -> float: return 1.0 if t < sp else lerpf(1.0, cut, pow(clampf((t - sp - 0.04) / FALL, 0.0, 1.0), 2.0)))
	frames_key(node, u + "sink", func(t: float) -> float: return N.smooth(sp + FALL, sp + FALL + SINK, t) * HH * (cut + 0.06))
	var gone: float = sp + FALL + SINK
	for i in int(SINK * 30.0) + 1:
		var t := sp + FALL + i / 30.0
		if N.smooth(sp + FALL, sp + FALL + SINK, t) * HH * (cut + 0.06) >= HH * (cut + 0.05):
			gone = t
			break
	show(node, at, gone)


func _erupt(s: Dictionary) -> void:
	var k: float = s.H / H
	var x: float = s.x
	var n: String = s.name
	var t0: float = s.at
	var big: float = 0.6 + 0.4 * k
	light_at(n + "Flash", Vector2(x, -s.H * 0.4), 30 * k + 14, Color.WHITE, 0.5 * k + 0.1, t0, 0.1)
	light_at(n + "Warm", Vector2(x, -10), 60 * k + 20, GL[2], 0.34 * k, t0, 0.5)
	var fade := [[0, 1], [0.8, 1], [1, 0]]
	var nc := int(roundf(16 * k)) + 3
	var sizes := [1.9, 2.7, 3.5]
	for j in 3:
		burst(n + "Chips%d" % j, Vector2(x, -3), t0, {"amount": int(ceil(nc / 3.0)), "lifetime": 2.4, "life_random": 0.4,
			"texture": N.rock(int(x * 10) + 7 * j + 3, sizes[j] * big, S), "emit": {"box": Vector2(s.w / 3.0, 2.5)}, "dir": -90,
			"spread": 63, "speed": [140 * big, 360 * big], "gravity": Vector2(0, 950), "damping": [40, 80], "angle": [0, 360],
			"spin": [-800, 800], "alpha_curve": fade, "collide": {"bounce": 0.32, "friction": 0.9, "size": 1}})
	var ng := int(roundf(55 * k)) + 10
	for g in [["Grit", "dot1", 0.6], ["Gravel", "dot2", 0.4]]:
		burst(n + g[0], Vector2(x, -1), t0, {"amount": int(ng * g[2]), "lifetime": 1.4, "life_random": 0.4, "texture": g[1],
			"emit": {"box": Vector2(s.w * 0.4, 0.5)}, "dir": -90, "spread": 52, "speed": [90, 330], "gravity": Vector2(0, 950),
			"damping": [20, 60], "initial": gradient([S[6], S[5], S[4], S[4], S[3]]), "collide": {"bounce": 0.1, "friction": 1.0}})
	burst(n + "Sparks", Vector2(x, -6), t0, {"amount": int(roundf(9 * k)) + 2, "lifetime": 0.35, "life_random": 0.5,
		"texture": "streak6", "align": true, "emit": {"box": Vector2(1, 4)}, "dir": -90, "spread": 69, "speed": [160, 380],
		"damping": [300, 500], "gravity": Vector2(0, 430), "ramp": gradient([GL[4], GL[3], GL[2], GL[1]])})
	var cloud := gradient([Color(dust, 0.0), Color(dust, 0.7), Color(dust.lerp(Color("#5d5660"), 0.35), 0.55),
		Color(dust2.lerp(Color("#433d48"), 0.5), 0.4), Color(Color("#433d48"), 0.2), Color(Color("#433d48"), 0.0)],
		[0.0, 0.05, 0.3, 0.55, 0.8, 0.95])
	var nk := int(roundf(10 * k)) + 3
	for side in [-1, 1]:
		burst(n + "Skirt%s" % ("L" if side < 0 else "R"), Vector2(x + side * 6, -2.5), t0, {"layer": "soft", "amount": int(ceil(nk / 2.0)),
			"lifetime": 1.5, "life_random": 0.4, "texture": "disc11", "emit": {"box": Vector2(4, 1.5)}, "dir": 90 - side * 90 - side * 5,
			"spread": 7, "speed": [50 * (0.5 + 0.5 * k), 170 * (0.5 + 0.5 * k)], "damping": [70, 120], "gravity": Vector2(0, -22),
			"scale": [0.6 * big, 1.0 * big], "scale_curve": [[0, 0.6], [0.3, 1.0], [1, 1.5]], "ramp": cloud})
		burst(n + "Dust%s" % ("L" if side < 0 else "R"), Vector2(x + side * 4, -1.5), t0, {"layer": "soft",
			"amount": int(ceil((14 * k + 4) / 2.0)), "lifetime": 0.9, "life_random": 0.45, "texture": "disc5",
			"emit": {"box": Vector2(4, 1.5)}, "dir": 90 - side * 90 - side * 6, "spread": 8, "speed": [40, 160], "damping": [120, 200],
			"scale": [0.6, 1.2], "scale_curve": [[0, 0.6], [1, 1.5]],
			"ramp": gradient([Color(dust2, 0.7), Color(dust2, 0.5), Color(dust2, 0.3), Color(dust2, 0.1)])})
	burst(n + "Rise", Vector2(x, -7), t0 + 0.05, {"layer": "soft", "amount": int(roundf(3 * k)) + 1, "lifetime": 1.5,
		"life_random": 0.35, "texture": "disc11", "emit": {"box": Vector2(6, 5)}, "dir": -90, "spread": 35, "speed": [15, 45],
		"damping": [10, 25], "gravity": Vector2(0, -20), "scale": [0.6 * k + 0.3, 0.9 * k + 0.4],
		"scale_curve": [[0, 0.6], [0.3, 1.0], [1, 1.5]], "ramp": cloud})
	if s.main:
		burst(n + "Stars", Vector2(x, -s.H * 0.5), t0 + 0.1, {"amount": 3, "lifetime": 0.4, "explosiveness": 0.3,
			"texture": "plus3", "emit": {"box": Vector2(5, s.H * 0.4)}, "speed": [3, 3], "color": S[7],
			"alpha_curve": [[0, 1], [0.6, 0.7], [1, 0]]})
		# rubble that went up high comes raining back down
		var rain := particles(n + "Rain", {"at": Vector2(x, -118), "amount": 32, "lifetime": 1.0, "texture": "dot1", "emitting": false,
			"emit": {"box": Vector2(60, 7)}, "dir": 90, "spread": 15, "speed": [10, 60], "gravity": Vector2(0, 950),
			"initial": gradient([S[5], S[4], S[3]]), "collide": {"bounce": 0.1, "friction": 1.0}})
		emit(rain, t0 + 0.25, t0 + 0.9)
		var glints := particles(n + "Glints", {"at": Vector2(x - 1, -s.H * 0.47), "amount": 2, "lifetime": 0.4, "emitting": false,
			"texture": "plus3", "emit": {"box": Vector2(3, s.H * 0.38)}, "speed": [2, 2], "initial": gradient([S[7], GL[3]]),
			"alpha_curve": [[0, 1], [0.6, 0.8], [1, 0]]})
		emit(glints, t0 + 0.25, s.split)
	# while it stands pebbles trickle off its flanks; as it cracks grit dribbles out
	var trickle := particles(n + "Trickle", {"at": Vector2(x + s.lean * 0.5, -s.H * 0.5), "amount": 3, "lifetime": 1.0,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(s.w * 0.35, s.H * 0.3)}, "dir": -90, "spread": 70,
		"speed": [10, 30], "gravity": Vector2(0, 950), "initial": gradient([S[6], S[5]]), "collide": {"bounce": 0.1, "friction": 1.0}})
	emit(trickle, t0 + 0.2, s.split)
	var split_t: float = s.split
	light_at(n + "SplitLight", Vector2(x, -s.H * 0.5), 30, Color.WHITE, 0.3, split_t, 0.08)
	burst(n + "SplitStar", Vector2(x + s.lean * 0.5, -s.H * 0.55), split_t, {"amount": 1, "lifetime": 0.3, "texture": "spark5",
		"speed": [2, 2], "color": S[7], "scale_curve": [[0, 1.4], [1, 0.6]], "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})


## after the split the halves crumble from the top: rubble and grit fall off the crumbling edge; the stump sinking
## pushes up a last puff of dust
func _crumble(s: Dictionary) -> void:
	var n: String = s.name
	var sp: float = s.split
	var t0 := sp + 0.04
	var holder := group(n + "Crumble")
	var path := []
	for i in int(FALL * 30.0) + 2:
		var t := t0 + i / 30.0
		var top := lerpf(1.0, s.cut, pow(clampf((t - t0) / FALL, 0.0, 1.0), 2.0))
		path.append([t, Vector2(s.x + s.lean * top, -top * s.H)])
	key(holder, "position", path)
	var D: float = meta.duration
	var life := minf(1.4, D - 0.1 - (t0 + FALL))
	var bands: float = (1.0 - s.cut) / 0.11
	var rocks := int(roundf(bands * 2.0))
	for j in 2:
		var p := particles(n + "Rubble%d" % j, {"parent": holder, "amount": int(ceil(rocks * life / FALL / 2.0)), "lifetime": life,
			"emitting": false, "texture": N.rock(int(s.x * 3) + 11 * j + 1, [1.8, 3.0][j] * (0.6 + 0.4 * s.H / H), S),
			"emit": {"box": Vector2(s.w * 0.3, 2)}, "dir": -90, "spread": 80, "speed": [10, 50], "gravity": Vector2(0, 950),
			"angle": [0, 360], "spin": [-450, 450], "alpha_curve": [[0, 1], [0.75, 1], [1, 0]],
			"collide": {"bounce": 0.3, "friction": 0.5, "size": 1}})
		emit(p, t0, t0 + FALL)
	var grit := particles(n + "CrumbleGrit", {"parent": holder, "amount": int(ceil(bands * 6.0 * 1.0 / FALL)), "lifetime": 1.0,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(s.w * 0.3, 2)}, "dir": -90, "spread": 75, "speed": [10, 70],
		"gravity": Vector2(0, 950), "initial": gradient([S[6], S[5], S[4], S[3]]), "collide": {"bounce": 0.1, "friction": 1.0}})
	emit(grit, t0, t0 + FALL)
	var puff := particles(n + "CrumbleDust", {"layer": "soft", "parent": holder, "amount": 4, "lifetime": 0.5, "emitting": false,
		"texture": "disc5", "emit": {"box": Vector2(4, 2)}, "dir": 90, "spread": 60, "speed": [15, 45], "damping": [40, 80],
		"ramp": gradient([Color(dust, 0.6), Color(dust, 0.4), Color(dust, 0.2)])})
	emit(puff, t0, t0 + FALL)
	var stump := particles(n + "StumpDust", {"layer": "soft", "at": Vector2(s.x, -1), "amount": 4, "lifetime": 0.6, "emitting": false,
		"texture": "disc5", "emit": {"box": Vector2(s.w / 2.0, 1)}, "dir": 0, "spread": 180, "speed": [20, 60], "damping": [60, 100],
		"scale_curve": [[0, 0.6], [1, 1.2]], "ramp": gradient([Color(dust2, 0.6), Color(dust2, 0.4), Color(dust2, 0.2)])})
	emit(stump, sp + FALL, sp + FALL + SINK * 0.8)
