# reimagined-from: src/fx/water/fountain.js@a18a8879e80d33752169912d064bcf8d8a2b6db6
# Fountain: A stone basin; a jet rises from its spout and blooms into glassy arcs that break into beads, fall back and plink into the water with rings.
# loop, 2.00 s, 120x104 canvas, origin [60.0, 96.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The basin and its spout are the original's pixels (port/props.py), split so its near half stands in front of the
# water. The basin's water and the jet are a canvas shader (fx/water/_fountain.gdshader), caustics swim in the water
# on the light layer. The twelve arcs (the original's, thrown the same ways) are glassy lines that thin as they fall;
# the beads they break into are an emitter per arc riding the arc's own parabola, slowed to the original's crawl;
# light runs down each stream. Where they come down rings spread (fx/water/_rings.gdshader), flecks pop up and the
# water lights; glints wink on the arcs and a fine mist hangs round the bloom.
extends "res://build/fx/water/_water.gd"

const D := 2.0
const SY := 0.34
const G := 600.0
const RIM := 10.0
const RX := 36.0
const IN := 29.5
const JET := 54.0
const ARCS := 12
const BY := -RX * SY
const LEVEL := RIM - 1.2

var Q := []


func along(q: Dictionary, tau: float) -> Vector2:
	var r: float = q.vr * tau
	var h: float = JET + q.vh * tau - 0.5 * G * tau * tau
	return Vector2(q.ca * r, BY + q.sa * r * SY - h)


## The arc's screen velocity tau seconds into its flight.
func vel(q: Dictionary, tau: float) -> Vector2:
	return Vector2(q.ca * q.vr, q.sa * q.vr * SY - (q.vh - G * tau))


## An emitter riding arc q from tau0, with its time slowed by k (tau seconds per second): velocity and gravity
## scaled so the particles trace the arc exactly.
func rider(name: String, q: Dictionary, tau0: float, k: float, o: Dictionary) -> GPUParticles2D:
	var v := vel(q, tau0) * k
	var oo := {"at": along(q, tau0), "dir": rad_to_deg(v.angle()), "spread": 0.0, "speed": [v.length(), v.length()],
		"gravity": Vector2(0, G * k * k)}
	oo.merge(o, true)
	return particles(name, oo)


func basin_part(name: String, r: Rect2, back: bool) -> Sprite2D:
	var s := prop({"name": name, "back": back})
	s.region_enabled = true
	s.region_rect = r
	s.position = -Vector2(root.origin) + r.position
	return s


func make() -> void:
	var S: int = meta.options.seed
	for i in ARCS:
		var a := ((i + 0.5) / ARCS) * TAU + jsrand([i, S]) * 0.25
		var vr := 38.0 + 14.0 * jsrand([i, S + 1])
		var vh := 30.0 + 26.0 * jsrand([i, S + 2])
		var tl := (vh + sqrt(vh * vh + 2.0 * G * (JET - LEVEL))) / G
		Q.append({"a": a, "vr": vr, "vh": vh, "tl": tl, "ca": cos(a), "sa": sin(a), "i": i})
	var W := float(root.canvas_size.x)
	var cut := float(root.origin.y) + BY - RIM

	# behind: the basin's far half, its water, the arcs on the far side
	basin_part("BasinBack", Rect2(0, 0, W, ceilf(cut)), true)
	var pool := {"pal": C, "by": BY, "level": LEVEL, "jet": JET, "pool_r": IN, "sy": SY, "seed": float(S)}
	var water := pool.duplicate()
	water.merge({"mode": 0.0, "translucent": true})
	var pool_at := Vector2(0, roundf(BY - LEVEL))
	loop_t(shape("Water", water_shader("fountain"), Vector2(64, 24), water, {"at": pool_at, "back": true}))
	loop_t(shape("Caustics", water_shader("fountain_light"), Vector2(64, 24), pool, {"at": pool_at, "back": true}))
	for q in Q:
		if q.sa < 0.0:
			water_arc(q, true)

	# the spout and the jet blooming at its top
	basin_part("Spout", Rect2(56, 67, 8, 10), false)
	var col := pool.duplicate()
	col.mode = 1.0
	loop_t(shape("Jet", water_shader("fountain"), Vector2(12, 48), col, {"at": Vector2(0, roundf(BY - 40.0))}))
	var bloom := glow("BloomLight", 22, {"radius": 22, "color": C[5], "alpha": 0.46}, {"at": Vector2(0, BY - JET)})
	sample(bloom, "material:shader_parameter/alpha", func(t: float) -> float: return 0.46 + 0.06 * sin(t / D * TAU * 4.0))
	glow("BloomHot", 8, {"radius": 8, "color": C[7], "alpha": 0.3}, {"at": Vector2(0, BY - JET - 1.0)})

	# the arcs on the near side, in front of the jet
	for q in Q:
		if q.sa >= 0.0:
			water_arc(q, false)

	# glints wink along the arcs
	var rng := RandomNumberGenerator.new()
	rng.seed = S + 30
	for g in 10:
		var born := rng.randf() * D
		var life := rng.randf_range(0.2, 0.35)
		var q: Dictionary = Q[rng.randi() % ARCS]
		if q.sa < -0.3:
			q = Q[(q.i + ARCS / 2) % ARCS]
		var p := along(q, rng.randf_range(0.1, 0.7) * q.tl)
		glint("Glint%d" % g, func(t: float) -> Array:
			var age := fposmod(t - born, D)
			return [p.x, p.y, sin(PI * age / life) if age < life else 0.0], 0.6)

	# where they come down: near halves of rings, flecks thrown up, light on the water
	var pts := PackedVector2Array()
	var ph := PackedFloat32Array()
	var ring_at := Vector2(0, roundf(BY - LEVEL))
	for q in Q:
		pts.append(along(q, q.tl) - ring_at)
		ph.append(jsrand([q.i, S + 9]))
	var rings := shape("Rings", water_shader("rings"), Vector2(84, 40), {"pal": C, "pts": pts, "phase": ph, "count": float(ARCS), "rate": 2.0,
		"r0": 2.0, "r1": 10.0, "kmax": 0.8, "kpow": 1.3, "sy": SY, "side": 1.0, "n": 1.0}, {"at": ring_at})
	loop_t(rings)
	var land := PackedVector2Array()
	for q in Q:
		land.append(along(q, q.tl) + Vector2(0, -1))
	particles("Flecks", {"amount": 7, "lifetime": 0.2, "texture": "dot1", "emit": {"points": land}, "dir": -90, "spread": 20,
		"speed": [12, 18], "gravity": Vector2(0, 60), "ramp": gradient([C[7], C[6]], [0.0, 0.5])})
	particles("LandLight", {"layer": "light", "amount": 12, "lifetime": 0.33, "texture": "glow16", "emit": {"points": land},
		"scale": [0.75, 0.75], "ramp": gradient([Color(C[5], 0.18), Color(C[5], 0.0)], [0.0, 1.0], true)})

	# the basin's near half stands in front of all that
	basin_part("BasinFront", Rect2(0, ceilf(cut), W, root.canvas_size.y - ceilf(cut)), false)

	# a fine mist hangs round the bloom
	particles("Mist", {"at": Vector2(0, BY - JET + 6.0), "amount": 9, "lifetime": 1.1, "randomness": 0.3, "texture": "dot1",
		"emit": {"ring": [20, 4]}, "dir": 90, "spread": 40, "speed": [6, 12], "radial": [3, 6],
		"initial": gradient([C[7], C[6], C[6]]), "alpha_curve": [[0, 1], [0.75, 1], [1, 0]]})

	# light: down the jet, and the basin water lit from above
	line("JetLight", PackedVector2Array([Vector2(0, BY - 16.0), Vector2(0, BY - JET)]), {"layer": "light", "width": 20, "color": Color(C[5], 0.18)})
	var lit := glow("PoolLight", 46, {"radius": 46, "color": C[4], "alpha": 0.26}, {"at": Vector2(0, BY - LEVEL - 2.0)})
	sample(lit, "material:shader_parameter/alpha", func(t: float) -> float: return 0.26 + 0.03 * sin(t / D * TAU * 2.0))
	glow("SkyLight", 30, {"radius": 30, "color": C[5], "alpha": 0.12}, {"at": Vector2(0, BY - LEVEL - 20.0)})


## One arc: a glassy stream that thins as it falls (white, then pale, then light blue; dimmer on the far side), the
## beads it breaks into crawling down its end, a fleck of light sliding down the stream.
func water_arc(q: Dictionary, back: bool) -> void:
	var n: String = ("Back" if back else "Arc") + str(q.i)
	var pts := PackedVector2Array()
	var dist := [0.0]
	var tau := 0.0
	var stops := [0.25] if back else [0.2, 0.45]
	var at_len := []
	while tau <= q.tl * 0.66:
		var p := along(q, tau)
		if pts.size():
			dist.append(dist[-1] + p.distance_to(pts[-1]))
		pts.append(p)
		tau += 0.012
	var total: float = dist[-1]
	for s in stops:
		var k := int(s * q.tl / 0.012)
		at_len.append(dist[mini(k, dist.size() - 1)] / total)
	var cols: Array = [C[5], C[4]] if back else [C[7], C[6], C[5]]
	line(n, pts, {"back": back, "gradient": gradient(cols, [0.0] + at_len)})
	# the beads, crawling from 0.58 to the end of the arc once a second
	var bo := {"back": back, "amount": 6, "lifetime": 1.0, "texture": "streak3", "align": true, "color": C[3] if back else C[4]}
	var beads := rider(n + "Beads", q, 0.58 * q.tl, 0.42 * q.tl, bo)
	if not back:
		# a bright head at the leading end of each (they fall nearly straight down there)
		var ho := bo.duplicate()
		ho.merge({"texture": "dot1", "align": false, "color": C[6]}, true)
		var head := rider(n + "BeadHeads", q, 0.58 * q.tl, 0.42 * q.tl, ho)
		head.position += Vector2(0, 1)
		head.seed = beads.seed
	# a fleck of light sliding down the stream twice a second
	var glide := {"back": back, "amount": 1, "lifetime": 0.5, "texture": "dot1", "color": C[7], "preprocess": 0.5 + fposmod(q.a, 1.0) * 0.5}
	var g := rider(n + "Glide", q, 0.0, 1.2 * q.tl, glide)
	if not back:
		var gl := glide.duplicate()
		gl.merge({"layer": "light", "texture": "glow8", "color": Color(C[5], 0.3)}, true)
		var light := rider(n + "GlideLight", q, 0.0, 1.2 * q.tl, gl)
		light.seed = g.seed
