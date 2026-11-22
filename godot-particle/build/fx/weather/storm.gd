# reimagined-from: src/fx/weather/storm.js@b6fb1b121b23df7400fdefbe653d5267ff6a1e55
# Storm: Driving rain at two depths under a churning cloud deck; a forked bolt strikes in a double flash that lights the sky and the rain, then sheet lightning glows in the clouds.
# loop, 10.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp bolt: #2a1a6e #4835c2 #6a6cff #78b8ff #c6ebff #ffffff
# ramp palette: #09080f #121120 #1b1a30 #262541 #363a5c #4f5d8c #7790c6 #c2d6ff
# The sky, veil, cloud deck and wet floor are canvas shaders (fx/weather/_storm.gdshader, its light twin) keyed with
# the original's flash curves; both depths of rain and the splashes are GPU particles placed from the clock by the
# original's own trips (_storm_rain.gdshader, drawn by _streak.gdshader and _splash.gdshader), lit by the flash.
# The bolt (stepped leader, two strokes down the same branching channel, the channel cooling), the spider
# lightning, the arcs skittering where it strikes and its sparks and steam (the original's Particles, run here at its
# own 120 Hz steps) are worked out here frame by frame from the original's seeded generators and replayed by a
# draw-list shader (_list.gdshader, with soft and light passes).
extends "res://build/fx/weather/_weather.gd"

const D := 10.0
const S := 5
const T_LEAD := 2.62
const T1 := 3.0
const T2 := 3.3
const T_SHEET := 6.4
const T_FAR := 8.6
const BX0 := 62.0
const BY0 := -136.0
const BX1 := 52.0
const BY1 := 3.0
const F1 := [1.0, 0.62, 0.95, 0.4, 0.7, 0.22]
const F2 := [0.92, 0.5, 0.8, 0.3, 0.12]
# draw-list colours: V0..V5, white, C0..C7, steam
const WI := 6
const CI := 7
const STEAM := 15
const LINE := 0
const DOT := 1
const CIRC := 2
const PXS := 3
const PXS2 := 4
const DISC := 5
const GLOW := 6

var P1 := []
var P2 := []
var CRAWL := []


func make() -> void:
	var C := fitc("palette", 8)
	var V := fitc("bolt", 6)
	var W := Color.WHITE
	keep_colour(W)
	var steam := mixc(C[4], V[3], 0.3)
	var PAL := []
	for c in V:
		PAL.append(c)
	PAL.append(W)
	for c in C:
		PAL.append(c)
	PAL.append(steam)
	var vg := mixc(C[3], V[3], 0.5)
	keep_mix(C[1], vg, 16)
	keep_mix(C[4], V[3], 8)
	P1 = channel()
	var trunk: Array = P1[0].pts
	var restrike := tree(JsRng.new(S * 31 + 2), BX0, BY0, BX1, BY1, 0.3, 0.3)
	P2 = [P1[0]]
	for i in range(1, mini(3, restrike.size())):
		P2.append(restrike[i])
	CRAWL = tree(JsRng.new(S * 7 + 3), -150, -138, -26, -134, 0.2, 0.7)
	var n := int(roundf(D * 30.0))
	var ts := []
	var ft := 0.0
	for i in n:
		ts.append(roundf(ft * 3e4) / 3e4)
		ft += 1.0 / 30.0
	var fk := []
	var shk := []
	var srck := []
	for i in n:
		var t: float = ts[i]
		var f := flash_at(t)
		var sh := sheet_at(t)
		var lead := 0.25 + 0.2 * sin(t * 70.0) if t > T_LEAD and t < T1 else 0.0
		var pre := 0.12 * maxf(0.0, sin((t - T_LEAD) * 41.0)) if t > T_LEAD - 0.5 and t < T_LEAD else 0.0
		fk.append([i / 30.0, f])
		shk.append([i / 30.0, sh])
		var s0 := f + lead * 0.5 + pre if f + lead + pre > 0.0 else 0.0
		srck.append([i / 30.0, Vector4(s0, maxf(sh, 0.0), maxf(blink(t - T_FAR, 0.45), 0.0), maxf(blink(t - 0.9, 0.3), 0.0))])
	var Fd := field_tex(S * 3 + 1)
	var pr := {"C": C, "V": V, "white": W, "veil_glow": vg, "sky_light": mixc(V[2], V[3], 0.6), "seed": S,
		"M": field_tex(S + 4, 256, 128, [4, 8, 16]), "FL": field_tex(S + 3)}
	var keyed := []
	keyed.append(sky("Light", "storm_light", pr.merged({"pass_": 0, "F": Fd}), {"layer": "light"}))
	keyed.append(sky("Veil", "storm", pr.merged({"pass_": 1, "F": field_tex(S + 11, 256, 128, [4, 8, 16]), "soft": true}), {"layer": "soft"}))
	var rpr := {"seed": S, "f": 0.0}
	var far := bodies("RainFar", 300, "storm_rain", "streak", 12, rpr.merged({"layer": 0, "mode": 1, "split": 0.4,
		"tail": [C[4], C[4], C[5]], "bodyc": [C[4], C[4], C[5]], "head": [C[5], C[6], C[6]]}))
	key(far, "process_material:shader_parameter/f", fk, "nearest")
	# the draw lists: the bolt behind the deck; the spider lightning, the pools' reflection and the strike after the floor
	var bolt_l := []
	var post_l := []
	var light_l := []
	for i in n:
		var t: float = ts[i]
		var b := []
		var p := []
		var l := []
		bolt_calls(t, b, l)
		crawler(t, p, l)
		reflection(t, p)
		strike(t, p, l)
		bolt_l.append(b)
		post_l.append(p)
		light_l.append(l)
	draw_list("Bolt", "list", bolt_l, PAL)
	keyed.append(sky("DeckHaze", "storm", pr.merged({"pass_": 2, "F": Fd, "soft": true}), {"layer": "soft"}))
	keyed.append(sky("Deck", "storm", pr.merged({"pass_": 2, "F": Fd, "soft": false})))
	keyed.append(sky("FloorWet", "storm", pr.merged({"pass_": 3, "F": Fd, "soft": true}), {"layer": "soft"}))
	keyed.append(sky("Floor", "storm", pr.merged({"pass_": 3, "F": Fd, "soft": false})))
	draw_list("Strike", "list", post_l, PAL)
	draw_list("Steam", "list_soft", post_l, PAL, "soft")
	draw_list("Glows", "list_light", light_l, PAL, "light")
	for k in keyed:
		key(k, "material:shader_parameter/f", fk, "nearest")
		key(k, "material:shader_parameter/sh", shk, "nearest")
		key(k, "material:shader_parameter/src", srck, "nearest")
	var near := bodies("RainNear", 84, "storm_rain", "streak", 32, rpr.merged({"layer": 1, "mode": 0, "split": 0.55, "ta0": 1.0,
		"ta1": 0.0, "tail": [C[4], C[5], V[3]], "bodyc": [C[6], C[6], V[4]], "head": [C[7], W, W]}))
	key(near, "process_material:shader_parameter/f", fk, "nearest")
	var sp := bodies("Splashes", 84, "storm_rain", "splash", 48, rpr.merged({"layer": 2, "hot": [C[7], W, W], "cool": [C[5], C[6], V[4]]}))
	key(sp, "process_material:shader_parameter/f", fk, "nearest")


## A draw list over the canvas: per frame, the entries [ax, ay, bx, by, kind, colour, alpha, radius].
func draw_list(name: String, shader: String, frames_: Array, PAL: Array, layer := "color") -> ColorRect:
	var total := 0
	for fl in frames_:
		total += fl.size()
	var w := 1024
	var rows_ := maxi(1, int(ceil(total * 2 / float(w))))
	var img := Image.create(w, rows_, false, Image.FORMAT_RGBAF)
	var idx := Image.create(frames_.size(), 1, false, Image.FORMAT_RGF)
	var e := 0
	for f in frames_.size():
		idx.set_pixel(f, 0, Color(e, frames_[f].size(), 0))
		for q in frames_[f]:
			var i0 := e * 2
			img.set_pixel(i0 % w, i0 / w, Color(q[0], q[1], q[2], q[3]))
			img.set_pixel((i0 + 1) % w, (i0 + 1) / w, Color(q[4], q[5], q[6], q[7]))
			e += 1
	var nm := name.to_snake_case()
	var o := {} if layer == "color" else {"layer": layer}
	return sky(name, shader, {"data": asset("_" + nm, img), "index": asset("_" + nm + "_index", idx), "frames": float(frames_.size()),
		"PAL": PAL}, o)


# ------------------------------------------------------------------ the original's timing

func env(t: float, t0: float, E: Array) -> float:
	var i := int(floor((t - t0) * 30.0 + 1e-3))
	return E[i] if i >= 0 and i < E.size() else 0.0


func flash_at(t: float) -> float:
	return maxf(env(t, T1, F1), env(t, T2, F2))


func sheet_at(t: float) -> float:
	var a := t - T_SHEET
	if a < 0.0 or a > 0.9:
		return 0.0
	var p1 := exp(-pow((a - 0.08) / 0.05, 2.0))
	var p2 := exp(-pow((a - 0.3) / 0.09, 2.0))
	var tail := exp(-(a - 0.3) * 6.0) * 0.5 if a > 0.3 else 0.0
	return minf(1.0, 0.7 * p1 + p2 + tail) * (0.75 if int(floor(a * 30.0)) % 3 == 1 else 1.0)


func blink(a: float, k: float) -> float:
	if a < 0.0 or a > 0.3:
		return 0.0
	return k * (exp(-pow((a - 0.06) / 0.04, 2.0)) + 0.65 * exp(-pow((a - 0.18) / 0.05, 2.0)))


# ------------------------------------------------------------------ the channel (src/fx/weather/_lib.js tree())

func tree(R: JsRng, x0: float, y0: float, x1: float, y1: float, jag := 0.3, forks := 0.4, w := 1.0, depth := 0) -> Array:
	var out := []
	var L := Vector2(x1 - x0, y1 - y0).length()
	var pts := [Vector2(x0, y0), Vector2(x1, y1)]
	var off := L * jag
	while pts.size() < 2 + L / 3.0:
		var nxt := [pts[0]]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var l := hypot(b.x - a.x, b.y - a.y)
			if l == 0.0:
				l = 1.0
			var o := R.range(-off, off)
			nxt.append(Vector2((a.x + b.x) / 2.0 + (-(b.y - a.y) / l) * o, (a.y + b.y) / 2.0 + ((b.x - a.x) / l) * o))
			nxt.append(b)
		pts = nxt
		off *= 0.52
	out.append({"pts": pts, "w": w, "depth": depth})
	if depth < 2:
		for i in range(2, pts.size() - 3):
			if R.chance(forks / (1 + depth) / maxf(4.0, pts.size() / 6.0)):
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[mini(pts.size() - 1, i + 3)]
				var sg := R.sign()
				var ang := atan2(b.y - a.y, b.x - a.x) + sg * R.range(0.35, 0.95)
				var l := (L - (i / float(pts.size())) * L) * R.range(0.25, 0.55)
				out += tree(R, a.x, a.y, a.x + cos(ang) * l, a.y + sin(ang) * l, jag * 1.1, forks, w * 0.55, depth + 1)
	return out


static func hypot(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


func channel() -> Array:
	var R := JsRng.new(S * 31 + 1)
	var P := tree(R, BX0, BY0, BX1, BY1, 0.26, 0.18)
	var pts: Array = P[0].pts
	var side := R.sign()
	var us := [0.2, 0.38, 0.55]
	for i in 3:
		var u: float = us[i]
		var k := int(floor(u * (pts.size() - 1)))
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[mini(pts.size() - 1, k + 3)]
		var ang := atan2(b.y - a.y, b.x - a.x) + (-side if i % 2 else side) * R.range(0.6, 1.0)
		var l := R.range(36.0, 56.0) * (1.0 - u * 0.45)
		P += tree(R, a.x, a.y, a.x + cos(ang) * l, a.y + sin(ang) * l, 0.3, 0.5, 0.6, 1)
	return P


# ------------------------------------------------------------------ the draw calls, frame by frame

static func E(a: Vector2, b: Vector2, kind: int, col: int, alpha := 1.0, r := 0.0) -> Array:
	return [a.x, a.y, b.x, b.y, kind, col, alpha, r]


func bolt_calls(t: float, out: Array, lights: Array) -> void:
	if not (t > T_LEAD and t < T2 + 0.7):
		return
	if t < T1:
		var reach := BY0 + (BY1 - BY0) * pow(floor(((t - T_LEAD) / (T1 - T_LEAD)) * 9.0) / 9.0, 1.25)
		for p in P1:
			var pts: Array = p.pts
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				if b.y > reach:
					break
				out.append(E(a, b, LINE, 2 if p.w >= 1.0 else 1))
				if i % 4 == 0:
					lights.append(E(a, a, GLOW, 3, 0.22 * p.w, 6.0))
		return
	var s := 2 if t >= T2 else 1
	var a0 := t - (T2 if s == 2 else T1)
	var k := env(t, T2 if s == 2 else T1, F2 if s == 2 else F1)
	var paths: Array = P2 if s == 2 else P1
	if k > 0.0:
		for ps in 3:
			for p in paths:
				var trunk: bool = p.w >= 1.0
				if not trunk and (k < 0.4 or (ps == 0 and p.w < 0.5)):
					continue
				var pts: Array = p.pts
				for i in pts.size() - 1:
					var a: Vector2 = pts[i]
					var b: Vector2 = pts[i + 1]
					if ps == 0:
						out.append(E(a, b, CIRC, 2 if k > 0.6 else 1, 1.0, (2.3 if k > 0.6 else 1.7) if trunk else 1.2))
						if i % 3 == 0:
							lights.append(E(a, a, GLOW, 3, (0.5 if trunk else 0.3) * k * p.w, 18.0 if trunk else 8.0))
					elif ps == 1:
						out.append(E(a, b, CIRC, 4 if trunk else 3, 1.0, (1.4 if k > 0.6 else 0.9) if trunk else 0.6))
					elif trunk:
						out.append(E(a, b, PXS2 if k > 0.85 else PXS, WI if k > 0.3 else 4))
					elif p.w > 0.4 and k > 0.6:
						out.append(E(a, b, PXS, 4))
	elif a0 < 0.5:
		var g := 1.0 - a0 / 0.5
		for p in paths:
			if p.w >= 1.0:
				for q in p.pts:
					out.append(E(q, q, DOT, 1, g * 0.9))


func crawler(t: float, out: Array, lights: Array) -> void:
	var a := t - T_SHEET - 0.22
	if a < 0.0 or a > 0.17:
		return
	var reach := -150.0 + 130.0 * minf(1.0, (floor(a * 30.0) + 1.0) / 3.0)
	var k := 1.0 if a < 0.1 else 0.5
	for p in CRAWL:
		var pts: Array = p.pts
		for i in pts.size() - 1:
			var A: Vector2 = pts[i]
			var B: Vector2 = pts[i + 1]
			if A.x > reach:
				break
			out.append(E(A, B, LINE, 4 if p.w >= 1.0 and k > 0.6 else 3))
			if p.w >= 1.0:
				out.append(E(A + Vector2(0, 1), A + Vector2(0, 1), DOT, 2, k))
			if i % 3 == 0:
				lights.append(E(A, A, GLOW, 3, 0.35 * k * p.w, 10.0))


func reflection(t: float, out: Array) -> void:
	var f := flash_at(t)
	if f <= 0.2:
		return
	for y in range(1, 10):
		if rand([y, int(floor(t * 30.0)), 3]) < 0.8:
			var q := Vector2(BX1 + sin(y * 1.7 + t * 40.0) * 1.2, y)
			out.append(E(q, q, DOT, WI if y < 4 else 4, f * (1.1 - y / 12.0)))


func strike(t: float, out: Array, lights: Array) -> void:
	var a := t - T1
	if a < 0.0 or a > 1.8:
		return
	var k := flash_at(t)
	if k > 0.0:
		var fr := int(floor(t * 30.0 + 1e-3))
		var Rc := JsRng.new(S * 977 + fr)
		for i in 4:
			var side := 1.0 if i % 2 else -1.0
			var l := Rc.range(10.0, 30.0) * (0.6 + 0.4 * k)
			var yy := BY1 + Rc.range(-2.0, 3.0)
			for p in tree(Rc, BX1 + side, BY1 - 1.0, BX1 + side * l, yy, 0.35, 0.5, 0.6, 1):
				var pts: Array = p.pts
				for j in pts.size() - 1:
					out.append(E(pts[j], pts[j + 1], LINE, 4 if k > 0.6 and p.w > 0.5 else 3))
				lights.append(E(pts[pts.size() >> 1], pts[pts.size() >> 1], GLOW, 3, 0.3 * k, 8.0))
		var c := Vector2(BX1, BY1 - 1.0)
		out.append(E(c, c, CIRC, 4, 1.0, 2.0 + 3.0 * k))
		out.append(E(c, c, CIRC, WI, 1.0, 1.0 + 2.0 * k))
		lights.append(E(Vector2(BX1, BY1 - 12), Vector2.ZERO, GLOW, 2, 0.55 * k, 95.0))
		lights.append(E(Vector2(BX1, BY1 - 4), Vector2.ZERO, GLOW, 3, 0.5 * k, 40.0))
		lights.append(E(Vector2(BX1, BY1 - 2), Vector2.ZERO, GLOW, WI, 0.6 * k, 14.0))
	# the original's Particles, replayed from the strike at its 120 Hz steps
	var R := JsRng.new(S * 13 + 5)
	var ps := []
	burst(ps, R, 48, 1.0)
	var tt := 0.0
	var second := false
	var dt := 1.0 / 120.0
	while tt + dt <= a:
		if not second and tt >= T2 - T1:
			second = true
			burst(ps, R, 16, 0.7)
		update(ps, dt)
		tt += dt
	for q in ps:
		if q.delay > 0.0:
			continue
		var kk: float = q.life / q.max
		var sp := hypot(q.vx, q.vy)
		if sp == 0.0:
			sp = 1.0
		var u := Vector2(q.vx / sp, q.vy / sp)
		var x := Vector2(q.x, q.y)
		if q.k == 0:
			var head := WI if kk > 0.6 else 4 if kk > 0.3 else 3
			var len := minf(9.0, 1.0 + sp * 0.022)
			out.append(E(x - u * len, x - u * len * 0.4, LINE, head if kk > 0.5 else 2))
			out.append(E(x - u * len * 0.45, x, LINE, head))
			lights.append(E(x, x, GLOW, head, 0.45 * kk, 3.0))
		else:
			var r: float = q.size * (0.6 + (1.0 - kk) * 0.9)
			out.append(E(x, x, DISC, STEAM, pow(kk, 1.3) * 0.45, r))
			lights.append(E(x, x, GLOW, 2, 0.16 * kk, r * 1.8))
	if a < 1.6:
		lights.append(E(Vector2(BX1, BY1), Vector2.ZERO, GLOW, 2, 0.4 * pow(1.0 - a / 1.6, 2.0), 16.0))


func spawn(ps: Array, R: JsRng, k: int, x: float, y: float, vx: float, vy: float, life: float, size := 1.0, delay := 0.0) -> void:
	ps.append({"k": k, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "size": size, "seed": R.next() * 100.0, "delay": delay})


func burst(ps: Array, R: JsRng, n: int, pw: float) -> void:
	for i in n:
		var an := -PI / 2.0 + R.range(-1.35, 1.35)
		var sp := R.range(110.0, 420.0) * pw
		var life := R.range(0.18, 0.6)
		spawn(ps, R, 0, BX1, BY1 - 1.0, cos(an) * sp, sin(an) * sp, life)
	var i := 0
	while i < 6.0 * pw:
		var sd := R.sign()
		var x := BX1 + sd * R.range(2.0, 8.0)
		var y := BY1 - R.range(1.0, 3.0)
		var vx := sd * R.range(30.0, 90.0)
		var vy := -R.range(4.0, 16.0)
		var life := R.range(0.6, 1.2)
		var size := R.range(2.5, 4.5)
		var delay := R.range(0.0, 0.08)
		spawn(ps, R, 4, x, y, vx, vy, life, size, delay)
		i += 1


func update(ps: Array, dt: float) -> void:
	var i := ps.size() - 1
	while i >= 0:
		var p: Dictionary = ps[i]
		if p.delay > 0.0:
			p.delay -= dt
			i -= 1
			continue
		p.life -= dt
		if p.life <= 0.0:
			ps.remove_at(i)
			i -= 1
			continue
		if p.k == 0:
			p.vy += 950.0 * 0.45 * dt
			p.vx -= p.vx * 2.2 * dt
			p.vy -= p.vy * 2.2 * dt
			var g := 4.0
			var ny: float = p.y + p.vy * dt
			p.x += p.vx * dt
			if p.vy > 0.0 and p.y <= g and ny >= g:
				p.vy = -p.vy * 0.45
				p.vx *= 0.7
				p.y = g - 0.25
			else:
				p.y = ny
		else:
			p.vx -= p.vx * 4.0 * dt
			p.vy -= p.vy * 4.0 * dt + 5.0 * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
		i -= 1
