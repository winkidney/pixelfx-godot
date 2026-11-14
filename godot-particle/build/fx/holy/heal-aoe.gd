# reimagined-from: src/fx/holy/heal-aoe.js@5e7c9d9fa3dccdc9a73c541397f1dcc06a43f75c
# Healing ring: A seed of green light sinks into the floor and a soft ring rolls out from it; the floor glows where it passes and plus signs sprout and float up.
# one-shot, 2.90 s, 256x136 canvas, origin [128.0, 104.0], backdrop ground
# ramp palette: #0e2a24 #14472f #1d6e3a #2f9a45 #5cc654 #a0e46c #dcffb4 #ffffff
# Motes streak in over the floor to a seed that brightens (aligned streak particles), then it lets go: a flare, a jet
# of light that leaps up and dissolves (fx/holy/_heal_jet.gdshader, keyed), a burst of motes and twinkling stars
# (particles with light twins) and two lights. The ring rolling out is a shader per half (fx/holy/_heal_ring.gdshader:
# band, oval, flickering crest, riders; the far half behind), lit by fx/holy/_heal_ring_light.gdshader with the floor
# glowing where it has passed. Plus signs sprout where it passes and float up (fx/holy/_heal_sprouts.gdshader, from
# the sites picked here), dew splashes up where each breaks the floor and embers of dew rise behind the ring
# (particles, the ring's reach in three bands that start as it passes them).
extends "res://build/fx/holy/_holy.gd"

const SY := 0.2
const SEED := 0.3
const ROLL := 1.0


func front(t: float) -> float:
	return 0.0 if t < SEED else float(meta.options.reach) * out_cubic(seg(t, SEED, SEED + ROLL))


func passed(d: float) -> float:
	return SEED + ROLL * (1.0 - pow(1.0 - minf(0.999, d / float(meta.options.reach)), 1.0 / 3.0))


## Frames of the originals' STAR particle over a life: arm(u) px (a sparkle), 0 a single pixel, < 0 nothing.
static func star_strip(n: int, arm: Callable, c: Color, tip: Color) -> Image:
	var s := 7
	var img := Image.create(s * n, s, false, Image.FORMAT_RGBA8)
	for f in n:
		var a := int(roundf(float(arm.call((f + 0.5) / n))))
		var ox := f * s + 3
		if a < 0:
			continue
		img.set_pixel(ox, 3, Color.WHITE)
		for d in range(1, mini(a, 3) + 1):
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixel(ox + v.x * d, 3 + v.y * d, tip if d > a * 0.6 else c)
	return img


func make() -> void:
	var REACH: float = meta.options.reach
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var D: float = meta.duration

	# ---- the sites the plus signs sprout from, each waiting for the ring to reach it
	var sa := PackedVector4Array()
	var sb := PackedVector4Array()
	var sites := []
	for i in 26:
		var a := rng.randf_range(0, TAU)
		var d := REACH * sqrt(rng.randf_range(0.04, 0.92))
		var big := i % 5 < 2
		var s := {"x": cos(a) * d, "z": sin(a) * d, "t0": passed(d) + rng.randf_range(0, 0.06), "rise": rng.randf_range(18, 34),
			"life": rng.randf_range(0.9, 1.3), "sway": rng.randf_range(0, TAU),
			"L": (3 + (1 if i % 5 == 0 else 0)) if big else (1 if i % 5 == 2 else 2), "thick": 3 if big else 1}
		sites.append(s)
		sa.append(Vector4(s.x, s.z, s.t0, s.rise))
		sb.append(Vector4(s.life, s.sway, s.L, s.thick))
	var riders := PackedVector4Array()
	for i in 14:
		riders.append(Vector4(i / 14.0 * TAU + rng.randf_range(-0.2, 0.2), rng.randf_range(0.6, 1.1) * (1.0 if i % 2 else -1.0), 0, 0))

	# ---- the ring, its light and the floor's glow
	for half in [[1.0, true, "RingFar"], [-1.0, false, "RingNear"]]:
		var rg := shape(half[2], holy_shader("heal_ring"), Vector2(224, 64), {"reach": REACH, "side": half[0], "pal": C, "riders": riders},
			{"back": half[1]})
		key(rg, "material:shader_parameter/time", [[0.0, 0.0], [D, D]])
	var rl := shape("RingLight", holy_shader("heal_ring_light"), Vector2(256, 96), {"reach": REACH, "pal": C, "riders": riders})
	key(rl, "material:shader_parameter/time", [[0.0, 0.0], [D, D]])

	# ---- the sprouts
	for half in [[1.0, true, "SproutsFar"], [-1.0, false, "SproutsNear"]]:
		var sp := shape(half[2], holy_shader("heal_sprouts"), Vector2(224, 96), {"side": half[0], "pal": C, "sa": sa, "sb": sb},
			{"at": Vector2(0, -20), "back": half[1]})
		key(sp, "material:shader_parameter/time", [[0.0, 0.0], [D, D]])
	var sl := shape("SproutsLight", holy_shader("heal_sprouts_light"), Vector2(240, 120), {"pal": C, "sa": sa, "sb": sb}, {"at": Vector2(0, -24)})
	key(sl, "material:shader_parameter/time", [[0.0, 0.0], [D, D]])

	# ---- the seed: motes streak in over the floor to a point of light that brightens
	var gpts := PackedVector2Array()
	for i in 96:
		var a := rng.randf_range(0, TAU)
		var dd := rng.randf_range(24, 48)
		gpts.append(Vector2(cos(a) * dd, sin(a) * dd * SY - rng.randf_range(1, 8) + 3.0))
	var streak := Image.create(1, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		var dd := 6 - y
		streak.set_pixel(0, y, Color.WHITE if dd < 1 else (C[6] if dd < 3.5 else Color(C[4], 1.2 - dd / 7.0)))
	var g_o := {"at": Vector2(0, -3), "amount": 18, "lifetime": 0.22, "life_random": 0.3, "emit": {"points": gpts}, "radial_speed": [-150, -110],
		"radial": [-500, -300], "align": true}
	var gather := particles("Gather", g_o.merged({"texture": asset("streak.png", streak)}))
	emit(gather, 0.0, SEED - 0.04)
	var gather_l := particles("GatherLight", g_o.merged({"texture": "glow8", "layer": "light", "modulate": Color(C[6], 0.4)}))
	emit(gather_l, 0.0, SEED - 0.04)

	var seed_sp := sparkle("Seed", Vector2(0, -3), 2.0, Color.WHITE, C[6])
	keyn(seed_sp, "material:shader_parameter/arm", func(t: float) -> float: return 2.0 + 4.0 * pow(t / SEED, 2.0) if t < SEED else 0.0, 0.0, SEED + 0.05)
	var seed_l := glow("SeedLight", 28, {"radius": 10, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -3)})
	keyn(seed_l, "material:shader_parameter/radius", func(t: float) -> float: return 10.0 + 16.0 * minf(1.0, t / SEED), 0.0, SEED + 0.05)
	keyn(seed_l, "material:shader_parameter/alpha", func(t: float) -> float: return 0.5 * t / SEED if t < SEED else 0.0, 0.0, SEED + 0.05)
	var seed_w := glow("SeedWhite", 18, {"radius": 8, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -3)})
	keyn(seed_w, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * roundf(2.0 + 4.0 * pow(minf(1.0, t / SEED), 2.0)), 0.0, SEED + 0.05)
	keyn(seed_w, "material:shader_parameter/alpha", func(t: float) -> float: return 0.3 + 0.4 * t / SEED if t < SEED else 0.0, 0.0, SEED + 0.05)

	# ---- it lets go: a flare, a jet of light, motes and stars, two lights
	var fl := flare("Flare", 24, {"at": Vector2(0, -3)})
	keyn(fl, "material:shader_parameter/reach", func(t: float) -> float: return 22.0 * pow(1.0 - seg(t, SEED, SEED + 0.2), 1.5) if t >= SEED and t < SEED + 0.2 else 0.0, 0.0, SEED + 0.25)
	keyn(fl, "material:shader_parameter/k", func(t: float) -> float: return 1.0 - seg(t, SEED, SEED + 0.2), 0.0, SEED + 0.25)
	var jet := shape("Jet", holy_shader("heal_jet"), Vector2(16, 76), {"c6": C[6], "c5": C[5]}, {"at": Vector2(0, -32)})
	var jet_l := shape("JetLight", holy_shader("heal_glowline"), Vector2(32, 100), {"radius": 12.0, "color": C[5]}, {"at": Vector2(0, -32)})
	var jet_top := sparkle("JetTip", Vector2(0, -4), 0.0, Color.WHITE, C[6])
	var jet_tl := glow("JetTipLight", 14, {"radius": 10, "color": Color.WHITE, "alpha": 0.0})
	var jt := func(g: float) -> float: return -4.0 - 46.0 * out_cubic(minf(1.0, g * 2.2)) - 10.0 * g
	var jb := func(g: float) -> float: return -2.0 - 50.0 * in_quad(seg(g, 0.35, 1.0))
	var on := func(g: float) -> bool: return g > 0.0 and g < 1.0 and float(jb.call(g)) - float(jt.call(g)) > 2.0
	var gg := func(t: float) -> float: return seg(t, SEED, SEED + 0.5)
	keyn(jet, "material:shader_parameter/top", func(t: float) -> float: return jt.call(gg.call(t)), 0.0, SEED + 0.55)
	keyn(jet, "material:shader_parameter/bot", func(t: float) -> float: return jb.call(gg.call(t)), 0.0, SEED + 0.55)
	keyn(jet, "material:shader_parameter/r", func(t: float) -> float: return (1.0 + 2.4 * (1.0 - gg.call(t))) if on.call(gg.call(t)) else 0.0, 0.0, SEED + 0.55)
	keyn(jet_l, "material:shader_parameter/a", func(t: float) -> Vector2: return Vector2(0, jb.call(gg.call(t))), 0.0, SEED + 0.55)
	keyn(jet_l, "material:shader_parameter/b", func(t: float) -> Vector2: return Vector2(0, jt.call(gg.call(t))), 0.0, SEED + 0.55)
	keyn(jet_l, "material:shader_parameter/k", func(t: float) -> float: return 0.55 * (1.0 - gg.call(t)) if on.call(gg.call(t)) else 0.0, 0.0, SEED + 0.55)
	keyn(jet_top, "position", func(t: float) -> Vector2: return Vector2(0, floorf(jt.call(gg.call(t)))) + Vector2(0.5, 0.5), 0.0, SEED + 0.55)
	keyn(jet_top, "material:shader_parameter/arm", func(t: float) -> float: return (4.0 * (1.0 - gg.call(t)) + 1.0) if on.call(gg.call(t)) else 0.0, 0.0, SEED + 0.55)
	keyn(jet_tl, "position", func(t: float) -> Vector2: return Vector2(0, jt.call(gg.call(t))), 0.0, SEED + 0.55)
	keyn(jet_tl, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * roundf(4.0 * (1.0 - gg.call(t)) + 1.0), 0.0, SEED + 0.55)
	keyn(jet_tl, "material:shader_parameter/alpha", func(t: float) -> float: return 0.5 * (1.0 - gg.call(t)) if on.call(gg.call(t)) else 0.0, 0.0, SEED + 0.55)
	burst("ReleaseLight", SEED, Vector2(0, -16), 76, C[5], 0.85, 0.55)
	burst("ReleaseWhite", SEED, Vector2(0, -6), 28, Color.WHITE, 0.8, 0.12)

	var mote := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		mote.set_pixel(0, y, Color(0.55, 0.55, 0.55) if y < 2 else Color.WHITE)
	var m_o := {"at": Vector2(0, -6), "amount": 10, "lifetime": 0.6, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "emit": {"box": Vector2(2, 4)}, "dir": -90, "spread": 12, "speed": [80, 170], "drag": 0.6, "align": true,
		"initial": gradient([Color.WHITE, C[6]])}
	var motes := particles("Motes", m_o.merged({"texture": asset("mote.png", mote)}))
	emit(motes, SEED)
	var motes_l := particles("MoteLight", m_o.merged({"texture": "glow8", "layer": "light", "modulate": Color(1, 1, 1, 0.4),
		"alpha_curve": [[0, 1], [1, 0]]}))
	emit(motes_l, SEED)

	var tw := func(u: float) -> float: return (0.6 + 0.4 * sin(u * 14.0)) * minf(1.0, 3.0 * (1.0 - u))
	for k in 2:
		var col: Color = Color.WHITE if k == 0 else C[6]
		var strip := star_strip(10, func(u: float) -> float: return 1.7 * float(tw.call(u)), col, col if k == 0 else C[5])
		var s_o := {"at": Vector2(0, -3), "amount": 8, "lifetime": 0.8, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "dir": -90, "spread": 81, "speed": [40, 120], "drag": 1.6, "gravity": Vector2(0, -5),
			"alpha_curve": [[0, 0.5], [0.3, 0.5], [1, 0]]}
		var stars := particles("Stars%d" % k, s_o.merged({"texture": asset("star%d.png" % k, strip)}))
		flip(stars, 10)
		emit(stars, SEED)
		var stars_l := particles("StarLight%d" % k, s_o.merged({"texture": "glow16", "layer": "light", "modulate": Color(col, 0.45)}))
		stars_l.process_material.anim_speed_min = 1.0
		stars_l.process_material.anim_speed_max = 1.0
		emit(stars_l, SEED)

	# ---- dew splashes up where each sprout breaks the floor (sites binned by when the ring reaches them)
	var dew_strip := star_strip(8, func(u: float) -> float: return 1.0 if u < 0.35 else (0.0 if u < 0.85 else -1.0), Color.WHITE, C[6])
	var dew_tex := asset("dew.png", dew_strip)
	var bins := {}
	for s in sites:
		var b := int(floorf((s.t0 - SEED) / 0.08))
		if not bins.has(b):
			bins[b] = []
		bins[b].append(s)
	for b in bins:
		var pts := PackedVector2Array()
		var t0 := 0.0
		for s in bins[b]:
			pts.append(Vector2(s.x, s.z * SY - 1.0))
			t0 += s.t0 / bins[b].size()
		var dew := particles("Dew%d" % b, {"amount": 3 * pts.size(), "lifetime": 0.6, "life_random": 0.5, "one_shot": true,
			"explosiveness": 0.7, "emitting": false, "emit": {"points": pts}, "dir": -90, "spread": 20, "speed": [15, 40], "drag": 1.6,
			"texture": dew_tex})
		flip(dew, 8)
		emit(dew, t0)

	# ---- dew rising off the glowing floor behind the ring, in three bands that start as the front passes them
	var ember_ramp := gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7])
	var bands := [[0.0, 35.0, 5], [35.0, 70.0, 14], [70.0, 104.0, 23]]
	var bi := 0
	for bd in bands:
		var pts := PackedVector2Array()
		for i in 96:
			var a := rng.randf_range(0, TAU)
			var dd := sqrt(rng.randf_range(bd[0] * bd[0], bd[1] * bd[1]))
			pts.append(Vector2(cos(a) * dd, sin(a) * dd * SY - 1.0))
		var e_o := {"amount": bd[2], "lifetime": 1.0, "life_random": 0.5, "emit": {"points": pts}, "dir": -90, "spread": 15,
			"speed": [10, 30], "gravity": Vector2(0, -30), "drag": 1.6, "ramp": ember_ramp, "preprocess": 0.0, "alpha_curve": [[0, 1], [0.6, 0.8], [1, 0]],
			"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}}
		var em := particles("Embers%d" % bi, e_o.merged({"texture": "dot1", "back": true}))
		var on_t := maxf(SEED + 0.1, passed(bd[0] + 4.0))
		emit(em, on_t, 1.9)
		var eml := particles("EmberLight%d" % bi, e_o.merged({"texture": "glow8", "layer": "light", "modulate": Color(1, 1, 1, 0.25)}))
		emit(eml, on_t, 1.9)
		bi += 1


## The original's Lights.add() on its frames: from the frame it's added, its radius shrinks to 0.55 r and its strength
## falls as the square of the life left.
func burst(name: String, t0: float, at: Vector2, r0: float, c: Color, k: float, life: float) -> void:
	var lg := glow(name, r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": at})
	keyn(lg, "material:shader_parameter/radius", func(t: float) -> float: return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0 - 1.0 / 30.0, t0 + life + 0.04)
	keyn(lg, "material:shader_parameter/alpha", func(t: float) -> float: return k * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 - 1e-4 else 0.0, t0 - 1.0 / 30.0, t0 + life + 0.04)
