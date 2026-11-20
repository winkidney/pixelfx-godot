# Shared by the critters build scripts (not an effect). A critter's original (src/fx/critters/*.js) builds its body
# in a small offscreen grid (_lib.js Grid) and puts it on the painter, then draws what goes on round it: glows,
# trails, motes, bubbles, drips, splashes. Here:
#   - the body is the original's own Grid cells and nothing else (build/fx/critters/_bodies.mjs runs the original
#     with every other write switched off) as frames.png, stepped frame by frame (critter());
#   - everything round it is native: particles placed frame by frame from the original's formulas (table(), from the
#     pickups), real emitters for motes and drifting dust, the big lights as one keyed light shader (glows()), see-
#     through smears as keyed polygons (smear()).
# Extends the pickups helpers (frame clock ft(), per_frame, table, glows, shadow) and through them the scifi ones
# (JsRng, rand, mixc, easings).
extends "res://build/fx/pickups/_pickups.gd"

const CR := "res://addons/pixelfx_particles/fx/critters/"


func csh(name: String) -> Shader:
	return load(CR + "_" + name + ".gdshader")


## The time the original draws frame i at, as the critter sees it: the reference's clock (pickups ft()) through
## _lib.js shift() (seed 1: wrap(t, D), which nudges the float and so decides a rounding on a .5 now and then).
func ft(i: int) -> float:
	return jmod(super(i), D) if root.loop else super(i)


## The body: the original's Grid cells, frame by frame (prop layer, exact). o.file: another lifted part
## (_bodies.mjs --name), as build.gd frames() plays frames.png.
func critter(name := "Body", o: Dictionary = {}) -> Sprite2D:
	var file: String = o.get("file", "frames")
	if file == "frames":
		return frames(name, o)
	var dir := CR + id.get_file() + "/"
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + file + ".json"))
	var oo := {"centered": false, "layer": "prop", "hframes": int(j.cols), "vframes": int(j.rows)}
	oo.merge(o, true)
	oo.erase("file")
	var s := sprite(name, load(dir + file + ".png"), oo)
	s.offset = -Vector2(j.pivot[0], j.pivot[1])
	var keys := []
	for i in int(j.count):
		keys.append([i / float(j.fps), i])
	key(s, "frame", keys, "nearest")
	return s


## _lib.js shift(): seeds other than 1 start the loop elsewhere
static func shift(t: float, d: float, seed_ := 1) -> float:
	return jmod(t + (seed_ - 1) * 0.618 * d, d)


static func wrapf_(x: float, m: float) -> float:
	return jmod(x, m)


## math.js smooth(e0, e1, x)
static func smoothx(e0: float, e1: float, x: float) -> float:
	var u := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## A see-through polygon keyed every frame: f(i, t) -> PackedVector2Array (empty: hidden). Soft layer, colour c at
## alpha a (the original's Grid poly with a.fill(a) blended over what's there).
func smear(name: String, c: Color, a: float, f: Callable, o: Dictionary = {}) -> Polygon2D:
	var pg := Polygon2D.new()
	pg.name = name
	pg.color = Color(c, a)
	pg.antialiased = false
	var oo := {"layer": "soft"}
	oo.merge(o, true)
	_place(pg, oo, o.get("parent"))
	var ks := []
	var vs := []
	for i in NF:
		var pts: PackedVector2Array = f.call(i, ft(i))
		ks.append([i / 30.0, pts if pts.size() >= 3 else PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])])
		vs.append([i / 30.0, pts.size() >= 3])
	key(pg, "polygon", ks, "nearest")
	key(pg, "visible", vs, "nearest")
	return pg


## sim.js sparkle(p, x, y, arm, c, tip, k) as table() dot entries (opaque px; the heart carries its light), padded to
## the entries a sparkle of arm `most` needs so slots stay fixed. c, tip: Color or an index into C (the heart is white).
static func sparkle_es(x: float, y: float, arm: float, c: Variant, tip: Variant, k: float, most: int) -> Array:
	var n := int(jround(arm))
	var size := 1 + 4 * most + (4 if most >= 3 else 0) + (4 if most >= 6 else 0)
	var out := []
	if n >= 1:
		var X := floorf(x)
		var Y := floorf(y)
		out.append(dot_e(X, Y, Color.WHITE, 1.0, [x, y, 4.0 + n * 2.0, c, k]))
		for d in range(1, n + 1):
			var cc: Variant = tip if d > n * 0.6 else c
			for q in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				out.append(dot_e(X + q[0] * d, Y + q[1] * d, cc))
		if n >= 3:
			for q in [[1, 1], [1, -1], [-1, 1], [-1, -1]]:
				out.append(dot_e(X + q[0], Y + q[1], c))
		if n >= 6:
			for q in [[1, 1], [1, -1], [-1, 1], [-1, -1]]:
				out.append(dot_e(X + q[0] * 2, Y + q[1] * 2, tip))
	while out.size() < size:
		out.append(null)
	return out


## particles.js cycle(t, period, count, seed, life, fn): fn(age, L, r, i) for every live copy (life: a number or a
## Callable(JsRng) -> float).
static func cycle(t: float, period: float, count: int, seed_: int, life: Variant, fn: Callable) -> void:
	for i in count:
		var g := rng([seed_, i, 911])
		var born := g.next() * period
		var L: float = life.call(g) if life is Callable else float(life)
		var age := fmod(fmod(t - born, period) + period, period)
		while age < L:
			fn.call(age, L, rng([seed_, i]), i)
			age += period


## _lib.js shadow(p, x(t), y, rx, ry, c, a) on the floor: f(i, t) -> [x, rx, k] keyed every frame (fx/critters/
## _shadow.gdshader, soft layer, behind).
func blob(name: String, y: float, ry: float, ink: Color, span: float, f: Callable) -> ColorRect:
	var s := shape(name, csh("shadow"), Vector2(span * 2.0, ceilf(ry) * 2.0 + 4.0), {"x": 0.0, "y": y, "rx": 1.0, "ry": ry, "k": 0.0,
		"ink": ink, "translucent": true}, {"at": Vector2(0, roundf(y)), "back": true})
	var xs := []
	var rs := []
	var ks := []
	for i in NF:
		var v: Array = f.call(i, ft(i))
		xs.append([i / 30.0, float(v[0])])
		rs.append([i / 30.0, float(v[1])])
		ks.append([i / 30.0, float(v[2])])
	key(s, "material:shader_parameter/x", xs, "nearest")
	key(s, "material:shader_parameter/rx", rs, "nearest")
	key(s, "material:shader_parameter/k", ks, "nearest")
	return s


## painter.js line(x0, y0, x1, y1, c, a) as a table() K_LINE entry (one colour, dithered alpha a).
static func line_e(x0: float, y0: float, x1: float, y1: float, c: Variant, a := 1.0) -> Dictionary:
	var sx := floorf(x0)
	var sy := floorf(y0)
	return {"x": sx, "y": sy, "c": c, "c2": c, "a": a, "e": [floorf(x1) - sx, floorf(y1) - sy, 2.0, 0.0]}


## _lib.js bubble(p, cx, cy, r, cols [highlight, lit, rim, shade], a, wob) as table() K_DOT entries: a dot, a shaded
## 2 x 2, or a rim lit top-left with its highlights; the first entry carries its glow.
static func bubble_es(cx: float, cy: float, r: float, cols: Array, a := 1.0, wob := 0.0) -> Array:
	var out := []
	if r < 0.9:
		out.append(dot_e(cx, cy, cols[2] if r < 0.7 else cols[1], a))
		return out
	if r < 1.5:
		var px := floorf(cx)
		var py := floorf(cy)
		out.append(dot_e(px, py, cols[0], a, [cx + 0.5, cy + 0.5, 3.0, cols[1], 0.12 * a]))
		out.append(dot_e(px + 1, py, cols[1], a))
		out.append(dot_e(px, py + 1, cols[2], a))
		out.append(dot_e(px + 1, py + 1, cols[3], a))
		return out
	var rx := r * (1.0 + wob)
	var ry := r * (1.0 - wob)
	for y in range(int(floorf(cy - ry - 1.0)), int(ceilf(cy + ry + 1.0)) + 1):
		for x in range(int(floorf(cx - rx - 1.0)), int(ceilf(cx + rx + 1.0)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := sqrt(dx * dx + dy * dy) * r
			if d > r + 0.5:
				continue
			var l := (-dx - dy) / sqrt(2.0) / maxf(0.01, d / r)
			if d > r - 0.6:
				out.append(dot_e(x, y, cols[1] if l > 0.45 else (cols[3] if l < -0.55 else cols[2]), a))
	var hx := jround(cx - rx * 0.45)
	var hy := jround(cy - ry * 0.45)
	out.append(dot_e(hx, hy, cols[0], a))
	if r >= 2.5:
		out.append(dot_e(hx + 1, hy, cols[1], a))
		out.append(dot_e(hx, hy + 1, cols[1], a))
	if r >= 2.0:
		out.append(dot_e(jround(cx + rx * 0.5), jround(cy + ry * 0.5), cols[1], a))
	# the glow rides the first entry
	out[0].lp = Vector2(cx, cy)
	out[0].lr = r * 2.4 + 2.0
	out[0].lc = cols[2]
	out[0].lk = 0.14 * a
	return out


# ------------------------------------------------------------------ the originals' maths (core/math.js, particles.js, _lib.js)

## math.js tileNoise(x, y, px, py, seed)
static func tile_noise(x: float, y: float, px := 0, py := 0, seed_: float = 0.0) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var x0 := jmod(ix, px) if px else ix
	var x1 := jmod(ix + 1.0, px) if px else ix + 1.0
	var y0 := jmod(iy, py) if py else iy
	var y1 := jmod(iy + 1.0, py) if py else iy + 1.0
	var a := rand([x0, y0, seed_])
	var b := rand([x1, y0, seed_])
	var c := rand([x0, y1, seed_])
	var d := rand([x1, y1, seed_])
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


## _lib.js lnoise(t, D, F, off, seed)
static func lnoise(t: float, d: float, f: int, off := 0.0, seed_: float = 0.0) -> float:
	return tile_noise((t / d) * f + off, 0.5, f, 0, seed_)


## particles.js fly(x, y, vx, vy, t, g, drag)
static func fly(x: float, y: float, vx: float, vy: float, t: float, g := 0.0, drag := 0.0) -> Vector2:
	if drag <= 0.0:
		return Vector2(x + vx * t, y + vy * t + 0.5 * g * t * t)
	var f := (1.0 - exp(-drag * t)) / drag
	var vt := g / drag
	return Vector2(x + vx * f, y + vt * t + (vy - vt) * f)


## _lib.js toss()
static func toss(x: float, y: float, vx: float, vy: float, age: float, g: float, fl := 0.0) -> Dictionary:
	var tl := (-vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * (fl - y)))) / g if g > 0.0 else INF
	if age < tl:
		return {"x": x + vx * age, "y": y + vy * age + 0.5 * g * age * age, "vx": vx, "vy": vy + g * age, "landed": false, "at": tl, "lx": x + vx * tl}
	return {"x": x + vx * tl, "y": fl, "vx": 0.0, "vy": 0.0, "landed": true, "at": tl, "lx": x + vx * tl}


## _lib.js bounce()
static func bounce(x: float, y: float, vx: float, vy: float, age: float, g: float, fl := 0.0, e := 0.45) -> Dictionary:
	var hops := 0
	while hops < 6:
		var f := toss(x, y, vx, vy, age, g, fl)
		if not f.landed:
			return {"x": f.x, "y": f.y, "vx": f.vx, "vy": f.vy, "hops": hops, "rest": false}
		var vl: float = vy + g * f.at
		age -= f.at
		x = f.lx
		y = fl - 0.01
		vx *= 0.7
		vy = -vl * e
		if absf(vy) < 25.0:
			break
		hops += 1
	return {"x": x, "y": fl - 0.25, "vx": 0.0, "vy": 0.0, "hops": hops, "rest": true}


## Stable sort (JS Array.sort is stable; GDScript's sort_custom isn't): less(a, b) true when a goes first.
static func stable_sort(a: Array, less: Callable) -> Array:
	var out := a.duplicate()
	for i in range(1, out.size()):
		var v: Variant = out[i]
		var j := i - 1
		while j >= 0 and less.call(v, out[j]):
			out[j + 1] = out[j]
			j -= 1
		out[j + 1] = v
	return out


## painter.js circle / disc as a table() K_DISC entry: a disc of radius r round (cx, cy) in c at alpha a (opaque at
## 1 on the colour layer; blended in a soft table). Below 0.6 px, a dot.
static func disc_e(cx: float, cy: float, r: float, c: Variant, a := 1.0) -> Dictionary:
	if r < 0.6:
		return {"x": floorf(cx), "y": floorf(cy), "s": 0.0, "c": c, "a": a, "e": [0.5, 0.5]}
	var X := floorf(cx)
	var Y := floorf(cy)
	return {"x": X, "y": Y, "s": r, "c": c, "a": a, "e": [cx - X, cy - Y], "reach": ceilf(r) + 1.0}


## The colour among cands nearest c (a table holds at most 16 colours; the colour layers snap to the palette anyway).
static func nearest(c: Color, cands: Array) -> Color:
	var best: Color = cands[0]
	var bd := INF
	for q in cands:
		var d: float = (q.r - c.r) ** 2 + (q.g - c.g) ** 2 + (q.b - c.b) ** 2
		if d < bd:
			bd = d
			best = q
	return best


## _lib.js firePuff(p, x, y, k, size, seed, heat) as K_DISC entries (heat: the hot-first ramp as colours).
static func fire_puff_es(x: float, y: float, k: float, size: float, seed_: float, heat: Array) -> Array:
	var age := 1.0 - k
	var n := heat.size()
	var hot := minf(0.999, pow(age, 0.62) + fmod(seed_, 1.0) * 0.1)
	var idx := mini(n - 2, int(floorf(hot * (n - 1))))
	var r := size * (0.55 + 0.45 * minf(1.0, age * 7.0)) * (1.0 - age * 0.55)
	var c: Color = heat[idx]
	if idx >= n - 2:
		# a dying puff: a see-through disc (the original blends it): soft_split() moves it to a soft table
		var e := disc_e(x, y, r, c, minf(1.0, k * 3.0) * 0.85)
		e.soft = true
		return [e]
	var out := [disc_e(x, y, r, heat[mini(n - 1, idx + 2)])]
	out.append(disc_e(x - r * 0.16, y - r * 0.22, r * 0.78, c))
	if r > 1.6:
		out.append(disc_e(x, y - r * 0.9, r * 0.42, c))
	if idx <= 3 and r > 1.8:
		out.append(disc_e(x - r * 0.28, y - r * 0.34, r * 0.36, heat[maxi(0, idx - 1)]))
	if idx < 6:
		out[0].lp = Vector2(x, y)
		out[0].lr = r * 2.4 + 2.0
		out[0].lc = c
		out[0].lk = 0.18 * k
	return out


## _lib.js spring(age, hz, damp)
static func spring(age: float, hz: float, damp: float) -> float:
	return 0.0 if age < 0.0 else exp(-age * damp) * cos(age * hz * TAU)


## The colours a SMOKE particle tinted col takes (sim.js: mix(col, rampAt(SMOKE_RAMP, age), age)), one for each of
## the ramp's five age bands and one for the lit cap of the youngest: a table holds 16 colours.
static func smoke_cols(col: Color) -> Array:
	var out := []
	for ri in 5:
		out.append(mixc(col, Color(SMOKE_RAMP[ri]), (ri + 0.5) / 5.0))
	out.append(mixc(mixc(col, Color(SMOKE_RAMP[0]), 0.1), Color.WHITE, 0.12))
	return out


## sim.js's SMOKE particle (three soft discs: a body, a denser core sitting low, a lit cap while it's young) as
## K_DISC entries for a soft table, its colours from smoke_cols(col).
static func smoke_es(x: float, y: float, age: float, life: float, col: Color, size: float, big: bool, cols: Array) -> Array:
	var k := (life - age) / life
	var ag := 1.0 - k
	var r := size * (0.65 + minf(1.0, ag * 2.5) * 0.45 + ag * (0.5 if big else 0.4))
	var a := minf(1.0, ag * 12.0) * minf(1.0, k * 2.4) * (0.7 if big else 0.58)
	var ri := clampi(int(floorf(ag * 5.0)), 0, 4)
	var c := nearest(mixc(col, Color(SMOKE_RAMP[ri]), ag), cols)
	var out := [disc_e(x, y, r, c, a * 0.45), disc_e(x + r * 0.05, y + r * 0.06, r * 0.74, c, a * 0.62)]
	if ag < 0.5:
		out.append(disc_e(x - r * 0.22, y - r * 0.3, r * 0.5, nearest(mixc(c, Color.WHITE, 0.12), cols), a * 0.4 * (1.0 - ag * 2.0)))
	return out


## Split table rows into [opaque rows, soft rows] by the entries' "soft" mark (fire_puff_es's dying puffs).
static func soft_split(rows: Array) -> Array:
	var hard := []
	var soft_ := []
	for r in rows:
		var h := []
		var s := []
		for e in r:
			if e != null and e.get("soft", false):
				s.append(e)
			else:
				h.append(e)
		hard.append(h)
		soft_.append(s)
	return [hard, soft_]
