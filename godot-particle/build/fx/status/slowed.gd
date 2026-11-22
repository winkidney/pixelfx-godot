# reimagined-from: src/fx/status/slowed.js@6ca80b739ec54f9acfe7347480042d4fe9e71785
# Slowed: Dragged through time: a glassy clock dial behind the head ticks round in heavy steps, flashing with each, while drops sink in slow motion and spread slow rings.
# loop, 2.40 s, 64x76 canvas, origin [32.0, 68.0], backdrop ground, stand-in 2
# ramp palette: #081a24 #0e3446 #165a6e #2a8a9a #52bcc4 #9ee6e0 #e2fff8 #ffffff
# The dial is a shader behind the head (fx/status/_slowed_dial.gdshader: a translucent face, then rim, dots, marks,
# hands and the tick's ripple) keyed with the original's hand: it waits, pulls back, snaps a quarter turn, overshoots
# and settles, flashing. Its light: a glow on the face, a glowing rim, a glow on the hand's tip, a ripple of light.
# The stand-in is the effect's own Actor under a cold film that thickens with each tick, an after-image of its
# outline dragged a step back. Six drops sink in slow motion (the original's cycle, replayed: a drop, two ghosts,
# a slow ring of two crests on the floor).
extends "res://build/fx/status/_status.gd"

const TICKS := 4
const R := 18.0
var D := 2.4
var STEP := 0.6


## the hand's angle and flash (slowed.js hand)
func hand(t: float) -> Vector2:
	var k := floorf(t / STEP + 1e-9)
	var ph := (t - k * STEP) / STEP
	var base := -PI / 2.0 + k * TAU / TICKS
	var q := TAU / TICKS
	if ph < 0.62:
		return Vector2(base, 0.0)
	if ph < 0.72:
		return Vector2(base - 0.1 * sin((ph - 0.62) / 0.1 * PI * 0.5), 0.0)
	var s := (ph - 0.72) / 0.28
	var snap := out_back(clamp01(s / 0.35), 2.2)
	var wob := exp(-s * 6.0) * sin(s * 22.0) * 0.05
	return Vector2(base - 0.1 * (1.0 - clamp01(s / 0.2)) + q * snap + wob, exp(-s * 5.0))


func afterglow(t: float) -> float:
	return exp(-fposmod(t - STEP * 0.72, STEP) * 4.0)


func make() -> void:
	D = root.duration
	STEP = D / TICKS
	var C := fit("palette", 8)
	var cy := AY + 3.0
	var seed_: int = int(meta.options.seed)
	var dial_sh: Shader = load(STATUS + "_slowed_dial.gdshader")

	# ---- behind: the dial
	shape("Face", dial_sh, Vector2(64, 64), {"pass": 0.0, "cols": C, "translucent": true}, {"at": Vector2(0, cy), "back": true})
	var dial := shape("Dial", dial_sh, Vector2(64, 64), {"pass": 1.0, "cols": C}, {"at": Vector2(0, cy), "back": true})
	var face_l := glow("FaceLight", R + 10, {"radius": R + 8, "color": C[4], "alpha": 0.14}, {"at": Vector2(0, cy)})
	var rim_l := glow("RimLight", R + 5, {"radius": R, "thickness": 3.0, "color": C[5], "alpha": 0.12}, {"at": Vector2(0, cy)})
	var tip_l := glow("TipLight", 7, {"radius": 5.0, "color": C[6], "alpha": 0.3})
	var rip_l := glow("RippleLight", R + 16, {"radius": R + 2, "thickness": 3.0, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, cy)})
	# the after-image of the body's outline, dragged a step back after every tick
	var ghost := sprite("Lag", asset("_outline", outline_image(C[5])), {"centered": false, "back": true, "at": Vector2(AX - 2, AY - 1)})
	# the body under a cold film of time
	var body := actor_node()
	body.material.set_shader_parameter("flash_color", C[5])

	var K := {"ang": [], "sh": [], "hot": [], "rr": [], "ra": [], "fl": [], "rl": [], "tp": [], "ta": [], "rlr": [], "rla": [],
		"gv": [], "gp": [], "ga": [], "film": []}
	for t in frame_times():
		var h := hand(fposmod(t, D))
		var fl := maxf(h.y, afterglow(t))
		var s := 1.0 - h.y
		K.ang.append([t, h.x])
		K.sh.append([t, -PI / 2.0 + 2.2 + h.y * sin(t * 60.0) * 0.06])
		K.hot.append([t, 1.0 if fl > 0.4 else 0.0])
		K.rr.append([t, R + 2.0 + 10.0 * s])
		K.ra.append([t, h.y])
		K.fl.append([t, 0.14 + 0.2 * fl])
		K.rl.append([t, 0.12 + 0.35 * fl])
		K.tp.append([t, Vector2(cos(h.x) * (R - 4.0), cy + sin(h.x) * (R - 4.0))])
		K.ta.append([t, 0.3 + 0.3 * h.y])
		K.rlr.append([t, R + 2.0 + 10.0 * s])
		K.rla.append([t, 0.3 * h.y])
		var lag := afterglow(t)
		K.gv.append([t, lag > 0.05])
		K.gp.append([t, Vector2(AX - 2 - jround(2.0 * lag), AY - 1)])
		K.ga.append([t, 0.55 * lag])
		K.film.append([t, 0.08 + 0.12 * fl])
	key(dial, "material:shader_parameter/ang", K.ang, "nearest")
	key(dial, "material:shader_parameter/short_ang", K.sh, "nearest")
	key(dial, "material:shader_parameter/hot", K.hot, "nearest")
	key(dial, "material:shader_parameter/ripple_r", K.rr, "nearest")
	key(dial, "material:shader_parameter/ripple_a", K.ra, "nearest")
	key(face_l, "material:shader_parameter/alpha", K.fl, "nearest")
	key(rim_l, "material:shader_parameter/alpha", K.rl, "nearest")
	key(tip_l, "position", K.tp, "nearest")
	key(tip_l, "material:shader_parameter/alpha", K.ta, "nearest")
	key(rip_l, "material:shader_parameter/radius", K.rlr, "nearest")
	key(rip_l, "material:shader_parameter/alpha", K.rla, "nearest")
	key(ghost, "visible", K.gv, "nearest")
	key(ghost, "position", K.gp, "nearest")
	key(ghost, "modulate:a", K.ga, "nearest")
	key(body, "material:shader_parameter/flash", K.film, "nearest")

	# ---- drops sinking in slow motion, ghosts trailing them, slow rings where they reach the floor
	var rows := []
	for n in 7:
		var d := {}
		for dx in range(-n, n + 1):
			d[Vector2i(dx, 0)] = C[4]
		d[Vector2i(-6, 0)] = d.get(Vector2i(-6, 0), Color(0, 0, 0, 0))
		d[Vector2i(6, 0)] = d.get(Vector2i(6, 0), Color(0, 0, 0, 0))
		rows.append(d)
	var N := []
	for i in 6:
		var n := {}
		n.drop = pixels("Drop%d" % i, {Vector2i(0, -1): C[5], Vector2i(0, 0): C[6], Vector2i(0, 1): C[5], Vector2i(-1, 1): C[4], Vector2i(-1, 0): C[7]}, {"at": Vector2.ZERO})
		n.drop.offset = Vector2(-1, -1)
		n.g = [pixels("Ghost%da" % i, {Vector2i(0, 0): C[4]}), pixels("Ghost%db" % i, {Vector2i(0, 0): C[4]})]
		n.g[0].modulate.a = 0.35
		n.g[1].modulate.a = 0.6
		n.crest = [pixels("Crest%dl" % i, {Vector2i(0, 0): WHITE, Vector2i(1, 0): WHITE}), pixels("Crest%dr" % i, {Vector2i(0, 0): WHITE, Vector2i(1, 0): WHITE})]
		n.row = _strip("Far%d" % i, rows)
		n.light = glow("DropLight%d" % i, 14, {"radius": 4.0, "color": C[5], "alpha": 0.0})
		n.K = {"dv": [], "dp": [], "gv": [[], []], "gp": [[], []], "cv": [], "cp": [[], []], "cc": [], "ca": [], "rv": [], "rp": [], "rf": [], "ra": [],
			"lp": [], "lr": [], "la": [], "lc": []}
		N.append(n)
	for t in frame_times():
		var seen := {}
		cycle(t, D, 6, seed_ + 3, func(r: Rng) -> float: return r.range(1.6, 2.2), func(age: float, life: float, r: Rng, i: int) -> void:
			var K2: Dictionary = N[i].K
			var sd := -1.0 if r.next() < 0.5 else 1.0
			var x := sd * r.range(10, 17)
			var y0 := AY + r.range(6, 22)
			var v0 := r.range(18, 30)
			var y_at := func(g: float) -> float: return y0 + (v0 * (1.0 - exp(-1.1 * g))) / 1.1 + 4.0 * g
			var y: float = y_at.call(age)
			var u := age / life
			seen[i] = true
			if y < -1.0:
				K2.dv.append([t, true])
				K2.dp.append([t, Vector2(floorf(x), floorf(y))])
				var lags := [0.22, 0.11]
				for j in 2:
					K2.gv[j].append([t, age > lags[j]])
					K2.gp[j].append([t, Vector2(floorf(x), floorf(y_at.call(age - lags[j])))])
				K2.cv.append([t, false])
				K2.rv.append([t, false])
				K2.lp.append([t, Vector2(x, y)])
				K2.lr.append([t, 4.0])
				K2.la.append([t, 0.3 * (1.0 - u)])
				K2.lc.append([t, C[5]])
			else:
				K2.dv.append([t, false])
				for j in 2:
					K2.gv[j].append([t, false])
				var g := age
				while g > 0.0 and y_at.call(g) >= -1.0:
					g -= 0.02
				var s := clamp01((age - g) / 0.9)
				var rx := 1.0 + 7.0 * sqrt(s)
				var vis := s < 1.0
				K2.cv.append([t, vis])
				K2.cp[0].append([t, Vector2(floorf(x - rx), -1)])
				K2.cp[1].append([t, Vector2(floorf(x + rx - 1.5), -1)])
				K2.cc.append([t, C[6] if s < 0.3 else C[5]])
				K2.ca.append([t, minf(1.0, (1.0 - s) * 1.2)])
				K2.rv.append([t, vis and rx >= 2.0])
				K2.rp.append([t, Vector2(floorf(x), -2)])
				K2.rf.append([t, clampi(int(floorf(rx - 2.0)), 0, 6)])
				K2.ra.append([t, (1.0 - s) * 0.4])
				K2.lp.append([t, Vector2(x, -1)])
				K2.lr.append([t, 4.0 + rx])
				K2.la.append([t, 0.12 * (1.0 - s) if vis else 0.0])
				K2.lc.append([t, C[4]]))
		for i in 6:
			if not seen.has(i):
				var K2: Dictionary = N[i].K
				K2.dv.append([t, false])
				K2.gv[0].append([t, false])
				K2.gv[1].append([t, false])
				K2.cv.append([t, false])
				K2.rv.append([t, false])
				K2.la.append([t, 0.0])
	for n in N:
		var K2: Dictionary = n.K
		key(n.drop, "visible", K2.dv, "nearest")
		key(n.drop, "position", K2.dp, "nearest")
		for j in 2:
			key(n.g[j], "visible", K2.gv[j], "nearest")
			key(n.g[j], "position", K2.gp[j], "nearest")
			key(n.crest[j], "visible", K2.cv, "nearest")
			key(n.crest[j], "position", K2.cp[j], "nearest")
			key(n.crest[j], "modulate", _rgba(K2.cc, K2.ca), "nearest")
		key(n.row, "visible", K2.rv, "nearest")
		key(n.row, "position", K2.rp, "nearest")
		key(n.row, "frame", K2.rf, "nearest")
		key(n.row, "modulate:a", K2.ra, "nearest")
		key(n.light, "position", K2.lp, "nearest")
		key(n.light, "material:shader_parameter/radius", K2.lr, "nearest")
		key(n.light, "material:shader_parameter/alpha", K2.la, "nearest")
		key(n.light, "material:shader_parameter/color", K2.lc, "nearest")


func _rgba(cc: Array, ca: Array) -> Array:
	var out := []
	for i in cc.size():
		out.append([cc[i][0], Color(cc[i][1], ca[i][1])])
	return out


## pixel dicts (centred on x = 0) as frames of one sprite whose position is their middle pixel
func _strip(name: String, dicts: Array) -> Sprite2D:
	var img := Image.create(13 * dicts.size(), 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in dicts.size():
		for q in dicts[i]:
			img.set_pixel(i * 13 + q.x + 6, 0, dicts[i][q])
	keep_image_colours(img)
	var s := sprite(name, asset("_" + name.to_lower(), img), {"centered": false, "hframes": dicts.size()})
	s.offset = Vector2(-6, 0)
	return s
