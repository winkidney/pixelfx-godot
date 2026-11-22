# reimagined-from: src/fx/nature/thorns.js@2966fdd134ae493a3760bf2f1fedd3f4674c8dd9
# Thorns: A seam races along the floor and hooked thorns punch up out of it one after another, each bigger than the
# last, in bursts of dirt and green light; they hold, then sink.
# Each thorn is a shader of its own (fx/nature/_thorn.gdshader: the original's hooked horn, lit edge, grain, barb,
# dark rim) whose height, sinking and white flash are keyed frame by frame from the original's curves; the seam is
# another small shader (fx/nature/_thorn_seam.gdshader) whose glowing head runs out along the floor. A collar of
# leaves (build-time textures drawn as the original draws its leaves) unfurls round each foot. Dirt chips (faceted
# stones), grit, dust, green stars and motes burst as each thorn punches up, chips and dust as it sinks; green light
# flares with each and glows at the feet.
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const RISE := 0.11
const SINK := 0.36


static func out_back(x: float, s: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


func frames_key(node: Node, prop: String, fn: Callable, t0 := 0.0, t1 := -1.0) -> void:
	var keys := []
	var last: Variant = null
	if t0 > 0.0:
		last = fn.call(t0)
		keys.append([0.0, last])
	for i in range(int(t0 * 30.0), int(roundf((meta.duration if t1 < 0.0 else t1) * 30.0)) + 1):
		var t := i / 30.0
		var v: Variant = fn.call(t)
		if last == null or v != last:
			keys.append([t, v])
			last = v
	key(node, prop, keys, "nearest")


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
	var C: PackedColorArray = root.ramps.palette
	var G: PackedColorArray = root.ramps.glow
	var S: PackedColorArray = root.ramps.soil
	var D: float = meta.duration
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	keep_colour(Color.WHITE)
	var n: int = maxi(2, int(meta.options.count))
	var list := []
	for i in n:
		var k := i / float(n - 1)
		var h := 12.0 + 36.0 * k + rng.randf_range(-1.5, 1.5)
		list.append({"x": 10.0 + i * (104.0 / (n - 1)) + rng.randf_range(-3, 3), "h": h, "w": 6.0 + 9.0 * k,
			"lean": rng.randf_range(-1, 1.5) + k * 2.0, "hook": h * rng.randf_range(0.14, 0.22), "at": 0.12 + i * 0.075,
			"sink": 1.45 + i * 0.06, "seed": float(rng.randi_range(1, 999))})
	var reach: float = list[n - 1].x + 8.0

	# the seam racing ahead along the floor, its head glowing green
	var seam := shape("Seam", load("res://addons/pixelfx_particles/fx/nature/_thorn_seam.gdshader"), Vector2(ceilf(reach / 2.0) * 2.0 + 12.0, 6),
		{"soil_dark": S[0], "soil_shade": S[1], "soil_lip": S[4], "glow_mid": G[2], "glow_hot": G[3], "run": -3.0, "cool": 1.0},
		{"at": Vector2(ceilf(reach / 2.0), 0), "back": true})
	var run := func(t: float) -> float: return N.out_cubic((t - 0.04) / 0.5) * reach if t > 0.04 else -3.0
	var cool := func(t: float) -> float: return 1.0 - N.smooth(0.6, 1.2, t)
	frames_key(seam, "material:shader_parameter/run", run, 0.0, 0.6)
	frames_key(seam, "material:shader_parameter/cool", cool, 0.0, 1.3)
	key(seam, "material:shader_parameter/alpha", [[0.0, 1.0], [1.9, 1.0], [2.1, 0.5], [2.3, 0.0]])
	var head := glow("SeamLight", 12, {"radius": 10, "squash": 0.6, "color": G[2], "alpha": 0.0})
	frames_key(head, "position", func(t: float) -> Vector2: return Vector2(roundf(run.call(t)) - 6.0, 0.0), 0.0, 0.6)
	frames_key(head, "material:shader_parameter/alpha", func(t: float) -> float: return 0.4 * cool.call(t) if t > 0.04 else 0.0, 0.0, 1.3)

	var cloud := gradient([Color(S[5], 0.0), Color(S[5].lerp(Color("#7b6f72"), 0.3), 0.45), Color(S[4].lerp(Color("#5d5660"), 0.5), 0.35),
		Color(S[3].lerp(Color("#433d48"), 0.5), 0.25), Color(Color("#433d48"), 0.12), Color(Color("#433d48"), 0.0)],
		[0.0, 0.06, 0.3, 0.55, 0.8, 0.95])
	var i := 0
	for s in list:
		_thorn(s, i, C, G, S, cloud)
		i += 1


func _thorn(s: Dictionary, i: int, C: PackedColorArray, G: PackedColorArray, S: PackedColorArray, cloud: GradientTexture1D) -> void:
	var D: float = meta.duration
	var x: float = s.x
	var h: float = s.h
	var w: float = s.w
	var at: float = s.at
	var sk: float = s.sink
	var k := h / 48.0
	var nm := "Thorn%d" % i
	var grown := func(t: float) -> float: return 0.0 if t < at else out_back(clampf((t - at) / RISE, 0.0, 1.0), 2.4)
	var sunk := func(t: float) -> float: return N.smooth(sk, sk + SINK, t)

	# the base glow and the leaves come first: the thorn stands over them
	var lk := func(t: float) -> float: return clampf((t - at - 0.04) / 0.18, 0.0, 1.0) * (1.0 - sunk.call(t))
	var foot := glow(nm + "FootLight", w + 8, {"radius": w + 6, "color": G[2], "alpha": 0.0}, {"at": Vector2(x, -2)})
	frames_key(foot, "material:shader_parameter/alpha", func(t: float) -> float: return 0.18 * lk.call(t))
	var lw := w * 0.5
	var leaves := [[-1.0, -2.5, 1.0], [1.0, -0.55, 0.9], [-1.0, -1.9, 0.7]]
	for j in 3:
		var sd: float = leaves[j][0]
		var a0: float = leaves[j][1]
		var sz: float = leaves[j][2]
		var L := (5.0 + w * 0.45) * sz
		var leaf := sprite(nm + "Leaf%d" % j, N.leaf(L, 1.4 + w * 0.1 * sz, 0.35, [G[0], G[1], G[2], G[3]], a0), {})
		var la := func(t: float) -> float: return a0 + sd * 0.25 * (1.0 - lk.call(t)) + sin(t * 4.0 + x) * 0.06
		var lp := func(t: float) -> Vector2:
			var a: float = la.call(t)
			var r: float = L * lk.call(t) * 0.5
			return Vector2(roundf(x + sd * lw + cos(a) * r), roundf(-1.0 + sin(a) * r))
		frames_key(leaf, "position", lp)
		frames_key(leaf, "rotation", func(t: float) -> float: return la.call(t) - a0)
		frames_key(leaf, "scale", func(t: float) -> Vector2: return Vector2.ONE * lk.call(t))
		frames_key(leaf, "visible", func(t: float) -> bool: return lk.call(t) > 0.05)

	# the thorn
	var x0: float = x - w - 6.0
	var x1: float = x + w / 2.0 + absf(s.lean) + absf(s.hook) + 3.0
	var y0: float = -h * 1.35 - 4.0
	var c := Vector2(roundf((x0 + x1) / 2.0), roundf((y0 + 2.0) / 2.0))
	var sz2 := Vector2(ceilf((x1 - x0) / 2.0) * 2.0 + 2.0, ceilf((2.0 - y0) / 2.0) * 2.0 + 2.0)
	var th := shape(nm, load("res://addons/pixelfx_particles/fx/nature/_thorn.gdshader"), sz2,
		{"ramp": ramp("palette", {"stops": 8}), "x": x, "w": w, "hook": s.hook, "lean": s.lean, "h": 0.0, "base": 0.0, "white": 0.0,
		"grain_seed": s.seed}, {"at": c})
	frames_key(th, "material:shader_parameter/h", func(t: float) -> float: return h * grown.call(t))
	frames_key(th, "material:shader_parameter/base", func(t: float) -> float: return sunk.call(t) * h * 1.05)
	frames_key(th, "material:shader_parameter/white", func(t: float) -> float: return 1.0 if t >= at and t - at < 0.035 else 0.0)
	show(th, at, sk + SINK)

	# light: a white pop and a green flare as it punches up, a glow rising with it
	light_at(nm + "Pop", Vector2(x, -h * 0.5), 18 + 18 * k, Color.WHITE, 0.45, at, 0.08)
	light_at(nm + "Flare", Vector2(x, -h * 0.4), 26 + 26 * k, G[2], 0.45, at, 0.4)
	var rise := glow(nm + "Rise", h * 0.6 + 8, {"radius": h * 0.6 + 6, "color": G[2], "alpha": 0.0})
	var rp := []
	var ra := [[0.0, 0.0], [at - 0.001, 0.0]]
	for f in range(int(ceilf(at * 30.0)), int(ceilf((at + 0.3) * 30.0)) + 1):
		var t := f / 30.0
		rp.append([t, Vector2(x, roundf(-h * 0.5 * grown.call(t)))])
		ra.append([t, maxf(0.0, 0.35 * (1.0 - (t - at) / 0.3))])
	key(rise, "position", rp, "nearest")
	key(rise, "material:shader_parameter/alpha", ra)

	# the burst: dirt chips, grit, dust, green stars and motes
	var sp := 0.6 + 0.6 * k
	var nc := 3 + int(roundf(5 * k))
	burst(nm + "Chips", Vector2(x, -1), at, {"amount": nc, "lifetime": 1.1, "life_random": 0.35,
		"texture": N.rock(i * 7 + 3, 2.0 * sqrt(sp), S), "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 63,
		"speed": [60 * sp, 210 * sp], "gravity": Vector2(0, 950), "angle": [0, 360], "spin": [-850, 850],
		"alpha_curve": [[0, 1], [0.78, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
	for g in [["Grit", "dot1", 0.7], ["Gravel", "dot2", 0.3]]:
		burst(nm + g[0], Vector2(x, -1), at, {"amount": int(ceil((10 + 18 * k) * g[2])), "lifetime": 1.0, "life_random": 0.4,
			"texture": g[1], "emit": {"box": Vector2(w / 3.0, 0.5)}, "dir": -90, "spread": 57, "speed": [60 * sp, 230 * sp],
			"gravity": Vector2(0, 950), "initial": gradient([S[5], S[4], S[3]]), "collide": {"bounce": 0.15, "friction": 1.0}})
	burst(nm + "Dust", Vector2(x, -2.5), at, {"layer": "soft", "amount": 3 + int(roundf(5 * k)), "lifetime": 1.1, "life_random": 0.35,
		"texture": "disc7", "emit": {"box": Vector2(4, 1.5)}, "dir": -90, "spread": 88, "speed": [20, 80], "damping": [60, 100],
		"gravity": Vector2(0, -10), "scale": [0.6 * (0.6 + 0.5 * k), 1.1 * (0.6 + 0.5 * k)], "scale_curve": [[0, 0.6], [0.3, 1.0], [1, 1.3]],
		"ramp": cloud})
	burst(nm + "Stars", Vector2(x + s.hook * 0.8, -h * 0.75), at, {"amount": 2 + int(roundf(3 * k)), "lifetime": 0.5,
		"life_random": 0.4, "explosiveness": 0.6, "texture": "plus3", "emit": {"box": Vector2(3, h * 0.25)}, "dir": -90,
		"spread": 40, "speed": [5, 20], "color": G[3], "alpha_curve": [[0, 1], [0.6, 0.8], [1, 0]]})
	burst(nm + "Motes", Vector2(x, -h * 0.3), at, {"amount": 4, "lifetime": 0.6, "life_random": 0.35, "texture": "streak4",
		"align": true, "emit": {"box": Vector2(3, h * 0.3)}, "dir": -90, "spread": 17, "speed": [30, 70], "damping": [15, 30],
		"color": G[3], "alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	var ml := burst(nm + "MoteLight", Vector2(x, -h * 0.3), at, {"layer": "light", "amount": 4, "lifetime": 0.6, "life_random": 0.35,
		"texture": "glow8", "emit": {"box": Vector2(3, h * 0.3)}, "dir": -90, "spread": 17, "speed": [30, 70], "damping": [15, 30],
		"color": Color(G[3], 0.4), "alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	ml.seed = get_node_seed(nm + "Motes")
	# while it stands, glints run up its lit edge
	var glints := particles(nm + "Glints", {"at": Vector2(x + s.lean * 0.5 - w * 0.15, -h * 0.55), "amount": 1, "lifetime": 0.6,
		"emitting": false, "texture": "plus3", "emit": {"box": Vector2(1, h * 0.25)}, "speed": [3, 3], "color": C[7],
		"alpha_curve": [[0, 1], [0.6, 0.7], [1, 0]]})
	emit(glints, at + 0.2, sk)
	# sinking: a few chips and a skirt of dust
	burst(nm + "SinkChips", Vector2(x, -1), sk, {"amount": 2 + int(roundf(2 * k)), "lifetime": minf(0.8, D - 0.05 - sk), "life_random": 0.3,
		"texture": N.rock(i * 7 + 5, 1.6, S), "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 63, "speed": [20, 75],
		"gravity": Vector2(0, 950), "angle": [0, 360], "spin": [-850, 850], "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
	burst(nm + "SinkDust", Vector2(x, -1.5), sk, {"layer": "soft", "amount": 3 + int(roundf(3 * k)), "lifetime": minf(0.7, D - 0.05 - sk),
		"life_random": 0.4, "texture": "disc7", "emit": {"box": Vector2(w / 2.0, 1.5)}, "dir": 0, "spread": 180, "speed": [15, 50],
		"damping": [60, 100], "scale_curve": [[0, 0.6], [1, 1.2]],
		"ramp": gradient([Color(S[5], 0.5), Color(S[5], 0.35), Color(S[4], 0.2), Color(S[4], 0.1)])})


func get_node_seed(name: String) -> int:
	return (root.get_node(name) as GPUParticles2D).seed
