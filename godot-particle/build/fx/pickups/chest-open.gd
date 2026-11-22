# reimagined-from: src/fx/pickups/chest-open.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Chest open: A banded chest rattles with gold light leaking from its seam, the lid kicks open, rays fan up, and coins and gems arc out, bounce, glint and get collected.
# one-shot, 4.60 s, 176x112 canvas, origin [88, 96], backdrop ground
# ramp palette: #1e1206 #4a2c08 #86520c #c48412 #f0b424 #ffe066 #fff6c4 #ffffff
# ramp wood: #110a10 #24131a #3a1f1f #552d24 #73402c #925737 #b07246
# The original is a simulation (create/update): this replays it at build time step for step (its seeded Rng, its
# 120 Hz steps, every spawn in order), then:
#   - the chest is a body painted every frame by the original's own painters (hoard, a lid swung on its curved
#     profile, banded front, outline) into a strip the animation steps through, shaken and hopped by its keys; once
#     empty it is a dissolve shader (fx/pickups/_dissolve.gdshader) taking it apart pixel by pixel from the lid down;
#   - the coins and gems tumbling out, bouncing and settling are particles drawn by the original's coin() and gemlet()
#     (fx/pickups/_bits.gdshader), with their shadows, glints, glows and the rings as gems are collected;
#   - the sim's sparks, stars, dust and embers, the seam's crack and its rays of light are particles placed frame by
#     frame from the replay; the rays fanning out of the open chest and the flare are shaders keyed from it; the
#     lights (Lights) ride particles of their own.
extends "res://build/fx/pickups/_pickups.gd"

const GEMS := [
	["#2a0612", "#6e0f2a", "#b81c3c", "#f0405a", "#ff8a96", "#ffd2d6"],
	["#06200f", "#0f4a26", "#1a8040", "#34c060", "#8af0a0", "#d8ffe0"],
	["#0a1030", "#142a70", "#2050c0", "#3a8cf0", "#8ccaff", "#dcf0ff"],
	["#1a0a2a", "#3e1466", "#6a28a8", "#a050e0", "#d09cff", "#f0e0ff"],
]
const IRON_HEX := ["#0e0d16", "#1d1c28", "#2f2e3e", "#474658", "#6a6a7e", "#9898ac"]
const T_OPEN := 0.8
const T_COLLECT := 2.55
const T_POOF := 3.3
const RATTLES := [[0.1, 0.4], [0.32, 0.62], [0.5, 0.8], [0.64, 1.0]]
const HWC := 12
const FH := 9
const CS := 0.94
const SN := 0.34
const LA := 6.0
const LB := 5.5
const STRAPS := [-9, 7]
const P_SPARK := 0
const P_DUST := 5
const P_STAR := 6
const P_EMBER := 7

var Wd: Array = []
var IRON: Array = []
var G: Array = []
var R: JsRng
var t := 0.0


# ------------------------------------------------------------------ the chest, painted as the original paints it

static func tone(r: Array, l: float, steps: Array) -> Color:
	return r[steps[0 if l > 0.6 else 1 if l > 0.25 else 2 if l > -0.1 else 3 if l > -0.45 else 4]]


func lid_rows(th: float) -> Array:
	var best := {}
	var ct := cos(th)
	var st := sin(th)
	var hb := FH / CS
	for i in 261:
		var al := (i / 260.0) * PI
		var dz := LA + LA * cos(al)
		var dy := LB * sin(al)
		var z := -LA + dz * ct - dy * st
		var y := hb + dz * st + dy * ct
		if y < hb - 0.05:
			continue
		var nz := cos(al) / LA
		var ny := sin(al) / LB
		var nl := sqrt(nz * nz + ny * ny)
		nz /= nl
		ny /= nl
		var Nz := nz * ct - ny * st
		var Ny := nz * st + ny * ct
		var v := y * CS + (LA - z) * SN
		var dep := z * CS + y * SN
		var row := int(floorf(-v))
		if not best.has(row) or dep > best[row].dep:
			best[row] = {"row": row, "al": al, "dep": dep, "out": Nz * CS + Ny * SN > 0.0, "lit": Ny * 0.95 + Nz * 0.3 - 0.2, "crest": false, "seam": false}
	var rows := best.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.row < b.row)
	var hi: Variant = null
	for r in rows:
		if r.out and (hi == null or r.lit > hi.lit):
			hi = r
	if hi != null and hi.lit > 0.5:
		hi.crest = true
	for s in [PI / 3.0, (2.0 * PI) / 3.0]:
		var k: Variant = null
		for r in rows:
			if k == null or absf(r.al - s) < absf(k.al - s):
				k = r
		if k != null and absf(k.al - s) < 0.4:
			k.seam = true
	return rows


func heat(k: float, g: float) -> Color:
	return C[clampi(int(jround(k + g * 2.2)), 0, 7)]


func paint_hoard(L: Dictionary, g: float) -> void:
	for y in range(-13, -9):
		for x in range(-HWC, HWC):
			var h := rand([x, y, 7])
			var k := 5 if h < 0.18 else (4 if h < 0.55 else 3)
			L[Vector2i(x, y)] = Wd[2] if (y == -13 and absf(x + 0.5) > 9.0) else heat(k - (1 if y == -13 else 0), g)
	for x in range(-9, 9):
		var top := -13 - int(jround(2.2 * pow(cos(((x + 0.5) / 10.0) * (PI / 2.0)), 1.4)))
		for y in range(top, -13):
			L[Vector2i(x, y)] = heat(5 if y == top else 4 + (1 if rand([x, y, 3]) < 0.3 else 0), g)


func paint_lid(L: Dictionary, th: float, g: float) -> void:
	var rows := lid_rows(th)
	var top: int = rows[0].row if rows.size() else 0
	for r in rows:
		var u: float = r.al
		for x in range(-HWC, HWC):
			var strap := x == STRAPS[0] or x == STRAPS[0] + 1 or x == STRAPS[1] or x == STRAPS[1] + 1
			var left := x == STRAPS[0] or x == STRAPS[1]
			var side := (x + HWC + 0.5) / (2.0 * HWC)
			var corner := x == -HWC or x == HWC - 1
			var mid := x >= -2 and x <= 1
			var c: Color
			if r.out:
				if r.row == top and corner and th < 0.6:
					continue
				var l: float = r.lit + 0.2 - side * 0.35 - (0.45 if r.row == top else 0.0)
				if u < 0.3 or (u < 0.55 and mid):
					c = tone(C, l + (0.15 if mid else 0.1), [6, 5, 5, 4, 3])
				elif corner:
					c = IRON[4] if x < 0 else IRON[2]
				elif strap:
					c = tone(IRON, l + (0.3 if left else -0.3), [5, 4, 3, 2, 1])
				elif r.seam:
					c = Wd[0]
				else:
					c = Wd[6] if (r.crest and side < 0.62) else tone(Wd, l, [5, 4, 3, 2, 1])
					if rand([x >> 1, int(jround(u * 6.0)), 11]) < 0.2:
						c = Wd[maxi(0, Wd.find(c) - 1)]
			else:
				var k := g * pow(u / PI, 1.3)
				if u < 0.3:
					c = heat(1, g)
				elif r.seam:
					c = Wd[0]
				else:
					c = mixc(Wd[4], C[5], 0.3) if k > 0.6 else (Wd[3] if k > 0.35 else (Wd[2] if k > 0.15 else Wd[1]))
				if corner:
					c = Wd[0]
			L[Vector2i(x, r.row)] = c


func paint_front(L: Dictionary, g: float) -> void:
	for y in range(-FH, 0):
		for x in range(-HWC, HWC):
			var side := (x + HWC + 0.5) / (2.0 * HWC)
			var c: Color
			if y == -FH:
				c = C[6] if side < 0.3 else (C[5] if side < 0.7 else C[4])
			elif y == -1:
				c = Wd[1]
			elif y == -5:
				c = Wd[0]
			else:
				var tp := y == -8 or y == -4
				var bt := y == -6 or y == -2
				c = Wd[(4 if side < 0.45 else 3) if tp else (2 if bt else 3)]
				if not tp and rand([x >> 1, y, 5]) < 0.2:
					c = Wd[1 if bt else 2]
			if x == -HWC:
				c = C[5] if y == -FH else IRON[4]
			if x == HWC - 1:
				c = C[3] if y == -FH else IRON[2]
			for s in STRAPS:
				if x == s and y > -FH:
					c = IRON[5] if (y == -7 or y == -3) else IRON[4]
				if x == s + 1 and y > -FH:
					c = IRON[2]
			L[Vector2i(x, y)] = c
	for y in range(-FH, -3):
		for x in range(-2, 2):
			L[Vector2i(x, y)] = C[3] if (x == 1 or y == -4) else (C[7] if (x == -2 and y == -FH) else C[5])
	var kh: Color = Wd[0] if g < 0.15 else (C[4] if g < 0.4 else (C[6] if g < 0.7 else Color.WHITE))
	L[Vector2i(-1, -7)] = kh
	L[Vector2i(0, -7)] = kh
	L[Vector2i(-1, -6)] = kh
	L[Vector2i(0, -6)] = scalec(kh, 0.85)


## the chest in its Layer (40 x 44 from (-20, -32)), outlined in the darkest wood
func paint_chest(th: float, g: float) -> Dictionary:
	var L := {}
	if th > 1.2:
		paint_lid(L, th, g)
		paint_hoard(L, g)
	else:
		paint_hoard(L, g)
		paint_lid(L, th, g)
	paint_front(L, g)
	var out := {}
	for y in range(-32, 12):
		for x in range(-20, 20):
			var p := Vector2i(x, y)
			if L.has(p):
				continue
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var q: Vector2i = p + d
				if q.x >= -20 and q.x < 20 and q.y >= -32 and q.y < 12 and L.has(q):
					out[p] = Wd[0]
					break
	L.merge(out)
	return L


func chest_image(L: Dictionary) -> Image:
	var img := Image.create(40, 44, false, Image.FORMAT_RGBA8)
	for p in L:
		img.set_pixel(p.x + 20, p.y + 32, L[p])
	return img


# ------------------------------------------------------------------ the original's clock-driven bits

func shake() -> Dictionary:
	var dx := 0.0
	var hop := 0
	var lid := 0.0
	for r in RATTLES:
		var u: float = t - r[0]
		if u < 0.0 or u > 0.18:
			continue
		var e := 1.0 - u / 0.18
		dx += sin(u * 90.0) * 1.6 * r[1] * e
		if u < 0.06 and r[1] > 0.5:
			hop = 1
		lid = maxf(lid, maxf(0.0, sin(u * 38.0)) * 0.13 * r[1] * e)
	if t >= T_OPEN and t < T_OPEN + 0.08:
		hop = 1
	var strain := smooth(T_OPEN - 0.14, T_OPEN, t)
	if t < T_OPEN:
		lid = maxf(lid, 0.07 * strain)
		dx += ((1.0 if int(floorf(t * 60.0)) % 2 else -1.0) * 0.6) if strain > 0.2 else 0.0
	return {"dx": jround(dx), "hop": hop, "lid": lid}


func lid_angle(lid: float) -> float:
	if t < T_OPEN:
		return lid
	var u := t - T_OPEN
	var w := 30.0
	var z := 0.55
	var wd := w * sqrt(1.0 - z * z)
	return 1.98 * (1.0 - exp(-z * w * u) * (cos(wd * u) + ((z * w) / wd) * sin(wd * u)))


func inner() -> float:
	if t < T_OPEN:
		var k := 0.1 + 0.45 * smooth(0.0, T_OPEN, t) + 0.5 * smooth(T_OPEN - 0.14, T_OPEN, t)
		for r in RATTLES:
			if t > r[0]:
				k += 0.45 * r[1] * exp(-(t - r[0]) * 9.0)
		return k
	return (0.62 + 0.3 * exp(-(t - T_OPEN) * 5.0)) * (1.0 - smooth(T_COLLECT - 0.3, T_POOF, t)) + 0.05 * sin(t * 9.0)


# ------------------------------------------------------------------ sim.js Particles

func spawn(list: Array, k: int, x: float, y: float, vx: float, vy: float, life: float, col: Color = Color.WHITE, size := 1.0) -> void:
	list.append({"k": k, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "col": col, "size": size, "seed": R.next() * 100.0})


static func step(list: Array, pt: float, dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]
		p.life -= dt
		if p.life <= 0.0:
			list.remove_at(i)
			continue
		match int(p.k):
			P_SPARK:
				p.vy += GRAVITY * 0.45 * dt
				p.vx -= p.vx * 2.2 * dt
				p.vy -= p.vy * 2.2 * dt
				var ny: float = p.y + p.vy * dt
				p.x += p.vx * dt
				if p.vy > 0.0 and p.y <= 0.0 and ny >= 0.0:
					p.vy = -p.vy * 0.45
					p.vx *= 0.7
					p.y = -0.25
				else:
					p.y = ny
				continue
			P_EMBER:
				p.vy += (-30.0 + sin(pt * 3.0 + p.seed) * 20.0) * dt
				p.vx += cos(pt * 2.3 + p.seed) * 45.0 * dt
				p.vx -= p.vx * 1.6 * dt
				p.vy -= p.vy * 1.6 * dt
			_:
				var drag := 4.0 if p.k == P_DUST else 1.6
				p.vx -= p.vx * drag * dt
				p.vy -= p.vy * drag * dt + 5.0 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt


## blobShadow(x, rx, k) as dots
static func shadow_dots(x: float, rx: float, k: float, out: Array) -> void:
	if rx < 0.8 or k <= 0.0:
		return
	for i in range(int(floorf(x - rx)), int(ceilf(x + rx)) + 1):
		var u := absf(i + 0.5 - x) / rx
		if u > 1.0:
			continue
		var a := k * (1.0 - u * u)
		out.append(dot_e(i, 0.0, INK, a * 1.1))
		if u < 0.6:
			out.append(dot_e(i, 1.0, INK, a * 0.6))


static func line_e(x0: float, y0: float, x1: float, y1: float, c: Variant, a: float, mode := 0, c2: Variant = null) -> Dictionary:
	var X := floorf(x0)
	var Y := floorf(y0)
	return {"x": X, "y": Y, "c": c, "c2": c if c2 == null else c2, "a": a, "e": [floorf(x1) - X, floorf(y1) - Y, 2.0, mode]}


func make() -> void:
	var W := Color.WHITE
	keep_colour(INK)
	Wd = Array(root.ramps["wood"])
	IRON = IRON_HEX.map(func(h: String) -> Color: return Color(h))
	for gm in GEMS:
		G.append(gm.map(func(h: String) -> Color: return Color(h)))
	var DUST := Color("#5e5068")
	R = JsRng.new(3)
	var ps := []
	var dust := []
	var lights := []
	var loot := []
	var rings := []
	var bits := []
	var rays := []
	for i in 9:
		var u := (i / 8.0) * 2.0 - 1.0
		var r := {}
		r.a = u * 1.05 + R.range(-0.06, 0.06)
		r.len = R.range(46, 64) * (1.2 - 0.4 * absf(u))
		r.w = R.range(0.035, 0.08)
		r.d = R.range(0, 0.06)
		r.f = R.range(5, 10)
		r.ph = R.range(0, TAU)
		rays.append(r)
	var n := 12
	for i in n + 4:
		var gem := i >= n
		var s := 1.0 if i % 2 else -1.0
		var a := s * R.range(0.1, 0.5)
		var sp := R.range(190, 270)
		var it := {"gem": gem, "gi": (i - n) % 4 if gem else -1, "vx": sin(a) * sp, "vy": -cos(a) * sp, "y": -12.0, "up": false, "rest": false,
			"r": 2.6 if gem else 3.0, "settle": 0.0, "pop": 0.0, "gone": false}
		it.x = R.range(-7, 7)
		it.t0 = T_OPEN + 0.03 + R.range(0, 0.2)
		it.ax = R.range(-0.6, 0.6)
		it.spin = R.range(0, TAU)
		var sg := R.sign()
		it.vs = sg * R.range(14, 24)
		it.ph = R.next()
		loot.append(it)
	var order := range(loot.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var va := absf(loot[a].vx)
		var vb := absf(loot[b].vx)
		return va > vb or (va == vb and a < b))
	for k in order.size():
		loot[order[k]].pop = T_COLLECT + k * 0.04 + R.range(0, 0.02)
	var opened := false
	var poofed := false
	var dt := (1.0 / 30.0) / 4.0
	var poof_img: Image = null
	var poof_td: Image = null
	# per frame
	var F := []
	for f in NF:
		if f > 0:
			for st_ in 4:
				t += dt
				var g := inner()
				for rr in RATTLES:
					if rr[1] > 0.5 and t - dt < rr[0] + 0.05 and t >= rr[0] + 0.05:
						for i in 4:
							var sd := 1.0 if i % 2 else -1.0
							spawn(ps, P_DUST, sd * R.range(9, 13), -1.0, sd * R.range(20, 50), -R.range(2, 8), R.range(0.3, 0.5), DUST, R.range(1.2, 2.2) * rr[1])
				if t < T_OPEN and R.chance(g * 0.08):
					var x := R.range(-11, 11)
					spawn(ps, P_STAR, x, -10.0, x * 1.5, -R.range(8, 30), R.range(0.3, 0.6), C[6] if R.chance(0.5) else C[5], R.range(0.4, 1.2))
				if not opened and t >= T_OPEN:
					opened = true
					lights.append([0.0, -18.0, 64.0, C[5], 0.45, 0.7, 0.7])
					lights.append([0.0, -16.0, 22.0, W, 0.35, 0.1, 0.1])
					for i in 7:
						var a := -PI / 2.0 + R.range(-1.1, 1.1)
						var sp := R.range(120, 260)
						spawn(ps, P_SPARK, R.range(-8, 8), -13.0, cos(a) * sp, sin(a) * sp, R.range(0.12, 0.26))
					for i in 8:
						var s := R.sign()
						spawn(ps, P_DUST, s * R.range(10, 14), -1.0, s * R.range(30, 80), -R.range(2, 10), R.range(0.4, 0.7), DUST, R.range(1.6, 3))
				if t > T_OPEN and t < T_COLLECT:
					if R.chance(0.22):
						spawn(ps, P_EMBER, R.range(-9, 9), -13.0, R.range(-12, 12), -R.range(25, 60), R.range(0.8, 1.5), C[5], R.range(0.8, 1.6))
					if R.chance(0.12):
						var a := R.range(-1, 1)
						var d := R.range(10, 40)
						spawn(ps, P_STAR, sin(a) * d, -12.0 - cos(a) * d, 0.0, -R.range(4, 12), R.range(0.3, 0.7), W if R.chance(0.5) else C[6], R.range(0.5, 2))
				for it in loot:
					if it.gone or t < it.t0:
						continue
					it.up = true
					if t >= it.pop + 0.13:
						it.gone = true
						var y: float = it.y - 6.0
						if it.gem:
							rings.append({"x": it.x, "y": y, "t0": t})
						lights.append([it.x, y, 18.0, G[it.gi][4] if it.gem else C[5], 0.65, 0.25, 0.25])
						for i in 4:
							var a := R.range(0, TAU)
							var sp := R.range(25, 55)
							spawn(ps, P_STAR, it.x, y, cos(a) * sp - it.x * 0.25, sin(a) * sp - 20.0, R.range(0.3, 0.55), (G[it.gi][5] if it.gem else C[6]) if i else W, R.range(0.6, 1.5))
						continue
					if it.rest:
						it.settle += dt
						it.vx -= it.vx * 9.0 * dt
						it.x = clampf(it.x + it.vx * dt, -74.0, 74.0)
						continue
					it.vy += 950.0 * dt
					it.x += it.vx * dt
					if absf(it.x) > 74.0:
						it.x = signf(it.x) * 74.0
						it.vx *= -0.3
					it.y += it.vy * dt
					it.spin += it.vs * dt
					if it.y + it.r >= -0.5 and it.vy > 0.0:
						it.y = -0.5 - it.r
						if it.vy > 110.0:
							spawn(ps, P_DUST, it.x, -1.0, R.range(-20, 20), -R.range(4, 12), R.range(0.25, 0.45), DUST, R.range(1, 1.8))
							if it.vy > 220.0:
								for i in 2:
									spawn(ps, P_SPARK, it.x, -1.0, R.range(-90, 90), -R.range(60, 140), R.range(0.1, 0.22))
								lights.append([it.x, -2.0, 9.0, C[5], 0.5, 0.12, 0.12])
							it.vy = -it.vy * 0.42
							it.vx *= 0.5
							it.vs *= 0.55
						else:
							it.rest = true
							it.vy = 0.0
				rings = rings.filter(func(r: Dictionary) -> bool: return t - r.t0 <= 0.3)
				if not poofed and t >= T_POOF:
					poofed = true
					lights.append([0.0, -12.0, 40.0, C[5], 0.5, 0.6, 0.6])
					# (the original tells motes from the dark outline with c !== W[0], an unsigned pixel against a signed
					# colour: never equal, so any pixel may become a mote; its last flash is always gold for the same reason)
					var L := paint_chest(lid_angle(0.0), 0.3)
					var top := 0
					for p in L:
						top = mini(top, p.y)
					poof_img = chest_image(L)
					poof_td = Image.create(40, 44, false, Image.FORMAT_RF)
					for y in range(-32, 12):
						for x in range(-20, 20):
							var p := Vector2i(x, y)
							if not L.has(p):
								continue
							var td := T_POOF + (float(y - top) / -top) * 0.32 + rand([x, y, 21]) * 0.05
							poof_td.set_pixel(x + 20, y + 32, Color(td, 0, 0))
							bits.append({"x": x, "y": y, "td": td, "mote": rand([x, y, 23]) < 0.14, "done": false})
				for b in bits:
					if not b.done and t >= b.td:
						b.done = true
						if b.mote:
							spawn(dust, P_EMBER, b.x + 0.5, b.y + 0.5, R.range(-28, 28), -R.range(14, 50), R.range(0.4, 0.8), C[5], R.range(0.5, 1.1))
				step(ps, t, dt)
				step(dust, t, dt)
				for l in lights:
					l[5] -= dt
				lights = lights.filter(func(l: Array) -> bool: return l[5] > 0.0)
		F.append(draw_frame(ps, dust, lights, loot, rings, rays, poofed))
	build_scene(F, rays, poof_img, poof_td)


## Everything the original draws at this frame, as entries per layer.
func draw_frame(ps: Array, dust: Array, lights: Array, loot: Array, rings: Array, rays: Array, poofed: bool) -> Dictionary:
	var W := Color.WHITE
	var out := {"t": t}
	var g := inner()
	var sh := shake()
	var th := lid_angle(sh.lid)
	var open := 1.0 if t >= T_OPEN else 0.0
	out.chest = paint_chest(th, minf(1.2, g)) if t < T_POOF else null
	out.dx = sh.dx
	out.hop = sh.hop
	out.shadow_k = (1.0 - smooth(T_POOF, T_POOF + 0.2, t)) if t < T_POOF + 0.2 else 0.0
	# the soft dust (behind)
	var back := []
	for q in ps:
		if q.k != P_DUST:
			continue
		var k: float = q.life / q.max
		var x: float = q.x
		var y: float = q.y
		back.append({"x": x, "y": y, "s": q.size * (0.6 + (1.0 - k) * 0.9), "a": pow(k, 1.3) * 0.7, "c": q.col, "e": [x - floorf(x), y - floorf(y)], "reach": 5.0})
	out.back = back
	# the big lights
	var gl := [{"t": G_POOL, "c": C[4], "p": Vector2(0, 0), "r": 30.0 + 10.0 * g, "ry": 4.0, "k": (0.1 + 0.18 * open) * g},
		{"c": C[4], "p": Vector2(0, -16), "r": 24.0 + 8.0 * g, "k": (0.1 + 0.2 * open) * g}]
	var seam := []
	if t < T_OPEN:
		gl.append({"t": G_LINE, "c": C[5], "p": Vector2(-11, -9.5 - sh.hop), "q": Vector2(11, -9.5 - sh.hop), "r": 5.0, "k": 0.22 * g})
		gl.append({"c": C[6], "p": Vector2(sh.dx, -7 - sh.hop), "r": 6.0, "k": 0.35 * g})
		seam.append(line_e(-10.0 + sh.dx, -10.0 - sh.hop, 9.0 + sh.dx, -10.0 - sh.hop, 6, (g - 0.35) * 2.2, 4, 8) if (g > 0.35 and sh.lid < 0.015) else null)
		for i in 8:
			if sh.lid > 0.015:
				var x: float = -10.5 + i * 3 + sh.dx + (rand([i, 3]) - 0.5) * 1.5
				var a := -PI / 2.0 + (x / 11.0) * 1.25
				var l := (7.0 + rand([i, int(floorf(t * 30.0)), 1]) * 12.0) * minf(1.0, sh.lid / 0.05)
				var y0: float = -10.0 - sh.hop
				seam.append(line_e(x, y0, x + cos(a) * l, y0 + sin(a) * l, 5, 1.0, 8))
				gl.append({"t": G_LINE, "c": C[5], "p": Vector2(x, y0), "q": Vector2(x + cos(a) * l * 0.7, y0 + sin(a) * l * 0.7), "r": 3.0, "k": 0.25})
			else:
				seam.append(null)
				gl.append(null)
	else:
		gl += [null, null]
		for i in 8:
			gl.append(null)
	out.glows = gl
	out.seam = seam
	# the rays fanning out of the open chest
	var rb := PackedVector2Array()
	for r in rays:
		var u: float = t - T_OPEN - r.d
		var k := 0.0
		if u >= 0.0:
			k = out_cubic(clampf(u / 0.1, 0.0, 1.0)) * (1.0 - smooth(1.0, 2.1, u)) * (0.72 + 0.28 * sin(t * r.f + r.ph))
		rb.append(Vector2(r.len * (0.88 + 0.12 * sin(t * r.f * 0.7 + r.ph)), k))
	out.rays = rb
	var fa := (t - T_OPEN) / 0.2
	out.flare = [22.0 * pow(1.0 - fa, 1.4), 1.0 - fa] if (t >= T_OPEN and t < T_OPEN + 0.2) else [0.0, 0.0]
	# the loot
	var shadows := {}
	var coins := {}
	var gems := {}
	var lg := []
	var glints := {}
	for it in loot:
		var li := loot.find(it)
		if not it.up or it.gone:
			continue
		var pu: float = t - it.pop
		var lift := 6.0 * out_cubic(clampf(pu / 0.1, 0.0, 1.0)) if pu > 0.0 else 0.0
		var wh := pu > 0.095
		var y: float = it.y - lift
		var ax: float = it.ax
		var spin: float = it.spin
		var flat := false
		if it.rest and not it.gem:
			var w := exp(-it.settle * 8.0) * absf(cos(it.settle * 22.0))
			ax = 0.0
			spin = acos(clampf(0.5 + 0.5 * w, 0.0, 1.0))
			flat = w < 0.12
			y = -1.5 - lift if flat else -it.r * cos(spin) - lift
		if it.y > -10.0:
			var sd := []
			shadow_dots(it.x, 3.0, 0.7 * (1.0 - clampf(-it.y / 30.0, 0.0, 1.0)), sd)
			shadows[li] = sd
		var glow := [it.x, y, 9.0, G[it.gi][4] if it.gem else C[5], 0.26 if it.rest else 0.18]
		if it.gem:
			var X := jround(it.x)
			var Y := jround(y)
			gems[it.gi] = ({"x": X, "y": Y, "s": it.r, "a": 2.0 if wh else 1.0, "e": [0.0, 0.0, 0.4 * signf(it.vs) if it.rest else it.spin, 0.0],
				"reach": 7.0, "lp": Vector2(it.x, y), "lr": 9.0, "lc": glow[3], "lk": glow[4]})
		else:
			var X: float = jround(it.x) + 0.5 if flat else jround(it.x)
			var Y: float = y if flat else jround(y)
			coins[li] = ({"x": floorf(X), "y": floorf(Y), "s": it.r, "a": 2.0 if wh else 1.0, "e": [X - floorf(X), Y - floorf(Y), acos(0.5) if flat else spin, ax],
				"reach": 6.0, "lp": Vector2(it.x, y), "lr": 9.0, "lc": C[5], "lk": glow[4]})
		lg.append(dot_e(it.x, y, 8, 0.0, [it.x, y, 3.0, W, 0.12]))
		if it.rest and t < it.pop:
			var u := fmod(t * 0.9 + it.ph, 1.0)
			if u < 0.16:
				glints[li] = glint_e(it.x - 1.0, y - 1.5, 2.6 * sin((u / 0.16) * PI), G[it.gi][5] if it.gem else C[6], 0.5)
	out.shadows = shadows
	out.coins = coins
	out.gems = gems
	out.loot_light = lg
	out.glints = glints
	var rr := []
	var rg := []
	for r in rings:
		var k: float = (t - r.t0) / 0.3
		var e := out_cubic(k)
		rr.append({"x": floorf(r.x), "y": floorf(r.y), "s": 2.0 + 5.0 * e, "c": 8 if k < 0.3 else 6, "a": 1.15 - k, "e": [r.x - floorf(r.x), r.y - floorf(r.y)],
			"reach": 9.0, "lp": Vector2(r.x, r.y), "lr": 12.0, "lc": C[5], "lk": 0.45 * (1.0 - k)})
		if k < 0.5:
			rg.append(glint_e(r.x, r.y, 3.4 * (1.0 - k / 0.5), 6, 0.55))
	out.rings = rr
	out.ring_glints = rg
	# the sim's particles in front, then the dust's embers, then the lights
	var sparks := []
	var stars := []
	var star_dots := []
	var embers := []
	var S := [C[7], C[6], C[5], C[4]]
	for q in ps:
		var k: float = q.life / q.max
		var x: float = q.x
		var y: float = q.y
		var sp := sqrt(q.vx * q.vx + q.vy * q.vy)
		if sp == 0.0:
			sp = 1.0
		var ux: float = q.vx / sp
		var uy: float = q.vy / sp
		match int(q.k):
			P_SPARK:
				var head: Color = S[0] if k > 0.6 else (S[1] if k > 0.3 else S[2])
				var ln := minf(9.0, 1.0 + sp * 0.022)
				sparks.append(line_e(x - ux * ln, y - uy * ln, x - ux * ln * 0.4, y - uy * ln * 0.4, head if k > 0.5 else S[3], 1.0))
				var l2 := line_e(x - ux * ln * 0.45, y - uy * ln * 0.45, x, y, head, 1.0)
				l2.lp = Vector2(x, y)
				l2.lr = 3.0
				l2.lc = head
				l2.lk = 0.45 * k
				sparks.append(l2)
			P_STAR:
				var tw := 0.6 + 0.4 * sin(t * (8.0 + fmod(q.seed, 5.0)) + q.seed)
				if q.size < 1.0:
					star_dots.append(dot_e(x, y, W if tw > 0.8 else q.col, 1.0 if tw * k > 0.25 else 0.0, [x, y, 3.0, q.col, 0.4 * k * tw]))
				else:
					var nn := jround(q.size * tw * minf(1.0, k * 3.0))
					if nn >= 1.0:
						stars.append({"x": x, "y": y, "s": nn, "c": q.col, "lp": Vector2(x, y), "lr": 4.0 + nn * 2.0, "lc": q.col, "lk": 0.5 * k * tw})
			P_EMBER:
				ember(embers, q, k, t, S)
	var demb := []
	for q in dust:
		ember(demb, q, q.life / q.max, t, [C[5], C[5], C[4], C[3]])
	out.sparks = sparks
	out.stars = stars
	out.star_dots = star_dots
	out.embers = embers
	out.dust_embers = demb
	var lt := []
	for l in lights:
		var k: float = l[5] / l[6]
		lt.append(dot_e(l[0], l[1], l[3], 0.0, [l[0], l[1], l[2] * (0.55 + 0.45 * k), l[3], l[4] * k * k]))
	out.lights = lt
	return out


static func ember(out: Array, q: Dictionary, k: float, pt: float, S: Array) -> void:
	var c: Color = S[0] if k > 0.6 else (S[1] if k > 0.3 else S[2])
	if k < 0.25 and sin(pt * 40.0 + q.seed) < 0.0:
		return
	out.append(dot_e(q.x, q.y, c, 1.0, [q.x, q.y, 3.0 + q.size, c, 0.35 * k]))
	if q.size > 1.5:
		out.append(dot_e(q.x, q.y + 1.0, S[3], 1.0))


func build_scene(F: Array, rays: Array, poof_img: Image, poof_td: Image) -> void:
	var col := func(name: String) -> Array: return F.map(func(f: Dictionary) -> Array: return f[name])
	var clk := func(i: int) -> float: return F[i].t
	# behind: the chest's shadow and the soft dust
	shadow("Shadow", func(i: int, _t: float) -> Array: return [0.0, 15.0, F[i].shadow_k], {"span": 20})
	table("Dust", K_DISC, col.call("back"), {"back": true, "soft": true})
	# the light round the chest and the floor
	glows("Glow", func(i: int, _t: float) -> Array: return F[i].glows)
	# the chest: a strip of the frames the original paints, then the dissolve
	var strip := []
	var which := []
	var seen := {}
	for f in F:
		if f.chest == null:
			which.append(-1)
			continue
		var img := chest_image(f.chest)
		var key_ := img.get_data().hex_encode().md5_text()
		if not seen.has(key_):
			seen[key_] = strip.size()
			strip.append(img)
		which.append(seen[key_])
	var sheet := Image.create(40 * strip.size(), 44, false, Image.FORMAT_RGBA8)
	for i in strip.size():
		sheet.blit_rect(strip[i], Rect2i(0, 0, 40, 44), Vector2i(40 * i, 0))
	for f in F:
		if f.chest != null:
			for p in f.chest:
				keep_colour(f.chest[p])
	var chest := sprite("Chest", asset("chest", sheet), {"centered": false, "at": Vector2(-20, -32), "layer": "prop", "hframes": strip.size()})
	var kf := []
	var kp := []
	var kv := []
	for i in NF:
		var on: bool = which[i] >= 0
		kv.append([i / 30.0, on])
		kf.append([i / 30.0, maxi(0, which[i])])
		kp.append([i / 30.0, Vector2(-20 + F[i].dx, -32 - F[i].hop)])
	key(chest, "frame", kf, "nearest")
	key(chest, "position", kp, "nearest")
	key(chest, "visible", kv, "nearest")
	if poof_img != null:
		var dis := shape("Dissolve", psh("dissolve"), Vector2(40, 44), {"tex": asset("poof", poof_img), "tdt": asset("poof_td", poof_td),
			"c6": C[6]}, {"at": Vector2(0, -10)})
		per_frame(dis, "material:shader_parameter/t", func(i: int, _t: float) -> float: return clk.call(i))
		dis.visible = false
		per_frame(dis, "visible", func(i: int, _t: float) -> bool: return F[i].chest == null)
		for y in 44:
			for x in 40:
				var c := poof_img.get_pixel(x, y)
				if c.a > 0.5:
					keep_colour(c)
	# light leaking from the seam: its crack and the rays shooting out of it
	table("Seam", K_LINE, col.call("seam"), {"light": false})
	# the rays fanning out of the open chest, and the flare out of its mouth
	var cr := canvas_rect()
	var ra := PackedVector4Array()
	for r in rays:
		ra.append(Vector4(sin(r.a) * 7.0, sin(r.a), -cos(r.a), tan(r.w)))
	var rl := shape("Rays", psh("chest_rays_light"), cr.size, {"c5": C[5], "c6": C[6], "ra": ra, "canvas": canvas_v4()}, {"at": cr.position + cr.size / 2.0})
	per_frame(rl, "material:shader_parameter/rb", func(i: int, _t: float) -> PackedVector2Array: return F[i].rays)
	var dirs := PackedVector2Array()
	for i in 8:
		dirs.append(Vector2(cos(i * PI / 4.0), sin(i * PI / 4.0)))
	var fl := body("Flare", "beam", {"part": 1, "dirs": dirs, "flare_at": Vector2(0, -14)})
	per_frame(fl, "material:shader_parameter/flare_l", func(i: int, _t: float) -> float: return F[i].flare[0])
	per_frame(fl, "material:shader_parameter/flare_k", func(i: int, _t: float) -> float: return F[i].flare[1])
	# the loot: shadows, coins, gems, their light, their glints; the rings as gems are collected
	# each item in turn, as the original draws them: its shadow, the coin or gem, its glint (particles overlapping in one
	# emitter have no reliable draw order, and the loot piles up)
	for li in 16:
		var gem := li >= 12
		table("LootShadow%d" % li, K_DOT, F.map(func(f: Dictionary) -> Array: return f.shadows.get(li, [])))
		if gem:
			table("Gem%d" % (li - 12), K_GEMLET, F.map(func(f: Dictionary) -> Array: return [f.gems.get(li - 12)]), {"extra": G[li - 12]})
		else:
			table("Coin%d" % li, K_COIN, F.map(func(f: Dictionary) -> Array: return [f.coins.get(li)]))
		table("LootGlint%d" % li, K_GLINT, F.map(func(f: Dictionary) -> Array: return [f.glints.get(li)]))
	table("LootLight", K_DOT, col.call("loot_light"))
	table("Rings", K_RING, col.call("rings"))
	table("RingGlints", K_GLINT, col.call("ring_glints"))
	# the sim's sparks, stars and embers, the dust's embers, the lights
	table("Sparks", K_LINE, col.call("sparks"))
	table("Stars", K_SPARKLE, col.call("stars"))
	table("StarDots", K_DOT, col.call("star_dots"))
	table("Embers", K_DOT, col.call("embers"))
	table("DustEmbers", K_DOT, col.call("dust_embers"))
	table("Lights", K_DOT, col.call("lights"))
