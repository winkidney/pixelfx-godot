# Shared by the ui build scripts (not an effect). The originals (src/fx/ui/*.js) are little simulations: create()
# keeps state that update(dt) steps at 120 Hz and draw(p) paints each frame (words through _lib.js drawWord, HUD
# plates, sparks and stars from sim.js Particles, Bits and Lights). Here the build script replays that update() at
# the reference's own steps and clock, frame by frame, and records what each frame draws:
#   - the particles and small marks (dots, lines, sparkles, rings, circles, beams, shards, coins...) become frame
#     tables (table()): GPU particles placed from the keyed clock by fx/ui/_ftp.gdshader, drawn cell by cell as the
#     original's painter draws them by fx/ui/_bits.gdshader;
#   - every light (p.glow, glowRing, glowLine, Lights, each spark's and star's own glow) is a particle of a light table
#     (fx/ui/_bits_light.gdshader), added as the original's light buffer adds it;
#   - words are fx/ui/_word.gdshader (drawWord pixel for pixel, the original's own fonts), their letters keyed every
#     frame;
#   - bigger bodies (plates, bars, medals, hearts) are each effect's own canvas shaders with keyed uniforms (fk()).
# Extends the pickups helpers for the original's randomness (JsRng, rand), colour maths and frame clock.
extends "res://build/fx/pickups/_pickups.gd"

const UI_DIR := "res://addons/pixelfx_particles/fx/ui/"
const PFont := preload("res://addons/pixelfx_particles/core/pixel_font.gd")
const Q_LIGHT := 1
const Q_DOT := 2
const Q_LINE := 3
const Q_SPARKLE := 4
const Q_CIRCLE := 5
const Q_RING := 6
const Q_OVAL := 7
const Q_BEAM := 8
const Q_SHARD := 9
const Q_RECT := 11
const Q_GLOW_RING := 12
const Q_GLOW_LINE := 13
const Q_COIN := 20
const Q_PAPER := 21
const Q_PLATE := 22
const Q_SPOKE := 23
const ROWS := 5
const DT := (1.0 / 30.0) / 4.0
const BLACK := Color(0, 0, 0, 1)
const LAY_W := 64
const TEX_W := 1024

var _rec := {}
var _lit := []
var _fi := 0
var _kbuf := {}
var _knodes := {}
var _words := []
## Where recorded marks go: a table name (see utable()).
var lay := "front"
## The effect's own clock (the original's `t`), advanced by step().
var T := 0.0


func begin(effect_id: String) -> void:
	super(effect_id)
	for i in NF:
		_lit.append([])


func ush(name: String) -> Shader:
	return load(UI_DIR + "_" + name + ".gdshader")


## Run the original frame by frame: upd(dt) at its 120 Hz steps (four a frame), then drw(f) records frame f.
func run(upd: Callable, drw: Callable) -> void:
	T = 0.0
	for f in NF:
		if f > 0:
			for s in 4:
				T += DT
				upd.call(DT)
		_fi = f
		drw.call(f)


# ------------------------------------------------------------------ maths (math.js)

static func noise(x: float, seed_: int = 0) -> float:
	var i := floorf(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(rand([i, seed_]), rand([i + 1.0, seed_]), u) * 2.0 - 1.0


static func noise2(x: float, y: float, seed_: int = 0) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var a := rand([ix, iy, seed_])
	var b := rand([ix + 1.0, iy, seed_])
	var c := rand([ix, iy + 1.0, seed_])
	var d := rand([ix + 1.0, iy + 1.0, seed_])
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


static func fract(x: float) -> float:
	return x - floorf(x)


static func in_back(t: float, s := 1.70158) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return (s + 1.0) * t * t * t - s * t * t


static func in_out_quad(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0


## _lib.js shake(): a whole-pixel shake that dies away, [dx, dy]
static func shake(t: float, amp: float, t0 := 0.0, len_ := 0.3, seed_ := 1, hz := 32.0) -> Array:
	if t < t0 or t > t0 + len_:
		return [0.0, 0.0]
	var k := 1.0 - (t - t0) / len_
	return [jround(noise(t * hz, seed_) * amp * k * 1.7), jround(noise(t * hz, seed_ + 7) * amp * k * 1.3)]


## _lib.js spell(): letters of s in a pixel font, laid out in font pixels
static func spell(s: String, font := "big") -> Dictionary:
	var F: Dictionary = PFont.FONTS[font]
	var letters := []
	var x := 0
	for ch in s:
		var g: Variant = PFont._glyph(F, ch)
		var w: int = g.w if g != null else F.space
		letters.append({"ch": ch, "g": g, "x": x, "w": w})
		x += w + F.gap
	return {"letters": letters, "w": maxi(0, x - F.gap), "h": F.h, "font": font}


static func glyphs_of(sp: Dictionary) -> Array:
	return sp.letters.filter(func(L: Dictionary) -> bool: return L.g != null)


# ------------------------------------------------------------------ the painter, recorded (painter.js)

func _put(e: Dictionary) -> void:
	var L: Array = _rec.get(lay, [])
	if L.is_empty():
		for i in NF:
			L.append([])
		_rec[lay] = L
	L[_fi].append(e)


static func _cols(c: Variant) -> Array:
	var a: Array = c if c is Array else [c]
	while a.size() < 3:
		a.append(a[-1])
	return a


func _e(k: int, x: float, y: float, a: float, c: Variant, p: Array, reach: float) -> Dictionary:
	return {"k": k, "x": floorf(x), "y": floorf(y), "a": a, "c": _cols(c), "p": p, "q": 2 * int(ceilf(reach)) + 1}


func pdot(x: float, y: float, c: Color, a := 1.0) -> void:
	if a > 0.0:
		_put(_e(Q_DOT, x, y, a, c, [], 0.0))


## painter.js line(): cols one colour or [c1, c2, c3] by u (u < t1: c1, u < t2: c2, else c3; o.le: <=, o.rev: u from
## the far end); o.al [s, A0, A1, B0, B1]: alpha A0 + A1 u below s, B0 + B1 u from it; o.a multiplies. Which band and
## which alpha piece each step takes is decided here, in doubles, as the original decides it (u = i / n lands on a
## threshold exactly more often than not); the shader gets the steps where they change.
func pline(x0: float, y0: float, x1: float, y1: float, cols: Variant, o := {}) -> void:
	var ts: Array = o.get("t", [2.0, 2.0])
	var al: Array = o.get("al", [2.0, 1.0, 0.0, 1.0, 0.0])
	var cs := _cols(cols)
	var ex := floorf(x1) - floorf(x0)
	var ey := floorf(y1) - floorf(y0)
	var rev: bool = o.get("rev", false)
	var le: bool = o.get("le", false)
	var n := maxf(absf(ex), absf(ey))
	if n == 0.0:
		n = 1.0
	var runs := []
	var bounds := []
	var a_first := true
	var ia := 1e6
	for i in int(n) + 1:
		var u := i / n
		var uu := 1.0 - u if rev else u
		var b := (0 if uu <= ts[0] else (1 if uu <= ts[1] else 2)) if le else (0 if uu < ts[0] else (1 if uu < ts[1] else 2))
		if runs.is_empty() or runs[-1] != b:
			runs.append(b)
			bounds.append(float(i))
		var pa: bool = uu < al[0]
		if i == 0:
			a_first = pa
		elif pa != a_first and ia > 1e5:
			ia = i
	var rc := []
	for b in runs:
		rc.append(cs[b])
	var i1: float = bounds[1] if bounds.size() > 1 else 1e6
	var i2: float = bounds[2] if bounds.size() > 2 else 1e6
	var a: float = o.get("a", 1.0)
	_put(_e(Q_LINE, x0, y0, a, rc, [ex, ey, i1, i2, ia, 1.0 if a_first else 0.0, al[1], al[2], al[3], al[4], 1.0 if rev else 0.0],
		maxf(absf(ex), absf(ey))))


func pglow(x: float, y: float, r: float, c: Color, k: float) -> void:
	if r < 1.0 or k <= 0.004:
		return
	_lit[_fi].append({"k": Q_LIGHT, "x": floorf(x), "y": floorf(y), "a": 1.0, "c": _cols(c), "p": [x, y, r, k], "q": 2 * int(ceilf(r + 1.0)) + 1})


func pglow_ring(x: float, y: float, R: float, r: float, c: Color, k: float) -> void:
	if r < 1.0 or k <= 0.004:
		return
	_lit[_fi].append({"k": Q_GLOW_RING, "x": floorf(x), "y": floorf(y), "a": 1.0, "c": _cols(c), "p": [x, y, R, k, r], "q": 2 * int(ceilf(R + r + 1.0)) + 1})


func pglow_line(x0: float, y0: float, x1: float, y1: float, r: float, c: Color, k: float) -> void:
	if r < 1.0 or k <= 0.004:
		return
	var reach := maxf(absf(x1 - floorf(x0)), absf(y1 - floorf(y0))) + r + 2.0
	_lit[_fi].append({"k": Q_GLOW_LINE, "x": floorf(x0), "y": floorf(y0), "a": 1.0, "c": _cols(c), "p": [x0, y0, r, k, x1, y1], "q": 2 * int(ceilf(reach)) + 1})


## painter.js light(): light added to one pixel
func plight(x: float, y: float, c: Color, k: float) -> void:
	if k <= 0.004:
		return
	_lit[_fi].append({"k": 14, "x": floorf(x), "y": floorf(y), "a": 1.0, "c": _cols(c), "p": [x, y, 0.0, k], "q": 1})


## sim.js sparkle()
func psparkle(x: float, y: float, arm: float, c: Color, tip: Color, k := 0.6) -> void:
	var n := jround(arm)
	if n < 1.0:
		return
	_put(_e(Q_SPARKLE, x, y, 1.0, [c, tip], [n], n))
	pglow(x, y, 4.0 + n * 2.0, c, k)


## painter.js circle() (and disc(), on a soft table)
func pcircle(cx: float, cy: float, r: float, c: Color, a := 1.0, small := 0.6) -> void:
	if r < small:
		pdot(cx, cy, c, a)
		return
	_put(_e(Q_CIRCLE, cx, cy, a, c, [cx - floorf(cx), cy - floorf(cy), r], r + 1.0))


## painter.js ring(): colours across it by v (0 inner .. 1 outer) as pline's
func pring(cx: float, cy: float, r: float, w: float, cols: Variant, a := 1.0, o := {}) -> void:
	var ts: Array = o.get("t", [2.0, 2.0])
	_put(_e(Q_RING, cx, cy, a, cols, [cx - floorf(cx), cy - floorf(cy), r, w, ts[0], ts[1], 1 if o.get("le", false) else 0], r + 1.0))


## painter.js ellipse() with alpha (d) => d > thr ? a : 0: its rim
func poval(cx: float, cy: float, rx: float, ry: float, c: Color, thr: float, a: float) -> void:
	if rx <= 0.0 or ry <= 0.0 or a <= 0.0:
		return
	_put(_e(Q_OVAL, cx, cy, a, c, [cx - floorf(cx), cy - floorf(cy), rx, ry, thr], maxf(rx, ry) + 1.0))


## painter.js beam(): colours along it by u as pline's
func pbeam(x0: float, y0: float, x1: float, y1: float, width: float, cols: Variant, a := 1.0, o := {}) -> void:
	var ts: Array = o.get("t", [2.0, 2.0])
	var X := floorf(x0)
	var Y := floorf(y0)
	var r := width / 2.0
	_put(_e(Q_BEAM, x0, y0, a, cols, [x0 - X, y0 - Y, x1 - X, y1 - Y, r, ts[0], ts[1], 1 if o.get("le", false) else 0],
		maxf(absf(x1 - X), absf(y1 - Y)) + r + 2.0))


## sim.js Bits SHARD
func pshard(x: float, y: float, ang: float, s: float, c: Color, a: float) -> void:
	_put(_e(Q_SHARD, x, y, a, c, [x - floorf(x), y - floorf(y), cos(ang), sin(ang), s], s / 2.0 + 2.0))


## _ui coin(): coin-collect's coin, r px across, turned so its face is w wide (fx/ui/_bits.gdshader coin_px; its
## colours are the palette ramp's steps, which every table's palette starts with)
func pcoin(x: float, y: float, r: float, w: float, white := false) -> void:
	_put(_e(Q_COIN, x, y, 1.0, C[0], [x - floorf(x), y - floorf(y), r, w, 1.0 if white else 0.0], ceilf(r) + 2.0))


## sim.js band(): a ring lying on the floor, th px thick, its rim the ramp's brightest; keep(angle) picks the half.
## One particle per angle (fx/ui/_bits.gdshader kind 23 draws its dots in to out).
func pband(cx: float, cy: float, r: float, sy: float, th: float, k: float, ramp: Array, keep: Callable, hot := false) -> void:
	if r <= 0.0 or k <= 0.0:
		return
	var n := ramp.size()
	var c4: Color = ramp[n - 4]
	var m := int(ceilf(r * TAU * 1.2))
	# which step (o = th, th - 0.5, ...) each colour starts at, in the original's doubles
	var s1 := 31
	var s2 := 31
	var s3 := 31
	var o := th
	var si := 0
	while o >= 0.0:
		var u := o / th
		if u < 0.7 and s1 == 31:
			s1 = si
		if u < 0.4 and s2 == 31:
			s2 = si
		if u < 0.15 and s3 == 31:
			s3 = si
		o -= 0.5
		si += 1
	var packed := float((1 if hot else 0) | (s1 << 1) | (s2 << 6) | (s3 << 11))
	for j in m:
		var ang := (j / float(m)) * TAU
		var ca := cos(ang)
		var sa := sin(ang)
		if not keep.call(ang):
			continue
		var X := floorf(cx + ca * r)
		var Y := floorf(cy + sa * r * sy)
		_put({"k": Q_SPOKE, "x": X, "y": Y, "a": 1.0, "c": [ramp[n - 1], ramp[n - 2], ramp[n - 3]],
			"p": [cx - floorf(cx), cy - floorf(cy), ca, sa, r, sy, th, k, packed, float(c4.r8 * 65536 + c4.g8 * 256 + c4.b8),
				floorf(cx) - X, floorf(cy) - Y], "q": 2 * int(ceilf(th + 2.0)) + 1})
		keep_colour(c4)


## sim.js flare(): an 8-ray flare of dots, long on the axes, fading along them
func pflare(x: float, y: float, L: float, k: float, ramp: Array) -> void:
	if L < 1.0:
		return
	var n := ramp.size()
	for i in 8:
		var an := (i * PI) / 4.0
		var ln := L if i % 4 == 0 else (L * 0.6 if i % 2 == 0 else L * 0.3)
		var ca := cos(an)
		var sa := sin(an)
		var d := 0.0
		while d <= ln:
			var u := d / ln
			pdot(x + ca * d, y + sa * d, Color.WHITE if u < 0.35 else (ramp[n - 2] if u < 0.7 else ramp[n - 3]), 1.0 if u < 0.6 else k * 1.5 * (1.0 - u) + 0.2)
			d += 0.5


## painter.js rect() (unrotated)
func prect(x: float, y: float, w: float, h: float, c: Color, a := 1.0) -> void:
	var X0 := jround(x)
	var Y0 := jround(y)
	var W := jround(x + w) - X0
	var H := jround(y + h) - Y0
	if W <= 0.0 or H <= 0.0:
		return
	_put(_e(Q_RECT, X0, Y0, a, c, [W, H], maxf(W, H)))


# ------------------------------------------------------------------ sim.js: Particles, Bits, Lights

func sim_new(R: JsRng, sparks: Array, ground := INF) -> Dictionary:
	return {"R": R, "list": [], "t": 0.0, "sparks": sparks, "ground": ground}


func spawn(s: Dictionary, k: int, x: float, y: float, vx: float, vy: float, life: float, col := Color.WHITE, size := 1.0, delay := 0.0, flag := 0) -> void:
	var R: JsRng = s.R
	s.list.append({"k": k, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "col": col, "size": size,
		"seed": R.next() * 100.0, "delay": delay, "flag": flag})


func sim_update(s: Dictionary, dt: float) -> void:
	s.t += dt
	var t: float = s.t
	var L: Array = s.list
	for i in range(L.size() - 1, -1, -1):
		var p: Dictionary = L[i]
		if p.delay > 0.0:
			p.delay -= dt
			continue
		p.life -= dt
		if p.life <= 0.0:
			L.remove_at(i)
			continue
		var k: int = p.k
		if k == SPARK:
			p.vy += GRAVITY * 0.45 * dt
			p.vx -= p.vx * 2.2 * dt
			p.vy -= p.vy * 2.2 * dt
			var g: float = s.ground
			var ny: float = p.y + p.vy * dt
			p.x += p.vx * dt
			if p.vy > 0.0 and p.y <= g and ny >= g:
				p.vy = -p.vy * 0.45
				p.vx *= 0.7
				p.y = g - 0.25
			else:
				p.y = ny
			continue
		elif k == STREAK:
			p.vx += p.vx * 3.0 * dt
			p.vy += p.vy * 3.0 * dt
		elif k == FLAKE:
			p.vx -= p.vx * 2.2 * dt
			p.vy -= p.vy * 2.2 * dt - 35.0 * dt
			p.x += sin(t * 2.5 + p.seed) * 7.0 * dt
		elif k == EMBER:
			p.vy += (-30.0 + sin(t * 3.0 + p.seed) * 20.0) * dt
			p.vx += cos(t * 2.3 + p.seed) * 45.0 * dt
			p.vx -= p.vx * 1.6 * dt
			p.vy -= p.vy * 1.6 * dt
		elif k == SMOKE:
			var big: bool = p.flag & PF_BIG
			p.vy -= (23.0 if big else 16.0) * dt
			p.vx += sin(t * 1.3 + p.seed) * 8.0 * dt
			p.vx -= p.vx * 1.6 * dt
			p.vy -= p.vy * 1.2 * dt
		elif k == MOTE:
			p.vx -= p.vx * 0.6 * dt
			p.vy -= p.vy * 0.6 * dt
		else:
			var drag := 4.0 if k in SOFT_KINDS else 1.6
			p.vx -= p.vx * drag * dt
			p.vy -= p.vy * drag * dt + 5.0 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt


## sim.js Particles.draw: layer "back" (soft kinds, PF_BACK), "front" (the rest), "" both. Soft kinds record on
## table `soft` (a translucent table).
func sim_draw(s: Dictionary, layer := "", soft := "soft") -> void:
	var S: Array = s.sparks
	for q in s.list:
		if q.delay > 0.0:
			continue
		var kk: int = q.k
		if layer != "" and ("back" if (kk in SOFT_KINDS or q.flag & PF_BACK) else "front") != layer:
			continue
		var k: float = q.life / q.max
		var x: float = q.x
		var y: float = q.y
		var sp: float = sqrt(q.vx * q.vx + q.vy * q.vy)
		if sp == 0.0:
			sp = 1.0
		var ux: float = q.vx / sp
		var uy: float = q.vy / sp
		var col: Color = q.col
		if kk == SPARK:
			var head: Color = S[0] if k > 0.6 else (S[1] if k > 0.3 else S[2])
			var ln := minf(9.0, 1.0 + sp * 0.022)
			pline(x - ux * ln, y - uy * ln, x - ux * ln * 0.4, y - uy * ln * 0.4, head if k > 0.5 else S[-1])
			pline(x - ux * ln * 0.45, y - uy * ln * 0.45, x, y, head)
			pglow(x, y, 3.0, head, 0.45 * k)
		elif kk == MOTE:
			var ln: float = minf(16.0, 0.5 + sp * 0.026) * q.size
			var a := k / 0.35 if k < 0.35 else 1.0
			pline(x - ux * ln, y - uy * ln, x - ux * ln * 0.35, y - uy * ln * 0.35, scalec(col, 0.55), {"a": a})
			pline(x - ux * ln * 0.4, y - uy * ln * 0.4, x, y, col, {"a": a})
			pglow(x, y, 2.5 + q.size, col, 0.4 * k)
		elif kk == DUST:
			var keep := lay
			lay = soft
			pcircle(x, y, q.size * (0.6 + (1.0 - k) * 0.9), col, pow(k, 1.3) * 0.7, 0.5)
			lay = keep
		elif kk == SMOKE:
			var keep := lay
			lay = soft
			var age := 1.0 - k
			var big: bool = q.flag & PF_BIG
			var r: float = q.size * (0.65 + minf(1.0, age * 2.5) * 0.45 + age * (0.5 if big else 0.4))
			var a := minf(1.0, age * 12.0) * minf(1.0, k * 2.4) * (0.7 if big else 0.58)
			var c := mixc(col, _ramp_at(SMOKE_RAMP, age), age)
			pcircle(x, y, r, c, a * 0.45, 0.5)
			pcircle(x + r * 0.05, y + r * 0.06, r * 0.74, c, a * 0.62, 0.5)
			if age < 0.5:
				pcircle(x - r * 0.22, y - r * 0.3, r * 0.5, mixc(c, Color.WHITE, 0.12), a * 0.4 * (1.0 - age * 2.0), 0.5)
			lay = keep
		elif kk == EMBER:
			var c: Color = S[0] if k > 0.6 else (S[1] if k > 0.3 else S[2])
			if k < 0.25 and sin(s.t * 40.0 + q.seed) < 0.0:
				continue
			pdot(x, y, c)
			if q.size > 1.5:
				pdot(x, y + 1.0, S[-1])
			pglow(x, y, 3.0 + q.size, c, 0.35 * k)
		elif kk == STAR:
			var tw: float = 0.6 + 0.4 * sin(s.t * (8.0 + fmod(q.seed, 5.0)) + q.seed)
			if q.size < 1.0:
				if tw * k > 0.25:
					pdot(x, y, Color.WHITE if tw > 0.8 else col)
				pglow(x, y, 3.0, col, 0.4 * k * tw)
			else:
				psparkle(x, y, q.size * tw * minf(1.0, k * 3.0), col, scalec(col, 0.75), 0.5 * k * tw)


static func _ramp_at(r: Array, t: float) -> Color:
	return Color(r[clampi(int(floorf(t * r.size())), 0, r.size() - 1)])


func bits_new(ground := INF) -> Dictionary:
	return {"list": [], "ground": ground}


func bits_add(b: Dictionary, o: Dictionary) -> void:
	var life: float = o.get("life", 1.0)
	var q := {"kind": 0, "vx": 0.0, "vy": 0.0, "a": 0.0, "va": 0.0, "s": 1.0, "c": Color.WHITE, "g": 1.0, "drag": 0.0, "bounce": 0.0, "rest": false}
	q.merge(o, true)
	q.life = life
	q.max = life
	b.list.append(q)


func bits_update(b: Dictionary, dt: float) -> void:
	var L: Array = b.list
	for i in range(L.size() - 1, -1, -1):
		var q: Dictionary = L[i]
		q.life -= dt
		if q.life <= 0.0:
			L.remove_at(i)
			continue
		if q.rest:
			continue
		q.vy += GRAVITY * q.g * dt
		q.vx -= q.vx * q.drag * dt
		q.vy -= q.vy * q.drag * dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		q.a += q.va * dt
		var fl: float = b.ground
		var sp: float = q.vy
		if q.g <= 0.0 or q.y < fl or sp <= 0.0:
			continue
		q.y = fl - 0.01
		if q.bounce > 0.0 and sp > 70.0:
			q.vy = -sp * q.bounce
			q.vx *= 0.7
			q.va *= 0.6
		else:
			q.rest = true
			q.vx = 0.0
			q.vy = 0.0


func bits_draw(b: Dictionary) -> void:
	for q in b.list:
		pshard(q.x, q.y, q.a, q.s, q.c, minf(1.0, q.life / 0.4))


func lights_new() -> Dictionary:
	return {"list": []}


func lights_add(L: Dictionary, x: float, y: float, r: float, c: Color, k: float, life: float) -> void:
	L.list.append([x, y, r, c, k, life, life])


func lights_update(L: Dictionary, dt: float) -> void:
	var a: Array = L.list
	for i in range(a.size() - 1, -1, -1):
		a[i][5] -= dt
		if a[i][5] <= 0.0:
			a.remove_at(i)


func lights_draw(L: Dictionary) -> void:
	for l in L.list:
		var k: float = l[5] / l[6]
		pglow(l[0], l[1], l[2] * (0.55 + 0.45 * k), l[3], l[4] * k * k)


# ------------------------------------------------------------------ tables

## The marks recorded on table `src` as a GPU particle emitter (colour layer; o.soft: translucent, as the original
## blends its soft discs; o.raw: translucent and unsnapped, for smoke mixed toward its own ramp). o: parent (a group
## placed where it draws among the rest), back.
func utable(name: String, src: Variant = null, o := {}) -> GPUParticles2D:
	var rows: Array = _rec.get(name if src == null else src, [])
	if rows.is_empty():
		return null
	return _table(name, rows, false, o)


## Every light recorded, as one emitter on the light layer.
func light_table(name := "Light") -> GPUParticles2D:
	return _table(name, _lit, true, {})


func _table(name: String, rows: Array, lit: bool, o: Dictionary) -> GPUParticles2D:
	var slots := 1
	for r in rows:
		slots = maxi(slots, (r as Array).size())
	# each frame's first entry and count, then the entries one after another (5 texels each), 1024 texels a row
	var total := 0
	for r in rows:
		total += (r as Array).size()
	var head := int(ceilf(NF / float(ROWS))) * ROWS
	var texels := head + total * ROWS
	var img := Image.create(TEX_W, maxi(1, int(ceilf(texels / float(TEX_W)))), false, Image.FORMAT_RGBAF)
	var raw: bool = o.get("raw", false)
	var at := 0
	for f in NF:
		var r: Array = rows[f] if f < rows.size() else []
		img.set_pixel(f % TEX_W, f / TEX_W, Color(at, r.size(), head, 0))
		for e in r:
			var ci := []
			for c in e.c:
				ci.append(float(c.r8 * 65536 + c.g8 * 256 + c.b8))
				if not lit and not raw:
					keep_colour(c)
			var p: Array = e.p.duplicate()
			while p.size() < 12:
				p.append(0.0)
			var vals := [Color(e.x, e.y, e.k, e.a), Color(ci[0], ci[1], ci[2], e.q), Color(p[0], p[1], p[2], p[3]), Color(p[4], p[5], p[6], p[7]),
				Color(p[8], p[9], p[10], p[11])]
			for k in ROWS:
				var tx := head + at * ROWS + k
				img.set_pixel(tx % TEX_W, tx / TEX_W, vals[k])
			at += 1
	# the palette ramp, for kinds that pick its steps by number (the coin)
	var full := PackedColorArray(C)
	while full.size() < 8:
		full.append(Color(0, 0, 0, 0))
	var data := asset("_" + name.to_snake_case(), img)
	var po := {"amount": slots, "lifetime": D + 0.04, "one_shot": true, "explosiveness": 1.0, "local": true,
		"texture": _oquad(1), "layer": "light" if lit else "color", "back": o.get("back", false), "process_shader": ush("ftp"),
		"process_params": {"data": data, "nframes": NF, "looped": false}, "preprocess": 0.0, "parent": o.get("parent")}
	var p := particles(name, po)
	p.interpolate = false
	# placed from the keyed clock: a frame of warm-up only so frame 0 is already placed when it is first drawn
	p.preprocess = 1.0 / 60.0
	p.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var m := ShaderMaterial.new()
	m.shader = ush("bits_light" if lit else "bits")
	m.set_shader_parameter("data", data)
	if not lit:
		m.set_shader_parameter("pal", full)
	if lit:
		m.set_shader_parameter("canvas", canvas_v4())
	elif raw:
		# blended as the original blends its smoke, in its own mixed colours (no palette snap)
		m.set_shader_parameter("raw", true)
	elif o.get("soft", false):
		m.set_shader_parameter("translucent", true)
	m.resource_name = name
	p.material = m
	return p


# ------------------------------------------------------------------ keyed every frame

## Key node.prop to v on the frame being recorded (stepped); missing frames hold the last value.
func fk(node: Node, prop: String, v: Variant) -> void:
	var k := String(node.name) + "|" + prop
	if not _kbuf.has(k):
		var a := []
		a.resize(NF)
		_kbuf[k] = a
		_knodes[k] = [node, prop]
	_kbuf[k][_fi] = v


## Write every fk() key and each word's layout (call once, at the end).
func flush_keys() -> void:
	for w in _words:
		(w.material as ShaderMaterial).set_shader_parameter("lay", asset("_" + String(w.name).to_snake_case() + "_layout", w.get_meta("lay")))
		w.remove_meta("lay")
	for k in _kbuf:
		var vals: Array = _kbuf[k]
		var first: Variant = null
		for v in vals:
			if v != null:
				first = v
				break
		var keys := []
		var last: Variant = first
		for i in NF:
			if vals[i] != null:
				last = vals[i]
			keys.append([i / 30.0, last])
		key(_knodes[k][0], _knodes[k][1], keys, "nearest")


# ------------------------------------------------------------------ words

## A word drawn by fx/ui/_word.gdshader (drawWord): gl the glyph dicts (one per letter slot), font, st: fill (Array,
## bottom row first), edge, under, outline, ow, shadow, glint (Colors; absent: none). Key it with word_at().
func word(name: String, gl: Array, font: String, st: Dictionary, o := {}) -> ColorRect:
	var F: Dictionary = PFont.FONTS[font]
	var n := gl.size()
	assert(n <= 16)
	var img := Image.create(maxi(8, n * 8), F.h, false, Image.FORMAT_R8)
	var gw := PackedFloat32Array()
	for k in 16:
		gw.append(0.0)
	for k in n:
		var g: Dictionary = gl[k]
		gw[k] = g.w
		for gy in F.h:
			for gx in g.w:
				if g.rows[gy][gx]:
					img.set_pixel(k * 8 + gx, gy, Color(1, 0, 0))
	var fill := []
	for c in st.fill:
		fill.append(c)
	var nf := fill.size()
	while fill.size() < 4:
		fill.append(fill[-1])
	var pr := {"glyphs": asset("_" + name.to_snake_case() + "_glyphs", img), "n": n, "gh": float(F.h), "gw": gw, "fill": fill, "nfill": nf,
		"ow": int(st.get("ow", 1))}
	for k in ["edge", "under", "outline", "shadow"]:
		if st.get(k) != null:
			pr[k] = st[k]
			pr["has_" + k] = true
	if st.get("glint") != null:
		pr.glint = st.glint
	var r := canvas_rect()
	var oo := {"at": r.position + r.size / 2.0}
	oo.merge(o, true)
	var w := shape(name, ush("word"), r.size, pr, oo)
	w.set_meta("gh", float(F.h))
	w.set_meta("ow", float(st.get("ow", 1)))
	w.set_meta("n", n)
	w.set_meta("nfill", nf)
	return w


## The word's letters on this frame: items[k] null (not drawn) or {x, y, sx, sy, a, flash, slant}; shine null or the
## shine's x, with shine_y. Where each letter's pixels fall in its font (drawWord's floors: which font row and column,
## the italic shift, the bevel's edges, the fill step) is worked out here in doubles, exactly as the original's
## doubles decide it, into the word's layout texture (8-bit): a pixel row a texel (font row + 1, shift + 128, edge
## bits, fill step) and a pixel column a texel (font column + 1, left-edge bit), 2 texel rows per letter per frame.
func word_at(w: ColorRect, items: Array, shine: Variant = null, shine_y := 0.0) -> void:
	var a0 := PackedVector4Array()
	var a1 := PackedVector4Array()
	var gh: float = w.get_meta("gh")
	var ow: float = w.get_meta("ow")
	var nf: int = w.get_meta("nfill")
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	var gw: PackedFloat32Array = (w.material as ShaderMaterial).get_shader_parameter("gw")
	var nl: int = w.get_meta("n")
	if not w.has_meta("lay"):
		var im := Image.create(LAY_W, NF * 2 * nl, false, Image.FORMAT_RGBA8)
		im.fill(Color(0, 0, 0, 0))
		w.set_meta("lay", im)
	var img: Image = w.get_meta("lay")
	for k in 16:
		var it: Variant = items[k] if k < items.size() else null
		if it == null:
			a0.append(Vector4(0, 0, 0, 0))
			a1.append(Vector4(0, 0, 0, 0))
			continue
		var sl: float = it.get("slant", 0.0)
		var x: float = it.x
		var y: float = it.y
		var sx: float = it.sx
		var sy: float = it.sy
		var bot := y + gh * sy
		var py0 := floorf(y)
		var rows := int(ceilf(bot) - py0)
		var m0 := floorf(x) - 2.0
		var cols := int(ceilf(x + gw[k] * sx) + 2.0 - m0)
		assert(rows <= LAY_W and cols <= LAY_W, "a letter too big for the word layout")
		var ry0 := (_fi * nl + k) * 2
		for j in rows:
			var py := py0 + j
			var gy := floorf((py + 0.5 - y) / sy)
			if gy < 0.0 or gy >= gh:
				continue
			var shift := floorf(((bot - py - 0.5) / sy) * sl + 0.5)
			var ry := py + 0.5 - y - gy * sy
			var v := (py + 0.5 - y) / (gh * sy)
			var fl := (1 if ry < 1.0 else 0) | (2 if ry >= sy - 1.0 else 0) | (4 if v < 0.5 else 0)
			var fi := clampi(int(floorf((1.0 - v) * nf)), 0, nf - 1)
			img.set_pixel(j, ry0, Color8(int(gy) + 1, int(shift) + 128, fl, fi))
		for i in cols:
			var fx := (m0 + i) + 0.5 - x
			var gx := floorf(fx / sx)
			if gx < 0.0 or gx >= gw[k]:
				continue
			img.set_pixel(i, ry0 + 1, Color8(int(gx) + 1, 1 if fx - gx * sx < 1.0 else 0, 0, 0))
		a0.append(Vector4(py0, m0, rows, cols))
		a1.append(Vector4(it.get("a", 1.0), it.get("flash", 0.0), sl, 1.0))
		var sa := absf(sl) * gh
		x0 = minf(x0, x - sa)
		x1 = maxf(x1, x + gw[k] * sx + sa)
		y0 = minf(y0, y)
		y1 = maxf(y1, bot)
	var box := Vector4(0, 0, -1, -1)
	if x0 < INF:
		box = Vector4(floorf(x0) - 1.0 - ow, floorf(y0) - 1.0 - ow, ceilf(x1) + 2.0 + ow, ceilf(y1) + 3.0 + ow)
	fk(w, "material:shader_parameter/frame", float(_fi))
	fk(w, "material:shader_parameter/it0", a0)
	fk(w, "material:shader_parameter/it1", a1)
	fk(w, "material:shader_parameter/box", box)
	fk(w, "material:shader_parameter/has_shine", shine != null)
	fk(w, "material:shader_parameter/shine", float(shine) if shine != null else 0.0)
	fk(w, "material:shader_parameter/shine_y", shine_y)
	if not _words.has(w):
		_words.append(w)
