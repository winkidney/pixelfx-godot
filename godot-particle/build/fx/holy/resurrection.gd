# reimagined-from: src/fx/holy/resurrection.js@3e58ca3ab5ef83a5080fa92aa74305a065f927c2
# Resurrection: Light pours down on the fallen and life climbs back up the body; wings of light unfold, a halo forms, one great wingbeat, then the wings scatter into feathers.
# one-shot, 4.80 s, 192x160 canvas, origin [96.0, 140.0], backdrop ground
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# ramp ash: #16131c #26222f #3a3546 #524c5e #6e6878 #8c8796
# The shaft is a shader (fx/holy/_res_shaft.gdshader, soft, behind) built from the original's own seeded rays: a
# translucent veil, the two brightest rays dotted with light running down them, the pour's white head and lit dust
# motes; its light (_res_shaft_light) adds the gold and the pool round the feet. The body is redrawn from the
# stand-in's own pixels (_res_body): ash above the climbing line of light, white at it, warmed below; then the hero
# flash. The wings are the original's feather() for each of 18 quills a side (_res_feathers), posed every frame from
# its arm, opening, wingbeat and flex, with the white bone of the leading edge and the downstroke's tip trails; the
# feathers they scatter into (and those the beat shakes loose) replay the original's flutter (thrown, braking,
# rocking as they sink) into the same shader, each with its glow. The halo (_res_halo) forms from the front round,
# a glint running round it. Particles: streaks pouring down, stars in the shaft, bits of light peeling off the body
# as life climbs it, bursts of stars and sparks on each beat, motes spiralling into the halo, embers and stars off the
# wings, the gust along the floor; the original's flashes of light on every beat.
extends "res://build/fx/holy/_holy.gd"

const TOP := -140.0
const POUR := 0.34
const CL0 := 0.5
const CL1 := 1.15
const W0 := 1.1
const H0 := 1.24
const H1 := 1.5
const B0 := 1.95
const B1 := 2.25
const B2 := 2.37
const B3 := 2.8
const SC := 2.95
const HX := 0.0
const HY := -47.0
const HRX := 9.5
const HRY := 2.6
const STOP := -38.0
const NFR := 145
const SHOULDER := Vector2(4, -20)
const ARM_OPEN := [Vector2(0, 0), Vector2(7, -9), Vector2(15, -19), Vector2(20, -27)]
const ARM_FOLD := [Vector2(0, 0), Vector2(2, -2), Vector2(3, -3), Vector2(4, -3)]
const QUILLS := [
	[0.14, 1.35, 11, 2.6, 1], [0.26, 1.12, 14, 2.8, 1], [0.38, 0.88, 17, 3, 1], [0.5, 0.62, 19, 3.1, 1], [0.62, 0.35, 21, 3.2, 1], [0.72, 0.08, 23, 3.3, 1],
	[0.8, -0.2, 26, 3.4, 0], [0.85, -0.45, 29, 3.5, 0], [0.9, -0.72, 31, 3.6, 0], [0.95, -1, 30, 3.6, 0], [1, -1.3, 26, 3.4, 0],
	[0.22, 1.2, 7, 2.2, 2], [0.34, 0.98, 8, 2.3, 2], [0.46, 0.75, 9, 2.4, 2], [0.58, 0.5, 10, 2.5, 2], [0.7, 0.22, 10, 2.5, 2], [0.81, -0.1, 11, 2.6, 2], [0.92, -0.5, 11, 2.6, 2],
]
const FLEX := [1.0, 0.5, 0.3]
# the original's own draws from Rng(5) in create(): the shaft's rays (offset, width, brightness, shimmer rate, phase),
# its dust motes (q, y, speed, sway, phase, rate) and when each quill lets go (right wing, left wing)
const RAYS := [[-0.7196, 0.1773, 0.6489, 2.7464, 0.5349], [-0.4353, 0.172, 0.7561, 3.3112, 1.4415], [-0.1052, 0.1741, 0.8473, 1.5276, 2.9242], [0.1181, 0.1897, 0.6797, 3.0106, 4.5458], [0.4106, 0.1019, 0.9071, 1.9166, 1.7129], [0.6897, 0.147, 0.9962, 1.9909, 0.5086]]
const MOTES := [[0.6972, 0.317, 6.8529, 2.3743, 1.7089, 0.9089], [-0.5655, 0.8692, 9.0565, 2.1819, 3.2142, 1.2441], [0.2983, 0.1396, 8.4523, 1.6397, 1.9804, 1.2231], [0.2188, 0.0081, 10.5241, 1.2147, 2.1998, 1.2997], [-0.5016, 0.1752, 9.8357, 1.102, 6.2724, 0.611], [-0.2979, 0.7585, 6.1996, 1.7894, 0.4824, 0.6639], [0.4699, 0.5247, 5.7741, 2.2741, 0.3112, 1.1878], [0.9077, 0.2852, 7.7322, 2.1417, 5.3207, 1.0631], [0.913, 0.7025, 7.7813, 0.7978, 1.8476, 1.0236], [-0.69, 0.2521, 9.368, 0.8494, 0.503, 0.8614], [0.6112, 0.6432, 6.8877, 0.7757, 1.8254, 1.3655], [-0.3471, 0.7028, 9.2091, 0.784, 4.9229, 1.3454], [0.2114, 0.1114, 6.5325, 1.3254, 0.3258, 0.937], [0.8356, 0.3113, 9.3677, 0.6936, 5.1297, 0.6805], [0.0239, 0.8269, 5.4681, 1.6737, 0.634, 0.8911], [0.3269, 0.2542, 8.7691, 1.0317, 1.5916, 1.3877], [0.2863, 0.4529, 9.1961, 0.6696, 3.8858, 1.1245], [-0.9613, 0.1447, 6.3354, 1.2028, 4.0362, 1.3591], [0.187, 0.8686, 9.4137, 1.1102, 0.4006, 0.736], [-0.9168, 0.227, 10.2364, 1.4136, 0.2649, 1.2218], [0.1724, 0.2861, 10.2602, 1.9942, 6.0968, 0.7465], [-0.4552, 0.805, 5.9189, 1.1287, 4.8118, 0.6031], [0.3167, 0.5303, 5.8944, 1.0377, 4.18, 1.2476], [0.1286, 0.6052, 8.6991, 1.3672, 3.5748, 0.7594], [-0.7872, 0.3716, 7.4725, 0.7132, 3.8268, 0.9633], [-0.0696, 0.3841, 7.5035, 1.2431, 1.5856, 0.948], [0.0525, 0.6611, 6.5119, 1.0414, 4.9638, 0.654], [-0.2668, 0.6896, 4.9086, 0.8458, 6.2347, 0.6646], [0.034, 0.3916, 4.9331, 0.9756, 6.178, 0.9142], [-0.9384, 0.6132, 8.8119, 1.9828, 3.2565, 0.7811], [-0.6236, 0.8657, 10.7139, 1.5143, 0.6677, 1.1438], [-0.0109, 0.3097, 4.7548, 1.4761, 6.1937, 1.015], [-0.6366, 0.2317, 10.6851, 0.9657, 4.9542, 1.1806], [0.1879, 0.0053, 7.0254, 2.2581, 0.0086, 1.2124]]
const OFFS := [[0.0199, 0.0223], [0.0177, 0.0127], [0.0263, 0.0344], [0.0108, 0.0145], [0.0002, 0.0112], [0.0326, 0.0198], [0.0341, 0.0391], [0.0202, 0.0259], [0.0032, 0.0044], [0.0201, 0.0204], [0.0213, 0.0253], [0.0167, 0.0002], [0.0224, 0.0394], [0.0043, 0.0061], [0.0144, 0.0348], [0.0374, 0.0352], [0.0185, 0.0009], [0.0305, 0.0133]]

var quills := []
var order := []
var WING: PackedColorArray


func make() -> void:
	WING = PackedColorArray([C[2], C[3], C[4], C[5], C[6], Color.WHITE])
	_quills()
	_shaft()
	_bands()
	_wings()
	_loose()
	_floor_and_body()
	_halo()
	_lights()
	_particles()


# ------------------------------------------------------------------ the original's poses

static func along(pts: Array, s: float) -> Vector2:
	var seglen := []
	var L := 0.0
	for i in range(1, pts.size()):
		var l: float = (pts[i] - pts[i - 1]).length()
		seglen.append(l)
		L += l
	var d := s * L
	for i in seglen.size():
		if d <= seglen[i] or i == seglen.size() - 1:
			var f: float = clampf(d / seglen[i], 0.0, 1.0) if seglen[i] > 0.0 else 0.0
			return (pts[i] as Vector2).lerp(pts[i + 1], f)
		d -= seglen[i]
	return pts[-1]


## The beat: a slow raise, a hard fast downstroke, a recovery that overshoots a touch.
static func beat(t: float) -> float:
	if t < B0:
		return 0.0
	if t < B1:
		return -0.34 * in_out_sine(seg(t, B0, B1))
	if t < B2:
		return lerpf(-0.34, 0.66, in_quad(seg(t, B1, B2)))
	return 0.66 * (1.0 - out_back(seg(t, B2, B3), 1.3))


static func climb_y(t: float) -> float:
	return lerpf(1.0, STOP - 2.0, in_out_sine(seg(t, CL0, CL1)))


static func shaft_k(t: float) -> float:
	return smooth(0.0, 0.12, t) * (1.0 - smooth(3.0, 3.75, t))


static func half_w(y: float, t: float) -> float:
	var sw := lerpf(0.4, 1.0, out_cubic(seg(t, 0.0, 0.6))) * lerpf(1.0, 0.12, in_cubic(seg(t, 2.9, 3.6)))
	return lerpf(8.0, 25.0, (y - TOP) / -TOP) * sw


func _quills() -> void:
	var reach := []
	var far := 0.0
	for q in QUILLS:
		var b := along(ARM_OPEN, q[0])
		var r := (b + Vector2(cos(q[1]), sin(q[1])) * float(q[2])).length()
		reach.append(r)
		far = maxf(far, r)
	for i in QUILLS.size():
		var q: Array = QUILLS[i]
		var s: float = q[0]
		var kind: int = q[4]
		var base: float = SC + (1.0 - reach[i] / far) * 0.2
		quills.append({"i": i, "s": s, "ang": float(q[1]), "len": float(q[2]), "wid": float(q[3]), "kind": kind,
			"fold": 1.45 + (i % 6) * 0.04, "open": (0.06 + (s - 0.8) * 0.45) if kind == 0 else (s * 0.06 if kind == 1 else 0.03 + s * 0.05),
			"off": [base + OFFS[i][0], base + OFFS[i][1]]})
	# the lowest feathers first, so each one above lays its trailing edge over the next; coverts on top
	var idx := range(QUILLS.size())
	idx.sort_custom(func(a: int, b: int) -> bool: return QUILLS[a][1] > QUILLS[b][1])
	for i in idx:
		if QUILLS[i][4] != 2:
			order.append(i)
	for i in idx:
		if QUILLS[i][4] == 2:
			order.append(i)


## Every feather of one wing at tt: {out: [{i, x, y, ang, len, wid, a, hot}], arm: [4 points]}.
func wing(tt: float, side: float) -> Dictionary:
	var oa := out_back(seg(tt, W0, W0 + 0.4), 1.6)
	var rot := beat(tt)
	var om := (beat(tt) - beat(tt - 0.03)) / 0.03
	var arm := []
	for i in 4:
		arm.append((ARM_FOLD[i] as Vector2).lerp(ARM_OPEN[i], oa))
	var cr := cos(rot)
	var sr := sin(rot)
	var a0 := smooth(W0, W0 + 0.1, tt)
	var out := []
	for q in quills:
		var off: float = q.off[0 if side > 0.0 else 1]
		if tt >= off + 0.05:
			continue
		var op: float = q.open
		var of := out_back(seg(tt, W0 + op, W0 + op + 0.42), 2.0)
		var v := along(arm, q.s)
		var b := Vector2(side * (SHOULDER.x + v.x * cr - v.y * sr), SHOULDER.y + v.x * sr + v.y * cr)
		var ang: float = lerpf(q.fold, q.ang, of) + rot - clampf(om * 0.045 * FLEX[q.kind], -0.5, 0.5)
		out.append({"i": q.i, "kind": q.kind, "x": b.x, "y": b.y, "ang": ang if side > 0.0 else PI - ang, "len": float(q.len) * lerpf(0.3, 1.0, of),
			"wid": q.wid, "a": a0, "hot": 1.0 if (tt < W0 + op + 0.07 or tt >= off) else 0.0})
	var placed := []
	for v in arm:
		placed.append(Vector2(side * (SHOULDER.x + v.x * cr - v.y * sr), SHOULDER.y + v.x * sr + v.y * cr))
	return {"out": out, "arm": placed}


static func find_i(out: Array, i: int) -> Dictionary:
	for f in out:
		if f.i == i:
			return f
	return {}


static func tip(f: Dictionary, k: float = 1.0) -> Vector2:
	return Vector2(f.x + cos(f.ang) * f.len * k, f.y + sin(f.ang) * f.len * k)


## Key node.prop with vals[f] on every frame f (stepped, half a frame early so the frame's capture gets its value).
func kf(node: Node, prop: String, vals: Array) -> void:
	var keys := []
	for f in vals.size():
		keys.append([maxf(0.0, (f - 0.5) / FPS), vals[f]])
	key(node, prop, keys, "nearest")


func per_frame(fn: Callable) -> Array:
	var out := []
	for f in NFR:
		out.append(fn.call(f / FPS))
	return out


# ------------------------------------------------------------------ the shaft

func _shaft() -> void:
	var ray := PackedVector4Array()
	var ph := PackedFloat32Array()
	for r in RAYS:
		ray.append(Vector4(r[0], r[1], r[2], r[3]))
		ph.append(r[4])
	var sorted := RAYS.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	var core := PackedVector4Array()
	for r in sorted.slice(0, 2):
		core.append(Vector4(r[0], r[3], r[4], 0.0))
	var ma := PackedVector4Array()
	var mb := PackedVector2Array()
	for m in MOTES:
		ma.append(Vector4(m[0], m[1], m[2], m[3]))
		mb.append(Vector2(m[4], m[5]))
	var sh := shape("Shaft", holy_shader("res_shaft"), Vector2(72, 142), {"pal": C, "ray": ray, "ray_ph": ph, "core": core,
		"mote_a": ma, "mote_b": mb, "translucent": true}, {"at": Vector2(0, -69), "back": true})
	key(sh, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	var sl := shape("ShaftLight", holy_shader("res_shaft_light"), Vector2(104, 160), {"pal": C, "ray": ray, "ray_ph": ph}, {"at": Vector2(0, -60)})
	key(sl, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])


## The ring of light rolling out where the pour lands: the far half behind, the near half in front.
func _bands() -> void:
	for half in [[1.0, true, "BandFar"], [-1.0, false, "BandNear"]]:
		var b := shape(half[2], holy_shader("res_band"), Vector2(80, 16), {"radius": 4.0, "thickness": 3.0, "squash": 0.18,
			"c0": Color.WHITE, "c1": C[6], "c2": C[5], "c3": C[4], "k": 0.0, "side": half[0]}, {"back": half[1]})
		kf(b, "material:shader_parameter/radius", per_frame(func(t: float) -> float: return 4.0 + 32.0 * out_cubic(seg(t, POUR, POUR + 0.4))))
		kf(b, "material:shader_parameter/thickness", per_frame(func(t: float) -> float: return 2.5 * (1.0 - seg(t, POUR, POUR + 0.4)) + 0.5))
		kf(b, "material:shader_parameter/k", per_frame(func(t: float) -> float: return (1.1 - seg(t, POUR, POUR + 0.4)) if (t > POUR and t < POUR + 0.4) else 0.0))


# ------------------------------------------------------------------ the wings

func _wings() -> void:
	for side in [-1.0, 1.0]:
		var nm := "WingL" if side < 0.0 else "WingR"
		var w := shape(nm, holy_shader("res_feathers"), Vector2(80, 84), {"R": WING, "count": 18, "quill": 0.02,
			"fa": PackedVector4Array(), "fb": PackedVector4Array()}, {"at": Vector2(side * 36.0, -38.0), "back": true})
		var gl := glow(nm + "Glow", 40, {"radius": 38, "color": C[4], "alpha": 0.0}, {"at": Vector2(side * 28.0, -36.0)})
		var bone := glow_path(nm + "BoneLight", Vector2(-40, -60), Vector2(40, -10), 7.0, C[5], 0.25, 2.0)
		var spk := sparkle(nm + "Glint", Vector2.ZERO, 2.0, Color.WHITE, C[6], {"visible": false})
		var spl := glow(nm + "GlintLight", 14, {"radius": 8, "color": Color.WHITE, "alpha": 0.0})
		var FA := []
		var FB := []
		var ARM := []
		var ARMA := []
		var TR := []
		var TRF := []
		var GA := []
		var BA := []
		var BB := []
		var BK := []
		var SV := []
		var SP := []
		var SA := []
		var LP := []
		var LR := []
		var LA := []
		for f in NFR:
			var t := f / FPS
			var wg := wing(t, side)
			var out: Array = wg.out
			var arm: Array = wg.arm
			var fa := PackedVector4Array()
			var fb := PackedVector4Array()
			for i in order:
				var q := find_i(out, i)
				if q.is_empty():
					fa.append(Vector4(0, 0, 0, 0))
					fb.append(Vector4(0, 0, 0, side))
				else:
					fa.append(Vector4(q.x, q.y, q.ang, q.len))
					fb.append(Vector4(q.wid, q.a, q.hot, side))
			FA.append(fa)
			FB.append(fb)
			var k := out.size() / 18.0
			var a0: float = out[0].a if out.size() else 0.0
			ARM.append(PackedVector2Array(arm))
			ARMA.append(a0 if k > 0.5 else 0.0)
			# the primaries' tips trail light on the downstroke
			var tr := PackedVector2Array()
			var trf := 0.0
			if t > B1 + 0.03 and t < B2 + 0.14:
				trf = 1.0 - smooth(B2, B2 + 0.14, t)
				for i in [6, 8, 10]:
					for j in 10:
						var tt := maxf(B1 + 0.01, t - j * 0.012)
						var q := find_i(wing(tt, side).out, i)
						tr.append(Vector2(999, 999) if q.is_empty() else Vector2(q.x + cos(q.ang) * (q.len - 1.0), q.y + sin(q.ang) * (q.len - 1.0)))
			else:
				for j in 30:
					tr.append(Vector2(999, 999))
			TR.append(tr)
			TRF.append(trf)
			GA.append(0.26 * a0 * k if out.size() else 0.0)
			BA.append(arm[0])
			BB.append(arm[3])
			BK.append(0.25 * a0 * k if out.size() else 0.0)
			# a glint runs out along the leading edge
			var g := fmod((t - W0 - 0.45) * 1.3, 1.0)
			var on := out.size() > 0 and k > 0.9 and t > W0 + 0.45 and g < 0.8
			SV.append(on)
			var gp := along(arm, g / 0.8) if on else Vector2.ZERO
			var n := 2.0 + sin((g / 0.8) * PI) * 2.0 if on else 2.0
			SP.append(gp.floor() + Vector2(0.5, 0.5))
			SA.append(n)
			LP.append(gp)
			LR.append(4.0 + roundf(n) * 2.0)
			LA.append(0.4 if on else 0.0)
		kf(w, "material:shader_parameter/fa", FA)
		kf(w, "material:shader_parameter/fb", FB)
		kf(w, "material:shader_parameter/arm", ARM)
		kf(w, "material:shader_parameter/arm_a", ARMA)
		kf(w, "material:shader_parameter/tr", TR)
		kf(w, "material:shader_parameter/tr_fade", TRF)
		kf(gl, "material:shader_parameter/alpha", GA)
		kf(bone, "material:shader_parameter/a", BA)
		kf(bone, "material:shader_parameter/b", BB)
		kf(bone, "material:shader_parameter/k", BK)
		kf(spk, "visible", SV)
		kf(spk, "position", SP)
		kf(spk, "material:shader_parameter/arm", SA)
		kf(spl, "position", LP)
		kf(spl, "material:shader_parameter/radius", LR)
		kf(spl, "material:shader_parameter/alpha", LA)


# ------------------------------------------------------------------ loose feathers (the original's Feathers, replayed)

func _add_feather(R: RandomNumberGenerator, list: Array, f: Dictionary) -> void:
	var d := {"vx": 0.0, "vy": 0.0, "a": 0.0, "len": 7.0, "wid": 2.0, "back": false, "side": 1.0, "ph": R.randf_range(0, TAU),
		"w": R.randf_range(3.2, 4.6), "amp": R.randf_range(6, 11), "sink": R.randf_range(14, 24), "va": R.randf_range(-9, 9),
		"tilt": R.randf_range(-0.35, 0.35)}
	d.merge(f, true)
	d.max = f.life
	d.age = 0.0
	d.landed = false
	list.append(d)


func _step_feathers(list: Array, dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var f: Dictionary = list[i]
		f.life -= dt
		if f.life <= 0.0:
			list.remove_at(i)
			continue
		f.age += dt
		if f.landed:
			f.a += (roundf(f.a / PI) * PI - f.a) * minf(1.0, dt * 10.0)
			continue
		f.vx -= f.vx * 3.4 * dt
		f.vy -= f.vy * 3.4 * dt
		var s := smooth(0.1, 0.6, f.age)
		var ph: float = f.age * f.w + f.ph
		var c := cos(ph)
		f.x += (f.vx + sin(ph) * f.amp * s * 0.9) * dt
		f.y += (f.vy + f.sink * s * (c * c * 1.5 - 0.2)) * dt
		var rest: float = roundf(f.a / PI) * PI + f.tilt + sin(ph) * 0.6
		f.a += f.va * dt * (1.0 - s) + (rest - f.a) * minf(1.0, dt * 5.0 * s)
		if f.y >= -0.5:
			f.y = -0.5
			f.landed = true
			f.life = minf(f.life, 0.6)


var scatter_pts := {-1.0: PackedVector2Array(), 1.0: PackedVector2Array()}
var beat_tips := {-1.0: PackedVector2Array(), 1.0: PackedVector2Array()}


func _loose() -> void:
	var R := RandomNumberGenerator.new()
	R.seed = 55
	var list := []
	var gone := {}
	var beaten := false
	var dt := 1.0 / 120.0
	var t := 0.0
	var nodes := {}
	for layer in ["back", "front"]:
		var nm := "LooseBack" if layer == "back" else "LooseFront"
		nodes[layer] = {"f": shape(nm, holy_shader("res_feathers"), Vector2(192, 160), {"R": WING, "count": 32, "quill": 0.2,
			"fa": PackedVector4Array(), "fb": PackedVector4Array()}, {"at": Vector2(0, -60), "back": layer == "back"}),
			"FA": [], "FB": []}
	var glows := shape("LooseLight", holy_shader("res_glows"), Vector2(192, 160), {"color": WING[3], "count": 32, "g": PackedVector4Array()}, {"at": Vector2(0, -60)})
	var G := []
	for f in NFR:
		var target := f / FPS
		while t < target - 1e-6:
			t += dt
			if not beaten and t >= B2 - 0.03:
				beaten = true
				for side in [-1.0, 1.0]:
					var out: Array = wing(t, side).out
					var sec := out.filter(func(w: Dictionary) -> bool: return w.kind == 1)
					var tips := PackedVector2Array()
					for w in out:
						if w.kind == 0:
							tips.append(tip(w))
					beat_tips[side] = tips
					for i in 3:
						if sec.is_empty():
							break
						var w: Dictionary = sec[R.randi_range(0, sec.size() - 1)]
						_add_feather(R, list, {"x": w.x + cos(w.ang) * w.len * 0.6, "y": w.y + sin(w.ang) * w.len * 0.6, "vx": side * R.randf_range(20, 70),
							"vy": R.randf_range(10, 50), "a": w.ang, "len": R.randf_range(9, 12), "wid": R.randf_range(2.2, 2.8), "life": R.randf_range(1.2, 1.6), "side": side})
			for side in [-1.0, 1.0]:
				var si := 0 if side > 0.0 else 1
				for q in quills:
					var gk := "%d/%d" % [si, q.i]
					if gone.has(gk) or t < q.off[si]:
						continue
					gone[gk] = true
					var w := find_i(wing(q.off[si] - 0.001, side).out, q.i)
					if w.is_empty():
						continue
					var pts: PackedVector2Array = scatter_pts[side]
					pts.append(tip(w, 0.3))
					pts.append(tip(w, 0.65))
					pts.append(tip(w, 1.0))
					scatter_pts[side] = pts
					if q.kind == 2:
						continue
					var x: float = w.x + cos(w.ang) * w.len * 0.55
					var y: float = w.y + sin(w.ang) * w.len * 0.55
					var ox: float = x - side * 4.0
					var oy: float = y + 20.0
					var l := maxf(1e-6, Vector2(ox, oy).length())
					var sp := R.randf_range(60, 150)
					_add_feather(R, list, {"x": x, "y": y, "vx": ox / l * sp + R.randf_range(-15, 15), "vy": oy / l * sp * 0.5 - R.randf_range(20, 50),
						"a": w.ang + R.randf_range(-0.4, 0.4), "len": R.randf_range(9, 12), "wid": R.randf_range(2.2, 2.8), "life": R.randf_range(1.0, 1.45),
						"side": side, "back": R.randf() < 0.35})
			_step_feathers(list, dt)
		var arr := {"back": [PackedVector4Array(), PackedVector4Array()], "front": [PackedVector4Array(), PackedVector4Array()]}
		var g := PackedVector4Array()
		for fe in list:
			var k: float = fe.life / fe.max
			var a := minf(1.0, minf(fe.life / 0.45, fe.age / 0.06))
			var ca := cos(fe.a)
			var sa := sin(fe.a)
			var L: Array = arr["back" if fe.back else "front"]
			L[0].append(Vector4(fe.x - ca * fe.len / 2.0, fe.y - sa * fe.len / 2.0, fe.a, fe.len))
			L[1].append(Vector4(fe.wid, a, 1.0 if fe.age < 0.06 else 0.0, fe.side))
			g.append(Vector4(fe.x, fe.y, 4.0 + fe.len * 0.5, 0.22 * a * (0.4 + 0.6 * k)))
		for layer in ["back", "front"]:
			var L: Array = arr[layer]
			while L[0].size() < 32:
				L[0].append(Vector4(0, 0, 0, 0))
				L[1].append(Vector4(0, 0, 0, 1))
			nodes[layer].FA.append(L[0].slice(0, 32))
			nodes[layer].FB.append(L[1].slice(0, 32))
		while g.size() < 32:
			g.append(Vector4(0, 0, 0, 0))
		G.append(g.slice(0, 32))
	for layer in ["back", "front"]:
		kf(nodes[layer].f, "material:shader_parameter/fa", nodes[layer].FA)
		kf(nodes[layer].f, "material:shader_parameter/fb", nodes[layer].FB)
	kf(glows, "material:shader_parameter/g", G)


# ------------------------------------------------------------------ the floor and the body

func _floor_and_body() -> void:
	var fl := shape("Floor", holy_shader("res_floor"), Vector2(192, 10), {"pal": C}, {"at": Vector2(0, 2)})
	kf(fl, "material:shader_parameter/kp", per_frame(func(t: float) -> float: return shaft_k(t) * smooth(POUR - 0.05, POUR + 0.1, t)))
	kf(fl, "material:shader_parameter/pw", per_frame(func(t: float) -> float: return maxf(0.5, half_w(0.0, t) * 1.25)))
	kf(fl, "material:shader_parameter/ru", per_frame(func(t: float) -> float: return seg(t, B2 - 0.03, B2 + 0.45) if (t > B2 - 0.03 and t < B2 + 0.45) else -1.0))
	var tex: Texture2D = load(EFFECT.STAND_INS[2])
	var body := shape("Body", holy_shader("res_body"), Vector2(28, 42), {"tex": tex, "ash": PackedColorArray(fit(root.ramps.ash, 6)), "pal": C},
		{"at": Vector2(0, -19)})
	kf(body, "material:shader_parameter/mode", per_frame(func(t: float) -> float: return 1.0 if t < CL1 else (2.0 if t < CL1 + 0.6 else 0.0)))
	kf(body, "material:shader_parameter/ly", per_frame(func(t: float) -> float: return climb_y(t)))
	kf(body, "material:shader_parameter/u", per_frame(func(t: float) -> float: return maxf(0.0, t - CL1)))
	# the wings light the character from behind
	var wk := func(t: float) -> float: return smooth(W0, W0 + 0.2, t) * (1.0 - smooth(SC, SC + 0.3, t))
	var rim := shape("RimLight", holy_shader("res_rim_light"), Vector2(28, 42), {"tex": tex, "color": C[5]}, {"at": Vector2(0, -19)})
	kf(rim, "material:shader_parameter/k", per_frame(func(t: float) -> float: return 0.55 * wk.call(t)))
	var back_glow := glow("WingsOnBody", 78, {"radius": 76, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -34)})
	kf(back_glow, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.14 * wk.call(t)))
	# the climbing line's light
	var climbing := func(t: float) -> bool: return t > CL0 and t < CL1
	var g1 := glow("ClimbGlow", 28, {"radius": 26, "color": C[4], "alpha": 0.0})
	var g2 := glow("ClimbWhite", 10, {"radius": 8, "color": Color.WHITE, "alpha": 0.0})
	var g3 := glow("ClimbBody", 38, {"radius": 36, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -18)})
	for g in [g1, g2]:
		kf(g, "position", per_frame(func(t: float) -> Vector2: return Vector2(0, climb_y(t))))
	kf(g1, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.5 if climbing.call(t) else 0.0))
	kf(g2, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.3 if climbing.call(t) else 0.0))
	kf(g3, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.16 * seg(t, CL0, CL1) if climbing.call(t) else 0.0))
	# the hero frame's flare over the head
	var fla := flare("Flare", 24, {"at": Vector2(0, STOP - 1)})
	kf(fla, "material:shader_parameter/reach", per_frame(func(t: float) -> float: return 22.0 * (1.0 - (t - CL1) / 0.22) if (t >= CL1 and t < CL1 + 0.22) else 0.0))
	kf(fla, "material:shader_parameter/k", per_frame(func(t: float) -> float: return clampf(1.0 - (t - CL1) / 0.22, 0.0, 1.0)))


# ------------------------------------------------------------------ the halo

func _halo() -> void:
	var h := shape("Halo", holy_shader("res_halo"), Vector2(28, 12), {"pal": C}, {"at": Vector2(HX, HY + 1)})
	var form := func(t: float) -> float: return out_cubic(seg(t, H0, H1))
	var hk := func(t: float) -> float: return 1.0 - smooth(3.35, 3.9, t)
	kf(h, "material:shader_parameter/form", per_frame(form))
	kf(h, "material:shader_parameter/k", per_frame(hk))
	kf(h, "material:shader_parameter/white", per_frame(func(t: float) -> float: return 1.0 if (t >= H1 and t < H1 + 0.06) else 0.0))
	kf(h, "material:shader_parameter/gl", per_frame(func(t: float) -> float: return (t - H1) * 4.2 + PI / 2.0))
	var l1 := glow("HaloGlow", 22, {"radius": 20, "color": C[4], "alpha": 0.0}, {"at": Vector2(HX, HY)})
	var l2 := glow("HaloWhite", 10, {"radius": 9, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(HX, HY + 1)})
	kf(l1, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.4 * hk.call(t) * form.call(t)))
	kf(l2, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.2 * hk.call(t) * form.call(t)))
	# a glint runs round it; a star as it closes
	var gl := sparkle("HaloGlint", Vector2(HX, HY), 2.0, C[6], C[4], {"visible": false})
	var gll := glow("HaloGlintLight", 10, {"radius": 8, "color": C[6], "alpha": 0.0})
	var gpos := func(t: float) -> Vector2:
		var g := (t - H1) * 4.2 + PI / 2.0
		return Vector2(HX + cos(g) * HRX, HY + sin(g) * HRY + 0.5)
	var gon := func(t: float) -> bool: return t > H1 and sin((t - H1) * 4.2 + PI / 2.0) > 0.2 and hk.call(t) > 0.0
	kf(gl, "visible", per_frame(gon))
	kf(gl, "position", per_frame(func(t: float) -> Vector2: return (gpos.call(t) as Vector2).floor() + Vector2(0.5, 0.5)))
	kf(gl, "material:shader_parameter/arm", per_frame(func(t: float) -> float: return 2.0 + 2.0 * sin((t - H1) * 4.2 + PI / 2.0)))
	kf(gll, "position", per_frame(func(t: float) -> Vector2: return gpos.call(t)))
	kf(gll, "material:shader_parameter/radius", per_frame(func(t: float) -> float: return 4.0 + 2.0 * roundf(2.0 + 2.0 * sin((t - H1) * 4.2 + PI / 2.0))))
	kf(gll, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.35 * hk.call(t) if gon.call(t) else 0.0))
	var st := sparkle("HaloStar", Vector2(HX, HY + HRY + 0.5), 7.0, Color.WHITE, C[5], {"visible": false})
	var stl := glow("HaloStarLight", 20, {"radius": 18, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(HX, HY + HRY + 0.5)})
	var son := func(t: float) -> bool: return t >= H1 and t < H1 + 0.3
	kf(st, "visible", per_frame(son))
	kf(st, "material:shader_parameter/arm", per_frame(func(t: float) -> float: return 7.0 * (1.0 - (t - H1) / 0.3) if son.call(t) else 0.0))
	kf(stl, "material:shader_parameter/radius", per_frame(func(t: float) -> float: return 4.0 + 2.0 * roundf(7.0 * (1.0 - (t - H1) / 0.3)) if son.call(t) else 4.0))
	kf(stl, "material:shader_parameter/alpha", per_frame(func(t: float) -> float: return 0.6 if (son.call(t) and roundf(7.0 * (1.0 - (t - H1) / 0.3)) >= 1.0) else 0.0))


# ------------------------------------------------------------------ the original's flashes of light (Lights.add)

func _lights() -> void:
	light_burst("PourLight", POUR, Vector2(0, -12), 42, C[5], 0.9, 0.4)
	light_burst("PourWhite", POUR, Vector2(0, -6), 16, Color.WHITE, 0.6, 0.1)
	light_burst("RiseLight", CL1, Vector2(0, -24), 64, C[5], 0.7, 0.5)
	light_burst("RiseWhite", CL1, Vector2(0, -30), 28, Color.WHITE, 0.7, 0.1)
	light_burst("HaloLight", H1, Vector2(HX, HY), 30, C[6], 0.8, 0.3)
	light_burst("BeatLightL", B2 - 0.03, Vector2(-30, -34), 46, C[5], 0.6, 0.4)
	light_burst("BeatLightR", B2 - 0.03, Vector2(30, -34), 46, C[5], 0.6, 0.4)


# ------------------------------------------------------------------ particles

## An emitter and its light twin (same options and seed, glow texture, tinted), started at on and stopped at off.
func pair(name: String, o: Dictionary, glow_tex: String, glow_mod: Color, on: float, off := -1.0, frames_n := 0) -> GPUParticles2D:
	var p := particles(name, o)
	if frames_n > 0:
		flip(p, frames_n)
	var l := particles(name + "Light", o.merged({"texture": glow_tex, "layer": "light", "modulate": glow_mod}, true))
	if frames_n > 0:
		l.process_material.anim_speed_min = 1.0
		l.process_material.anim_speed_max = 1.0
	emit(p, on, off)
	emit(l, on, off)
	return p


func _particles() -> void:
	ground()
	var star_tex := asset("stars.png", sparkle_strip(8, func(u: float) -> float: return roundf(1.8 * (0.6 + 0.4 * sin(u * 11.0 + 1.0)) * minf(1.0, 3.0 * (1.0 - u))), Color.WHITE, C[6], 4))
	var star_small := asset("stars_small.png", sparkle_strip(8, func(u: float) -> float: return roundf(1.2 * (0.6 + 0.4 * sin(u * 9.0)) * minf(1.0, 3.0 * (1.0 - u))), C[6], C[5], 4))
	# a streak of light: the head white, the body cream, the tail dim (head last: it points along the velocity)
	var sk := Image.create(1, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		var d := 6 - y
		sk.set_pixel(0, y, Color.WHITE if d < 1 else (Color(C[6], 1.0) if d < 3 else Color(C[5], clampf(1.2 - d / 7.0, 0.0, 1.0))))
	var streak := asset("streak.png", sk)

	# light pours down the shaft as streaks, faster as they fall
	pair("PourStreaks", {"at": Vector2(0, TOP + 16), "amount": 12, "lifetime": 0.6, "life_random": 0.15, "texture": streak, "align": true,
		"emit": {"box": Vector2(8, 8)}, "dir": 90, "spread": 1, "speed": [50, 90], "gravity": Vector2(0, 430)},
		"glow8", Color(C[6], 0.4), 0.05, 2.9)
	# stars hang in the shaft
	pair("ShaftStars", {"at": Vector2(0, -47), "amount": 4, "lifetime": 0.8, "life_random": 0.5, "texture": star_small,
		"emit": {"box": Vector2(18, 43)}, "dir": 90, "spread": 180, "speed": [0, 5]}, "glow16", Color(C[6], 0.3), 0.3, 2.8, 8)
	# the pour lands: stars and sparks thrown up off the floor
	pair("PourStars", {"at": Vector2(0, -3), "amount": 14, "lifetime": 1.1, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": star_tex, "emit": {"box": Vector2(18, 3)}, "dir": -90, "spread": 35, "speed": [12, 50], "drag": 1.6}, "glow16", Color(C[6], 0.35), POUR, -1, 8)
	pair("PourSparks", {"at": Vector2(0, -1), "amount": 10, "lifetime": 0.5, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "align": true, "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 69, "speed": [60, 150], "gravity": Vector2(0, 427),
		"drag": 2.2, "ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}}, "glow8", Color(C[6], 0.45), POUR)
	# bits of light peel off the rim as life climbs the body
	var rows := {}
	for q in actor_points(true, 2):
		var y := int(floorf(q.y))
		if not rows.has(y):
			rows[y] = [q.x, q.x]
		rows[y] = [minf(rows[y][0], q.x), maxf(rows[y][1], q.x)]
	for side in [-1.0, 1.0]:
		var nm := "ClimbBits%s" % ("L" if side < 0.0 else "R")
		var p := pair(nm, {"amount": 22, "lifetime": 0.7, "life_random": 0.5, "texture": "dot1",
			"emit": {"box": Vector2(0.5, 1)}, "dir": -90.0 - side * 32.0, "spread": 22, "speed": [17, 54], "drag": 0.6,
			"initial": gradient([C[6], C[5]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]}, "glow8", Color(C[6], 0.4), CL0, CL1)
		var lp := get_node_light(p)
		var pos := per_frame(func(t: float) -> Vector2:
			var ly := int(roundf(climb_y(t)))
			var r: Array = rows.get(ly, rows.get(ly + 1, [0.0, 0.0]))
			return Vector2((r[0] - 0.5) if side < 0.0 else (r[1] + 0.5), float(ly)))
		kf(p, "position", pos)
		kf(lp, "position", pos)
	# the hero frame: stars burst off the body
	pair("RiseStars", {"at": Vector2(0, -24), "amount": 18, "lifetime": 0.9, "life_random": 0.45, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": star_tex, "emit": {"box": Vector2(6, 12)}, "dir": -90, "spread": 180, "speed": [30, 110], "gravity": Vector2(0, -20), "drag": 1.6},
		"glow16", Color(C[6], 0.35), CL1, -1, 8)
	# motes spiral in to make the halo
	var ring_pts := PackedVector2Array()
	for i in 24:
		var g := i / 24.0 * TAU
		ring_pts.append(Vector2(cos(g) * 19.0, sin(g) * 9.5))
	pair("HaloMotes", {"at": Vector2(HX, HY), "amount": 10, "lifetime": 0.22, "life_random": 0.25, "texture": streak, "align": true,
		"emit": {"points": ring_pts}, "radial_speed": [-55, -40], "tangential": [60, 90]}, "glow8", Color(C[6], 0.4), H0 - 0.2, H0 + 0.1)
	# the wings burst open with a scatter of light; light twinkles on the tips while they hold; embers lift off them
	for side in [-1.0, 1.0]:
		var sn := "L" if side < 0.0 else "R"
		var open_tips := PackedVector2Array()
		var prim := PackedVector2Array()
		var mids := PackedVector2Array()
		for w in wing(W0 + 0.3, side).out:
			open_tips.append(tip(w))
		for w in wing(1.8, side).out:
			if w.kind == 0:
				prim.append(tip(w, 1.0) - Vector2(cos(w.ang), sin(w.ang)) * 2.0)
			mids.append(tip(w, 0.7))
		pair("WingBurst" + sn, {"amount": 14, "lifetime": 0.6, "life_random": 0.5, "texture": star_tex, "emit": {"points": open_tips},
			"dir": -90.0 - side * 45.0, "spread": 35, "speed": [8, 35], "drag": 1.6}, "glow16", Color(C[6], 0.35), W0, W0 + 0.35, 8)
		pair("TipStars" + sn, {"amount": 3, "lifetime": 0.6, "life_random": 0.5, "texture": star_tex, "emit": {"points": prim},
			"dir": -90, "spread": 5, "speed": [2, 8]}, "glow16", Color(C[6], 0.35), W0 + 0.45, SC, 8)
		_embers("WingEmbers" + sn, {"amount": 4, "emit": {"points": mids}, "dir": -90.0 - side * 20.0, "spread": 25, "speed": [8, 26]}, W0 + 0.45, SC)
		# the downstroke: a gust of lit dust along the floor, sparks flung off the tips
		pair("Gust" + sn, {"at": Vector2(side * 15.0, -2.5), "amount": 7, "lifetime": 0.45, "life_random": 0.45, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": streak, "align": true, "emit": {"box": Vector2(7, 1.5)}, "dir": 90.0 - side * 90.0 + side * 2.0, "spread": 3,
			"speed": [90, 160], "drag": 0.6}, "glow8", Color(C[6], 0.4), B2 - 0.03)
		var bt: PackedVector2Array = beat_tips[side]
		pair("BeatSparks" + sn, {"amount": maxi(1, bt.size()), "lifetime": 0.6, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": "streak3", "align": true, "emit": {"points": bt}, "dir": 90.0 - side * 30.0, "spread": 20, "speed": [70, 180],
			"gravity": Vector2(0, 427), "drag": 2.2, "ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}},
			"glow8", Color(C[6], 0.45), B2 - 0.03)
		# the wings come apart: each feather breaks into embers and a star
		var sp: PackedVector2Array = scatter_pts[side]
		_embers("ScatterEmbers" + sn, {"amount": 36, "lifetime": 1.1, "explosiveness": 0.75, "one_shot": true, "emit": {"points": sp},
			"dir": -90, "spread": 30, "speed": [10, 42]}, SC, -1.0)
		pair("ScatterStars" + sn, {"amount": 11, "lifetime": 0.6, "life_random": 0.5, "one_shot": true, "explosiveness": 0.6, "emitting": false,
			"texture": star_tex, "emit": {"points": sp}, "dir": -90, "spread": 5, "speed": [5, 15]}, "glow16", Color(Color.WHITE, 0.3), SC, -1, 8)
	# the halo melts into rising motes
	_embers("HaloMelt", {"at": Vector2(HX, HY), "amount": 10, "emit": {"points": PackedVector2Array(ring_pts).duplicate()}, "dir": -90, "spread": 25,
		"speed": [10, 25]}, 3.35, 3.75)


func get_node_light(p: GPUParticles2D) -> GPUParticles2D:
	return root.get_node(String(p.name) + "Light")


## The original's EMBER: a hot pixel rising and swaying, white cooling to gold, flickering out; a glow on each.
func _embers(name: String, o: Dictionary, on: float, off: float) -> void:
	var d := {"lifetime": 1.1, "life_random": 0.45, "texture": "dot1", "gravity": Vector2(0, -30), "drag": 1.6,
		"ramp": gradient([Color.WHITE, C[6], C[5], Color(C[5], 0.0), C[5], Color(C[5], 0.0)], [0.0, 0.4, 0.7, 0.8, 0.86, 0.93]),
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.025]}, "emitting": false}
	d.merge(o, true)
	pair(name, d, "glow8", Color(C[5], 0.35), on, off)
