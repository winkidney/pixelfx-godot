# reimagined-from: src/fx/fire/candle.js
# Candle: a wax candle in a brass dish: a calm flame with a blue root that sways and stretches, a halo of light, motes
# drifting in it, a bead of wax running down a drip.
# The wax, wick and dish are the original's pixels (port/props.py) with the few the flame lights drawn over them;
# the flame is one calm tongue of five layered emitters (an orange rim round gold, yellow, a pale heart and a white
# core), its sideways pull and its speed keyed from the original's sway and stretch; the blue root is a few pixels,
# the bead a pixel keyed down the drip; a thread of smoke, motes drifting in the light, the halo, its ring and a pool
# of light on the floor.
extends "res://build/fx/fire/_fire.gd"

const S := 2
const TOP := -16.0
const WICK := TOP - 3.0
## a calm flame: an orange rim round gold, yellow, a pale heart and a small white core low down
const CALM := [[1.0, 1.0, 5], [0.8, 0.88, 3], [0.6, 0.72, 2], [0.38, 0.52, 1], [0.18, 0.3, 0]]
const LIFE := 0.22


func fl(t: float) -> float:
	return 0.86 + 0.08 * N(t, 2.0, S + 1) + 0.06 * N(t, 7.0, S + 2)


func height(t: float) -> float:
	var stretch := maxf(0.0, N(t, 0.75, S + 3) - 0.3) * 0.6
	return 12.0 * (1.0 + stretch) * (0.94 + 0.06 * fl(t))


func sway(t: float) -> float:
	return N(t, 0.5, S + 4) * 1.6 + N(t, 1.5, S + 5) * 0.5


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func make() -> void:
	fire_begin()
	var X: PackedColorArray = root.ramps.wax
	var B: PackedColorArray = root.ramps.brass
	var RT: PackedColorArray = root.ramps.root
	var GLOW := H[3].lerp(H[4], 0.5).lerp(Color.WHITE, 0.3)
	var fl0 := 0.86

	# a pool of warm light on the floor, the halo behind the flame and its ring
	var pool := glow("FloorLight", 26, {"radius": 26, "squash": 5.0 / 26.0, "color": GLOW, "alpha": 0.3}, {"at": Vector2(0, 1)})
	key(pool, "material:shader_parameter/alpha", sampled(func(t): return 0.3 * fl(t)))
	var halo := glow("Halo", 44, {"radius": 38, "color": GLOW, "alpha": 0.42}, {"at": Vector2(0, WICK - 4.8)})
	var ring_ := glow("HaloRing", 16, {"radius": 10, "thickness": 4, "color": H[2], "alpha": 0.12}, {"at": Vector2(0, WICK - 4.8)})
	key(halo, "material:shader_parameter/alpha", sampled(func(t): return 0.42 * fl(t)))
	key(halo, "material:shader_parameter/radius", sampled(func(t): return 38.0 * fl(t)))
	key(ring_, "material:shader_parameter/alpha", sampled(func(t): return 0.12 * fl(t)))
	for g in [halo, ring_]:
		key(g, "position", sampled(func(t): return Vector2(sway(t) * 0.3, WICK - height(t) * 0.4)))

	# the candle and its dish, and the pixels the flame lights on them
	prop({"back": false})
	rect("Rim", Rect2(-3, TOP, 3, 1), X[5].lerp(H[2], 0.25 * fl0))
	rect("Rim2", Rect2(1, TOP, 3, 1), X[5].lerp(H[2], 0.25 * fl0))
	rect("Pool", Rect2(-2, TOP + 1, 5, 1), X[5].lerp(H[1], 0.5 * fl0))
	rect("PoolHeart", Rect2(-1, TOP + 1, 3, 1), X[4].lerp(H[2], 0.45 * fl0))
	var lit := B[3].lerp(H[3], 0.3 * fl0)
	for r in [Rect2(-6, -1, 2, 1), Rect2(5, -1, 1, 1), Rect2(-8, 0, 2, 1), Rect2(6, 0, 2, 1)]:
		rect("Brass%d_%d" % [r.position.x, r.position.y], r, lit)

	# the bead of wax: it swells at the rim, runs down the drip and sets into its bulb
	var bead := group("Bead", {"at": Vector2(4, TOP + 2)})
	rect("Drop", Rect2(0, 0, 1, 1), X[5].lerp(H[1], 0.4 * fl0), {"parent": bead})
	var side := group("Side", {"parent": bead})
	rect("Side1", Rect2(1, 0, 1, 1), X[4], {"parent": side})
	rect("Side2", Rect2(1, 1, 1, 1), X[2], {"parent": side})
	var D: float = root.duration
	var pos := []
	var vis := []
	var svis := []
	for i in int(D * 30.0) + 1:
		var t := i / 30.0
		var run := fposmod(t, D) / D
		var sw := smooth(0.0, 0.3, run)
		var sl := smooth(0.3, 0.85, run)
		var st := smooth(0.85, 1.0, run)
		pos.append([t, Vector2(4, roundf(TOP + 2 + (-7.0 - TOP - 2) * sl))])
		vis.append([t, st < 1.0 and sw > 0.15])
		svis.append([t, sw > 0.6 and st < 0.5])
	key(bead, "position", pos, "nearest")
	key(bead, "visible", vis, "nearest")
	key(side, "visible", svis, "nearest")

	# the flame: one calm tongue, swaying and now and then stretching tall
	flame(Vector2(0, WICK + 1.5))
	# its blue root and the hot tip of the wick
	rect("Wick", Rect2(0, WICK + 2, 1, 1), X[0])
	var root_px := [[-2, 0, RT[0]], [-1, 0, RT[1]], [0, 0, RT[1]], [1, 0, RT[1]], [2, 0, RT[0]], [-1, 1, RT[0]], [1, 1, RT[0]], [0, -1, RT[2]]]
	for q in root_px:
		rect("Root%d_%d" % [q[0] + 2, q[1] + 1], Rect2(q[0], WICK + 1 + q[1], 1, 1), q[2])

	# a thread of smoke now and then off the tip
	var wisp := gradient([Color(SMOKE1, 0.0), Color(SMOKE1.lerp(Color("#7b6f72"), 0.5), 0.13), Color(SMOKE1, 0.08), Color(SMOKE1, 0.0)], [0.0, 0.1, 0.6, 0.95])
	var thread := particles("Smoke", {"layer": "soft", "at": Vector2(0, WICK - 12), "amount": 2, "lifetime": 1.8, "randomness": 0.3,
		"texture": "disc3", "dir": -90, "spread": 8, "speed": [8, 12], "gravity": Vector2(1, -4), "damping": [1, 2],
		"scale_curve": [[0, 0.7], [1, 1.4]], "ramp": wisp, "turbulence": {"strength": 1.0, "scale": 3.0, "influence": [0.005, 0.01]}})
	key(thread, "position", sampled(func(t): return Vector2(sway(t), WICK - height(t))))

	# motes drifting in the candlelight
	particles("Motes", {"at": Vector2(0, WICK - 6), "amount": 5, "lifetime": 3.2, "randomness": 0.3, "texture": "dot1",
		"emit": {"circle": 19}, "dir": -90, "spread": 180, "speed": [1, 4], "gravity": Vector2(0, -0.6),
		"ramp": gradient([Color(H[3], 0.0), Color(H[3], 0.7), H[1], Color(H[3], 0.7), Color(H[3], 0.0)], [0.0, 0.12, 0.4, 0.75, 0.95]),
		"turbulence": {"strength": 1.0, "scale": 2.0, "influence": [0.005, 0.01]}})

	# the hot core of the light
	var core := glow("Core", 12, {"radius": 10, "color": H[1], "alpha": 0.35}, {"at": Vector2(0, WICK - 3.6)})
	key(core, "material:shader_parameter/alpha", sampled(func(t): return 0.35 * fl(t)))
	key(core, "position", sampled(func(t): return Vector2(sway(t) * 0.5, WICK - height(t) * 0.3)))


## The calm tongue: per layer an emitter of discs rising off the wick, as wide as the layer, tapering to the tip; its
## speed keyed from the stretch and a sideways pull from the sway (the tip swept sway px).
func flame(at: Vector2) -> void:
	var k := 0
	for L in CALM:
		var lw: float = L[0]
		var lh: float = L[1]
		var half := 2.6 * lw
		var width := 2.0 * half + 1.0
		var tex := "disc5" if width > 3.2 else "disc3"
		var ts := 5.0 if tex == "disc5" else 3.0
		var s := width / ts
		var m := 1.1 / width
		var taper := []
		for u in [0.0, 0.1, 0.2, 0.4, 0.6, 0.8, 0.95, 1.0]:
			var r: float = u * 12.0 * lh
			taper.append([u, maxf(m, pow(1.0 - u, 0.85) * minf(1.0, (r + 1.5) / 3.5))])
		var len := 12.0 * lh
		var v := len / LIFE
		var p := particles("Flame%d" % k, {"at": at, "amount": int(ceil(len * 2.0)) + 4, "lifetime": LIFE, "texture": tex,
			"emit": {"box": Vector2(0.3, 0.4)}, "dir": -90, "spread": 1.5, "speed": [v * 0.95, v * 1.02],
			"scale": [s, s], "scale_curve": taper, "color": H[L[2]]})
		key(p, "process_material:initial_velocity_min", sampled(func(t): return height(t) * lh / LIFE * 0.95))
		key(p, "process_material:initial_velocity_max", sampled(func(t): return height(t) * lh / LIFE * 1.02))
		key(p, "process_material:gravity", sampled(func(t): return Vector3(2.0 * sway(t) * lh / (LIFE * LIFE), 0, 0)))
		k += 1


# ------------------------------------------------------------------ the original's own noise (src/core/math.js hash,
# fire/_lib.js noiseFor), so the flame leaps, sways and flickers on the reference's beats

static func _mul32(a: int, b: int) -> int:
	return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


static func _jhash(a: int, b: int) -> int:
	var h := 0x9e3779b9
	for n in [a, b]:
		h = _mul32(h ^ (n & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = _mul32(h, 0xc2b2ae35)
		h ^= h >> 16
	return h


func N(t: float, rate: float, s: int, off := 0.0) -> float:
	var D: float = root.duration
	var P := maxi(1, roundi(rate * D))
	var x := t / D * P + off
	var i := floori(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	var a := _jhash(posmod(i, P), s) / 4294967296.0
	var b := _jhash(posmod(i + 1, P), s) / 4294967296.0
	return (a + (b - a) * u) * 2.0 - 1.0
