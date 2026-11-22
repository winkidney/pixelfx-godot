# reimagined-from: src/fx/shadow/curse.js@882315bee79ce16c16f956a0a15a80c3d3a906c3
# Curse: Wisps gather over the head, a skull stamps down with a flash, its eyes burn as the curse floods the body violet, then it cracks and crumbles.
# one-shot, 3.40 s, 112x124 canvas, origin [56.0, 108.0], backdrop ground, stand-in 2
# ramp bone: #170f26 #4a3a6e #7f6ea6 #b3a4d4 #e2d8f6
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The skull is a canvas shader over the original's hand-drawn pixels (fx/shadow/_curse_skull.gdshader, keyed from its
# stamp, squash, bob, shake and cracks), drawn twice: whole, and its bone again above the light layer (the original
# keeps bone out of the glow). The flood is a shader over the stand-in's own pixels (_curse_flood.gdshader: a violet
# wash down the body with a bright front, a sweeping band, a crawling edge). Particles: motes and soot spiralling in,
# the stamp's sparks and soot, eye fire, embers, smoke, vapour and the curse dripping onto the head, stars on the
# body; at the break bone chunks and grit that land on the floor, dust and the last of the fire. Rings, a sparkle and
# glows on the original's beats.
extends "res://build/fx/shadow/_shadow.gd"

const SY := -60.0
const STAMP := 0.55
const CRACK := 1.72
const BREAK := 1.98
const HEAD := -38.0
const EYES := [Vector2(-3.5, 1.5), Vector2(3.5, 1.5)]
const SKULL := [
	"......kkkkk......",
	"....kkhhhhlkk....",
	"...khhhhhhlllk...",
	"..khhhhhllllllk..",
	".khhhhlllllllmmk.",
	".khhhllllllllmmk.",
	"khhllllllllllmmdk",
	"khlldddllldddmmdk",
	"khleeeeelleeeeedk",
	"kleeeeeelleeeeedk",
	"kleeeeeemleeeeedk",
	"kmleeeelmmleeedkk",
	".kmmlllmnnmlmddk.",
	"..kmmlmnnnnmddk..",
	"..kdmlllmmlmddk..",
	"...kgtgtgtgtgk...",
	"...kdgtgtgtgdk...",
	"....kkkkkkkkk....",
]
const CRACK_PATHS := [[[8, 1], [7, 3], [8, 5], [6, 6], [5, 7]], [[9, 1], [10, 3], [10, 4], [12, 6], [12, 7]], [[4, 3], [3, 5], [2, 6]], [[13, 4], [14, 6]]]

var K: PackedColorArray


static func jround(v: float) -> float:
	return floorf(v + 0.5)


## Front particles: the original draws them after the skull, so they go over its lifted bone.
static func front(n: CanvasItem) -> CanvasItem:
	n.z_index = OVER_LIGHT + 1
	return n


func skull_texture() -> Texture2D:
	var codes := {".": 0, "k": 1, "d": 2, "m": 3, "l": 4, "h": 5, "e": 6, "n": 7, "t": 8, "g": 9}
	var cracks := {}
	for path in CRACK_PATHS:
		var n: int = path.size() - 1
		for k in n:
			var a: Array = path[k]
			var b: Array = path[k + 1]
			var steps: int = maxi(absi(b[0] - a[0]), absi(b[1] - a[1]))
			for st in steps + 1:
				var x := int(jround(a[0] + (b[0] - a[0]) * st / float(steps)))
				var y := int(jround(a[1] + (b[1] - a[1]) * st / float(steps)))
				var kk := y * 17 + x
				if not cracks.has(kk):
					cracks[kk] = (k + st / float(maxi(1, steps))) / float(n)
	var img := Image.create(17, 18, false, Image.FORMAT_RGBA8)
	for v in 18:
		for u in 17:
			var ch: String = SKULL[v][u]
			var ck := 0
			if cracks.has(v * 17 + u):
				ck = int(roundf(float(cracks[v * 17 + u]) * 250.0)) + 1
			img.set_pixel(u, v, Color8(codes[ch], ck, 0, 255))
	return asset("skull.png", img)


## The original's lights: a glow that shrinks a little and dies (k * (life left)^2) from t0.
func light_burst(name: String, t0: float, at: Vector2, r0: float, c: Color, k: float, life: float) -> void:
	var lg := glow(name, r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": at})
	keyf(lg, "material:shader_parameter/radius", func(t: float): return r0 * (0.6 + 0.4 * (1.0 - seg(t, t0, t0 + life))), t0, t0 + life)
	keyf(lg, "material:shader_parameter/alpha", func(t: float): return k * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 else 0.0, t0 - 0.034, t0 + life + 0.01)


func skull_s(t: float) -> float:
	var u := (t - STAMP) / 0.1
	return 1.7 - 0.7 * in_quad(u) if u < 1.0 else 1.0


func skull_sq(t: float) -> float:
	var land := t - STAMP - 0.1
	return 1.0 - 0.16 * exp(-land * 18.0) * cos(land * 40.0) if land > 0.0 else 1.0


func skull_off(t: float) -> Vector2:
	var land := t - STAMP - 0.1
	var shake := (t - CRACK) * 4.0 if t > CRACK else 0.0
	return Vector2(jround(sin(t * 61.0) * shake), jround(sin(t * 3.4) * 1.2) if land > 0.0 else 0.0)


func burn(t: float) -> float:
	return smooth(STAMP + 0.1, STAMP + 0.25, t) * (1.0 + 0.4 * smooth(CRACK, BREAK, t))


func make() -> void:
	K = root.ramps.bone
	ground()
	var hot := [Color.WHITE, C[7], C[6], C[5]]

	# ---------------------------------------------------------------- the gathering
	var gg := glow("GatherGlow", 31, {"radius": 14, "color": C[5], "alpha": 0.2}, {"at": Vector2(0, SY)})
	keyf(gg, "material:shader_parameter/radius", func(t: float): return 14.0 + 16.0 * t / STAMP, 0.0, STAMP)
	keyf(gg, "material:shader_parameter/alpha", func(t: float): return 0.2 + 0.5 * t / STAMP if t < STAMP else 0.0, 0.0, STAMP + 0.034)
	var gr := ring("GatherRing", 35, {"radius": 34, "thickness": 1, "color": C[3]}, {"at": Vector2(0, SY)})
	keyf(gr, "material:shader_parameter/radius", func(t: float): return 4.0 + 30.0 * (1.0 - in_quad(t / STAMP)), 0.0, STAMP)
	key(gr, "material:shader_parameter/color", [[0.0, C[3]], [0.4 * STAMP, C[4]], [0.7 * STAMP, C[5]]], "nearest")
	show(gr, 0.15 * STAMP, STAMP)

	var swirl := group("Swirl", {"at": Vector2(0, SY)})
	swirl.scale = Vector2(1, 0.8)
	var mo := {"parent": swirl, "local": true, "amount": 30, "lifetime": 0.42, "texture": "streak4", "align": true,
		"emit": {"ring": [44, 22]}, "tangential": [140, 200], "radial": [-340, -260], "initial": gradient(hot),
		"alpha_curve": [[0, 1], [0.65, 1], [1, 0]]}
	var motes := particles("Motes", mo)
	life_rand(motes, 0.3)
	var mol := mo.duplicate()
	mol.layer = "light"
	mol.texture = "glow8"
	mol.align = false
	mol.alpha_curve = [[0, 0.4], [1, 0.0]]
	var mlight := particles("MoteLight", mol)
	life_rand(mlight, 0.3)
	mlight.seed = motes.seed
	for m in [motes, mlight]:
		emit(m, 0.0, STAMP - 0.05)
		key(m, "amount_ratio", [[0.0, 0.45], [STAMP, 1.0]])
		show(m, 0.0, STAMP)
	var soot := gradient([Color(C[3].lerp(C[2], 0.5), 0.0), Color(C[3].lerp(C[2], 0.5), 0.7), Color(C[1].lerp(C[0], 0.3), 0.6), Color(C[1].lerp(C[0], 0.3), 0.0)], [0.0, 0.1, 0.6, 1.0], true)
	var gs := particles("GatherSoot", {"parent": swirl, "local": true, "layer": "soft", "back": true, "amount": 8, "lifetime": 0.6,
		"texture": "disc9", "scale": [0.7, 1.2], "emit": {"ring": [34, 20]}, "tangential": [30, 60], "radial": [-120, -80], "ramp": soot})
	emit(gs, 0.0, STAMP - 0.05)
	show(gs, 0.0, STAMP)

	# ---------------------------------------------------------------- the stamp
	light_burst("StampLight", STAMP, Vector2(0, SY), 64, C[5], 1.0, 0.35)
	light_burst("StampWhite", STAMP, Vector2(0, SY), 30, Color.WHITE, 1.0, 0.1)
	light_burst("HeadLight", STAMP, Vector2(0, HEAD + 12), 40, C[4], 0.6, 0.5)
	var sp := {"at": Vector2(0, SY), "amount": 22, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0, "texture": "streak4",
		"align": true, "emit": {"circle": 6}, "spread": 180, "speed": [80, 160], "gravity": Vector2(0, 427), "drag": 2.2,
		"ramp": gradient([Color.WHITE, C[7], C[6], C[5]], [0.0, 0.4, 0.7, 0.9])}
	var sparks := particles("Sparks", sp)
	life_rand(sparks, 0.6)
	front(sparks)
	var spl := sp.duplicate()
	spl.layer = "light"
	spl.texture = "glow8"
	spl.align = false
	spl.ramp = gradient([Color(Color.WHITE, 0.45), Color(C[6], 0.0)], [0.0, 1.0], true)
	var sparkl := particles("SparkLight", spl)
	life_rand(sparkl, 0.6)
	sparkl.seed = sparks.seed
	emit(sparks, STAMP)
	emit(sparkl, STAMP)
	var bs := particles("StampSoot", {"at": Vector2(0, SY), "layer": "soft", "back": true, "amount": 6, "lifetime": 0.9, "one_shot": true,
		"explosiveness": 1.0, "texture": "disc9", "scale": [0.8, 1.3], "scale_curve": [[0, 0.7], [1, 1.4]], "emit": {"box": Vector2(8, 6)},
		"spread": 180, "speed": [20, 45], "drag": 1.3, "gravity": Vector2(0, -18), "ramp": soot})
	life_rand(bs, 0.33)
	emit(bs, STAMP)
	for half in [["ShockOuter", Color.WHITE, 0.0], ["ShockInner", C[6], 1.0]]:
		var inner: float = half[2]
		var rr := ring(half[0], 38, {"radius": 10, "thickness": 1, "color": half[1]}, {"at": Vector2(0, SY + 2)})
		var t0 := STAMP + 0.08
		var rad := func(t: float) -> float: return 10.0 + 26.0 * out_cubic((t - t0) / 0.3)
		var wid := func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - (t - t0) / 0.3))
		keyf(rr, "material:shader_parameter/radius", func(t: float): return rad.call(t) - inner * wid.call(t) * 0.5, t0, t0 + 0.3)
		keyf(rr, "material:shader_parameter/thickness", func(t: float): return maxf(0.6, wid.call(t) * 0.5), t0, t0 + 0.3)
		keyf(rr, "material:shader_parameter/alpha", func(t: float): return clampf(1.2 - (t - t0) / 0.3, 0.0, 1.0), t0, t0 + 0.3)
		show(rr, t0, t0 + 0.3)
	var spk := shape("Sparkle", shadow_shader("curse_sparkle"), Vector2(41, 41), {"arm": 0.0, "c": C[7], "tip": C[5], "heart": Color.WHITE}, {"at": Vector2(0.5, SY + 0.5)})
	keyf(spk, "material:shader_parameter/arm", func(t: float): return 14.0 * (1.0 - (t - STAMP) / 0.12) if t >= STAMP else 0.0, STAMP - 0.034, STAMP + 0.13)
	front(spk)
	var spkl := glow("SparkleLight", 33, {"radius": 32, "color": C[7], "alpha": 0.0}, {"at": Vector2(0.5, SY + 0.5)})
	keyf(spkl, "material:shader_parameter/radius", func(t: float): return 4.0 + 2.0 * roundf(14.0 * (1.0 - (t - STAMP) / 0.12)), STAMP, STAMP + 0.12)
	keyf(spkl, "material:shader_parameter/alpha", func(t: float): return 0.6 if t >= STAMP and t < STAMP + 0.12 else 0.0, STAMP - 0.034, STAMP + 0.13, 30.0, "nearest")

	# ---------------------------------------------------------------- the skull
	var tex := skull_texture()
	var sk := {"tex": tex, "sy": SY, "k0": K[0], "k1": K[1], "k2": K[2], "k3": K[3], "k4": K[4], "c0": C[0], "c5": C[5], "c6": C[6], "white": Color.WHITE}
	var skull := shape("Skull", shadow_shader("curse_skull"), Vector2(40, 46), sk, {"at": Vector2(0, SY)})
	sk.no_sockets = 1.0
	var bone := shape("Bone", shadow_shader("curse_skull"), Vector2(40, 46), sk, {"at": Vector2(0, SY)})
	over_light(bone)
	for n in [skull, bone]:
		keyf(n, "material:shader_parameter/s", skull_s, STAMP, BREAK)
		keyf(n, "material:shader_parameter/sq", skull_sq, STAMP, BREAK)
		keyf(n, "material:shader_parameter/ox", func(t: float): return skull_off(t).x, STAMP, BREAK, 30.0, "nearest")
		keyf(n, "material:shader_parameter/oy", func(t: float): return skull_off(t).y, STAMP, BREAK, 30.0, "nearest")
		keyf(n, "material:shader_parameter/white_on", func(t: float): return 1.0 if t < STAMP + 0.067 else 0.0, STAMP, STAMP + 0.1, 30.0, "nearest")
		keyf(n, "material:shader_parameter/crack", func(t: float): return smooth(CRACK, BREAK, t), CRACK, BREAK)
	show(skull, STAMP, BREAK)
	show(bone, STAMP + 0.067, BREAK)
	var sg := glow("SkullGlow", 27, {"radius": 26, "color": C[4], "alpha": 0.25}, {"at": Vector2(0, SY)})
	show(sg, STAMP, BREAK)

	# the eyes burn: a white pupil, two licking tongues each, a violet light; they ride the skull's bob and shake
	var eyes := group("Eyes", {"at": Vector2.ZERO})
	keyf(eyes, "position", skull_off, STAMP, BREAK, 30.0, "nearest")
	show(eyes, STAMP + 0.1, BREAK)
	var fire := gradient([C[7], C[6], C[5], C[4], Color(C[4], 0.4)], [0.0, 0.3, 0.6, 0.8, 0.9])
	var i := 0
	for e in EYES:
		var at := Vector2(e.x, SY + e.y)
		var cell := at.floor()
		front(rect("Pupil%d" % i, Rect2(cell, Vector2(1, 1)), Color.WHITE, {"parent": eyes}))
		front(rect("PupilEdge%d" % i, Rect2(cell + Vector2(-1, 0), Vector2(1, 1)), C[6], {"parent": eyes}))
		var fl := particles("EyeFire%d" % i, {"parent": eyes, "local": true, "at": cell + Vector2(0.5, -0.5), "amount": 10, "lifetime": 0.16,
			"texture": "dot1", "emit": {"box": Vector2(0.7, 0.2)}, "dir": -90, "spread": 10, "speed": [16, 30], "ramp": fire})
		front(fl)
		key(fl, "amount_ratio", [[STAMP + 0.1, 0.4], [STAMP + 0.25, 1.0]])
		keyf(fl, "process_material:initial_velocity_max", func(t: float): return 30.0 * (0.6 + 0.4 * burn(t) / 1.4), STAMP, BREAK)
		emit(fl, STAMP + 0.1, BREAK)
		var el := glow("EyeLight%d" % i, 9, {"radius": 8, "color": C[5], "alpha": 0.0}, {"parent": eyes, "at": at})
		keyf(el, "material:shader_parameter/alpha", func(t: float): return 0.5 * burn(t), STAMP + 0.1, BREAK)
		i += 1

	# it burns: embers and thin smoke off the eyes, a violet haze, the curse dripping onto the head, stars on the body
	var eye_pts := PackedVector2Array([Vector2(-3.5, SY - 1.5), Vector2(3.5, SY - 1.5)])
	var em := {"amount": 14, "lifetime": 0.9, "texture": "dot1", "emit": {"points": eye_pts}, "dir": -90, "spread": 20, "speed": [20, 45],
		"drag": 1.6, "gravity": Vector2(0, -30), "ramp": gradient([C[6], Color(C[6], 0.5), C[7], Color.WHITE], [0.0, 0.25, 0.4, 0.7]).duplicate(),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}}
	em.ramp = gradient([Color.WHITE, C[7], C[6], Color(C[6], 0.5)], [0.0, 0.4, 0.7, 0.85])
	var embers := particles("Embers", em)
	life_rand(embers, 0.44)
	front(embers)
	var eml := em.duplicate()
	eml.layer = "light"
	eml.texture = "glow8"
	eml.ramp = gradient([Color(Color.WHITE, 0.35), Color(C[6], 0.0)], [0.0, 1.0], true)
	var emlight := particles("EmberLight", eml)
	life_rand(emlight, 0.44)
	emlight.seed = embers.seed
	var thin := gradient([Color(C[3].lerp(C[2], 0.5), 0.0), Color(C[3].lerp(C[2], 0.5), 0.6), Color(C[1].lerp(C[0], 0.3), 0.4), Color(C[1].lerp(C[0], 0.3), 0.0)], [0.0, 0.1, 0.6, 1.0], true)
	var es := particles("EyeSmoke", {"layer": "soft", "back": true, "amount": 11, "lifetime": 0.8, "texture": "disc5", "scale": [0.6, 1.0],
		"scale_curve": [[0, 0.8], [1, 1.8]], "emit": {"points": eye_pts}, "dir": -90, "spread": 15, "speed": [14, 26], "drag": 1.3,
		"gravity": Vector2(0, -18), "ramp": thin})
	life_rand(es, 0.37)
	var vap := particles("Vapour", {"layer": "soft", "back": true, "at": Vector2(0, SY), "amount": 6, "lifetime": 0.8, "texture": "disc13",
		"scale": [0.75, 1.2], "scale_curve": [[0, 0.5], [1, 1.25]], "emit": {"box": Vector2(7, 6)}, "spread": 180, "speed": [4, 12],
		"drag": 4.0, "initial": gradient([C[3], C[4]]), "alpha_curve": [[0, 0.45], [0.5, 0.18], [1, 0.0]]})
	life_rand(vap, 0.37)
	var vapl := particles("VapourLight", {"layer": "light", "at": Vector2(0, SY), "amount": 6, "lifetime": 0.8, "texture": "glow32",
		"scale": [0.75, 1.2], "scale_curve": [[0, 0.5], [1, 1.25]], "emit": {"box": Vector2(7, 6)}, "spread": 180, "speed": [4, 12],
		"drag": 4.0, "initial": gradient([C[4], C[4]]), "alpha_curve": [[0, 0.16], [1, 0.0]]})
	life_rand(vapl, 0.37)
	vapl.seed = vap.seed
	var drip := particles("Drip", {"at": Vector2(0, SY + 9), "amount": 5, "lifetime": 0.4, "texture": "streak4", "align": true,
		"emit": {"box": Vector2(4, 0.5)}, "dir": 90, "spread": 6, "speed": [40, 70], "initial": gradient([C[6], C[5]]),
		"alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	life_rand(drip, 0.37)
	front(drip)
	var dsoot := particles("DripSoot", {"layer": "soft", "back": true, "at": Vector2(0, SY + 9), "amount": 6, "lifetime": 0.7, "texture": "disc5",
		"scale": [0.5, 0.9], "scale_curve": [[0, 0.8], [1, 1.6]], "emit": {"box": Vector2(3.5, 0.5)}, "dir": 90, "spread": 8,
		"speed": [14, 26], "drag": 1.3, "gravity": Vector2(0, -18), "ramp": thin})
	life_rand(dsoot, 0.36)
	var stars := particles("Stars", {"at": Vector2(0, -19), "amount": 3, "lifetime": 0.5, "texture": "star5", "emit": {"box": Vector2(12, 15)},
		"dir": -90, "speed": [6, 6], "scale": [0.6, 1.0], "color": C[6], "alpha_curve": [[0, 1], [0.6, 0.6], [0.8, 1], [1, 0]]})
	life_rand(stars, 0.4)
	front(stars)
	for e in [embers, emlight, es, vap, vapl, drip, dsoot]:
		emit(e, STAMP, BREAK)
	emit(stars, STAMP + 0.3, BREAK)

	# ---------------------------------------------------------------- the flood down the body
	var stand: Texture2D = load(EFFECT.STAND_INS[2])
	var fsize := Vector2(stand.get_width() + 4, stand.get_height() + 4)
	var fat := Vector2(0, -stand.get_height() / 2.0)
	var fp := {"tex": stand, "c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6], "c7": C[7], "translucent": true}
	var wash := shape("Flood", shadow_shader("curse_flood"), fsize, fp, {"at": fat})
	fp.mode = 1.0
	fp.translucent = false
	var edge := shape("FloodEdge", shadow_shader("curse_flood"), fsize, fp, {"at": fat})
	var flood := func(t: float) -> float: return smooth(STAMP + 0.04, STAMP + 0.42, t)
	var ebb := func(t: float) -> float: return 1.0 - smooth(BREAK + 0.15, BREAK + 0.75, t)
	var pulse := func(t: float) -> float: return 0.85 + 0.15 * sin(t * 9.0)
	var t_on := STAMP + 0.04
	var t_off := BREAK + 0.75
	for n in [wash, edge]:
		keyf(n, "material:shader_parameter/flood", flood, t_on, t_off)
		keyf(n, "material:shader_parameter/k", ebb, t_on, t_off)
		show(n, t_on, t_off)
	keyf(wash, "material:shader_parameter/pulse", pulse, t_on, t_off)
	keyf(wash, "material:shader_parameter/band", func(t: float): return fmod((t - STAMP) * 1.3, 1.4) - 0.2, t_on, t_off, 30.0, "nearest")
	keyf(edge, "material:shader_parameter/crawl", func(t: float): return t, t_on, t_off)
	var bg := glow("BodyGlow", 31, {"radius": 30, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, HEAD + 38 * 0.45)})
	keyf(bg, "material:shader_parameter/alpha", func(t: float): return 0.3 * ebb.call(t) * pulse.call(t) if flood.call(t) > 0.0 else 0.0, t_on - 0.034, t_off)

	# ---------------------------------------------------------------- the break
	light_burst("BreakLight", BREAK, Vector2(0, SY), 40, C[5], 0.5, 0.25)
	var bone_pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	while bone_pts.size() < 80:
		var x := rng.randf_range(-8.5, 8.5)
		var y := rng.randf_range(-9, 9)
		var u := int(floorf(x + 8.5))
		var v := int(floorf(y + 9))
		if u >= 0 and u < 17 and v >= 0 and v < 18 and SKULL[v][u] != ".":
			bone_pts.append(Vector2(x, y))
	var chunks := particles("Chunks", {"at": Vector2(0, SY), "amount": 24, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0,
		"texture": "dot2", "emit": {"points": bone_pts}, "dir": -90, "spread": 90, "speed": [0, 45], "radial_speed": [20, 48],
		"gravity": Vector2(0, 807), "drag": 0.4, "spin": [-600, 600], "scale": [0.6, 1.2], "initial": gradient([K[1], K[2], K[3], K[4]]),
		"alpha_curve": [[0, 1], [0.85, 1], [1, 0]], "collide": {"bounce": 0.35, "friction": 0.6, "size": 2}})
	life_rand(chunks, 0.33)
	front(chunks)
	emit(chunks, BREAK)
	var grit := particles("Grit", {"at": Vector2(0, SY), "amount": 26, "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0,
		"texture": "dot1", "emit": {"box": Vector2(7, 8)}, "dir": -90, "spread": 75, "speed": [20, 65], "gravity": Vector2(0, 950),
		"initial": gradient([K[2], K[3], K[3], K[4]]), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]], "collide": {"bounce": 0.15, "friction": 0.9}})
	life_rand(grit, 0.38)
	front(grit)
	emit(grit, BREAK)
	var dustr := gradient([Color(K[2].lerp(K[1], 0.4), 0.0), Color(K[2].lerp(K[1], 0.4), 0.7), Color(K[1].lerp(K[0], 0.5), 0.5), Color(K[1].lerp(K[0], 0.5), 0.0)], [0.0, 0.1, 0.6, 1.0], true)
	var dust := particles("Dust", {"at": Vector2(0, SY), "layer": "soft", "back": true, "amount": 7, "lifetime": 0.8, "one_shot": true,
		"explosiveness": 0.85, "texture": "disc7", "scale": [0.6, 1.1], "scale_curve": [[0, 0.7], [1, 1.5]], "emit": {"box": Vector2(7, 7)},
		"spread": 180, "speed": [10, 30], "drag": 1.3, "gravity": Vector2(0, -18), "ramp": dustr})
	life_rand(dust, 0.37)
	emit(dust, BREAK)
	var land := particles("LandDust", {"at": Vector2(0, -2), "layer": "soft", "back": true, "amount": 14, "lifetime": 0.6, "texture": "disc5",
		"scale": [0.6, 1.0], "scale_curve": [[0, 0.7], [1, 1.5]], "emit": {"box": Vector2(22, 0.5)}, "dir": -90, "spread": 60,
		"speed": [4, 12], "drag": 1.3, "ramp": dustr})
	life_rand(land, 0.4)
	emit(land, BREAK + 0.3, BREAK + 0.75)
	var flame := gradient([Color.WHITE, C[7], C[6], C[5], C[4], C[3], C[2], C[1]], [0.0, 0.08, 0.2, 0.35, 0.5, 0.65, 0.8, 0.92])
	var lastfire := particles("LastFire", {"at": Vector2.ZERO, "amount": 2, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0,
		"texture": "disc5", "emit": {"points": PackedVector2Array([Vector2(-3.5, SY + 1.5), Vector2(3.5, SY + 1.5)])}, "dir": -90,
		"spread": 12, "speed": [30, 32], "gravity": Vector2(0, -95), "drag": 3.2, "scale_curve": [[0, 0.6], [0.15, 1.0], [1, 0.45]], "ramp": flame})
	front(lastfire)
	emit(lastfire, BREAK)
