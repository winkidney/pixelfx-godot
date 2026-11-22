# Shared by the spawn build scripts (not an effect). Builds on the impacts' helpers (build/fx/impacts/_impacts.gd: the
# original's seeded generator bit for bit, its hash, colour mixes, glows and keys on its frames) and adds:
#   - run(): the original's own update() at its 120 Hz substeps with its seeded draws, at build time; jt(t) its clock.
#   - Track / track(): each of its bodies (a smoke ball, a coin, a mote, a shard, a speed line, a wisp) recorded 60 or
#     30 times a second into a packed data texture; one GPU particle per body follows it (fx/spawn/_track.gdshader, on
#     the effect's keyed clock) and a canvas shader of the effect's own draws it as the original does, on whole pixel
#     cells (fx/spawn/_track.gdshaderinc).
#   - Parts: the original's Particles bit for bit, its own draws from the generator included (grit skipping off the
#     floor, fire leaving smoke), every kind drawn as it draws it (_parts.gdshader, _parts_light.gdshader).
#   - BitsSim: its Bits (shards, chunks, drips: _shards.gdshader). Lamps: its Lights (_lamps.gdshader).
#   - body_of() / rim_of(): _lib.js's bodyOf() and rimOf() for the stand-in.
# Note: a render holds its first frame at speed 0, before any particle has been processed, so whatever the original
# shows at t = 0 (a light added in create()) is a keyed node here, not a tracked particle.
extends "res://build/fx/impacts/_impacts.gd"

const SP := "res://addons/pixelfx_particles/fx/spawn/"
## the original's substep: a 30 fps frame cut in 4 (src/core/fx.js)
const SUB := (1.0 / 30.0) / 4.0
const HZ := 60.0
## the original's particle kinds the impacts' helper doesn't name (src/core/sim.js P), and its flags (PF)
const STREAK := 2
const VAPOUR := 4
const EMBER := 7
const FIRE := 9
const SMOKES := 1
const PBACK := 4
const FIRE_RAMP := ["#ffffff", "#fff3a6", "#ffe26b", "#ffc23d", "#ff8a2a", "#f2561d", "#c9281f", "#8a1f17", "#4a1712"]


func ssh(name: String) -> Shader:
	return load(SP + "_" + name + ".gdshader")


# ------------------------------------------------------------------ the original's maths

static func clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


static func in_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return (s + 1.0) * x * x * x - s * x * x


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func in_cubic(x: float) -> float:
	return x * x * x


static func out_quad(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func in_out_sine(x: float) -> float:
	return -(cos(PI * x) - 1.0) / 2.0


static func in_out_cubic(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func out_sine(x: float) -> float:
	return sin(x * PI / 2.0)


static func out_quart(x: float) -> float:
	return 1.0 - pow(1.0 - x, 4.0)


static func out_elastic(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * (TAU / 3.0)) + 1.0


static func bump(t: float, a: float, b: float) -> float:
	return 0.0 if (t <= a or t >= b) else sin(PI * seg(t, a, b))


## math.js noise(): smooth 1D value noise in [-1, 1]
static func noise(x: float, sd := 0) -> float:
	var i := floori(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(rand([i, sd]), rand([i + 1, sd]), u) * 2.0 - 1.0


## math.js noise2(): smooth 2D value noise in [-1, 1]
static func noise2(x: float, y: float, sd := 0) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var a := rand([ix, iy, sd])
	var b := rand([ix + 1, iy, sd])
	var c := rand([ix, iy + 1, sd])
	var d := rand([ix + 1, iy + 1, sd])
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


## color.js fit(): the ramp as given (the options already hold n colours)
func ramp_of(name: String) -> PackedColorArray:
	return root.ramps[name]


# ------------------------------------------------------------------ the stand-in

## _lib.js bodyOf(): the stand-in's pixels, feet at (0, 0): [{x, y, mx, my, c, edge}], plus w, h, x, y and a lookup.
func body_of(ramp_c: PackedColorArray) -> Dictionary:
	var img: Image = load(EFFECT.STAND_INS[maxi(1, root.actor)]).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var x0 := -floori(w / 2.0)
	var y0 := -h
	var on := func(mx: int, my: int) -> bool: return mx >= 0 and my >= 0 and mx < w and my < h and img.get_pixel(mx, my).a > 0.5
	var list := []
	var cells := {}
	for my in h:
		for mx in w:
			if not on.call(mx, my):
				continue
			var c := img.get_pixel(mx, my)
			c.a = 1.0
			var b := {"x": x0 + mx, "y": y0 + my, "mx": mx, "my": my, "c": Color8(c.r8, c.g8, c.b8),
				"edge": not on.call(mx - 1, my) or not on.call(mx + 1, my) or not on.call(mx, my - 1) or not on.call(mx, my + 1)}
			list.append(b)
			cells[Vector2i(mx, my)] = b
	return {"list": list, "w": w, "h": h, "x": x0, "y": y0, "cells": cells}


## _lib.js rimOf(): the cells just outside the body: [{x, y, mx, my}]
func rim_of(body: Dictionary) -> Array:
	var out := []
	var cells: Dictionary = body.cells
	for my in range(-1, body.h + 1):
		for mx in range(-1, body.w + 1):
			if cells.has(Vector2i(mx, my)):
				continue
			if cells.has(Vector2i(mx - 1, my)) or cells.has(Vector2i(mx + 1, my)) or cells.has(Vector2i(mx, my - 1)) or cells.has(Vector2i(mx, my + 1)):
				out.append({"x": body.x + mx, "y": body.y + my, "mx": mx, "my": my})
	return out


# ------------------------------------------------------------------ tracked particles

## How many samples (60 a second, from t = 0) cover the effect.
func samples() -> int:
	return int(roundf(root.duration * HZ)) + 1


## A track: particles with `rows` Vector4 rows a sample, at `hz` samples a second (60 or 30: run() records at 60, a
## 30 Hz track keeps every other one and glides between them). put(i, s, r, Color(...)) with s run()'s sample; row 0 is
## (x, y, on, ..). put_head(i, h, Color) sets a constant of the particle's (h >= 1, `head` texels each). Packed: each
## particle keeps only the samples from its first to its last, one after another in a texture `W` texels wide.
class Track:
	const W := 2048
	var n := 1
	var rows := 1
	var head := 1
	var hz := 60.0
	var count := 1
	var cells := {}
	var heads := {}
	var span := {}
	var img: Image
	var tex: Texture2D

	func _init(rows_: int, samples_: int, hz_ := 60.0, head_ := 1) -> void:
		rows = rows_
		hz = hz_
		head = head_
		count = samples_ if hz_ >= 60.0 else (samples_ - 1) / 2 + 1

	func put(i: int, s: int, r: int, v: Color) -> void:
		if hz < 60.0:
			if s % 2:
				return
			s /= 2
		n = maxi(n, i + 1)
		cells[Vector3i(i, s, r)] = v
		var sp: Vector2i = span.get(i, Vector2i(s, s))
		span[i] = Vector2i(mini(sp.x, s), maxi(sp.y, s))

	func put_head(i: int, h: int, v: Color) -> void:
		n = maxi(n, i + 1)
		heads[Vector2i(i, h)] = v

	func image() -> Image:
		if img != null:
			return img
		var off := {}
		var at := n * head
		for i in n:
			if span.has(i):
				off[i] = at
				at += (span[i].y - span[i].x + 1) * rows
		img = Image.create(W, maxi(1, ceili(at / float(W))), false, Image.FORMAT_RGBAF)
		var put_l := func(l: int, v: Color) -> void: img.set_pixel(l % W, l / W, v)
		for i in n:
			if span.has(i):
				put_l.call(i * head, Color(span[i].x, span[i].y - span[i].x + 1, off[i], 0))
		for k in heads:
			put_l.call(k.x * head + k.y, heads[k])
		for k in cells:
			put_l.call(off[k.x] + (k.y - span[k.x].x) * rows + k.z, cells[k])
		return img


func new_track(rows: int, hz := 60.0, head := 1) -> Track:
	return Track.new(rows, samples(), hz, head)


## The original's Lights, run alongside its update(): add() as it does, step(dt) after its own, record(s) at each
## sample; draw() makes one light-layer emitter of them all (fx/spawn/_lamps.gdshader).
class Lamps:
	var list := []
	var cols := []
	var tr: Track

	func _init(samples_: int) -> void:
		tr = Track.new(2, samples_)

	func add(x: float, y: float, r: float, c: Color, k: float, life: float) -> void:
		var ci := cols.find(c)
		if ci < 0:
			cols.append(c)
			ci = cols.size() - 1
		list.append({"i": list.size(), "x": x, "y": y, "r": r, "c": ci, "k": k, "life": life, "max": life, "on": true})

	func step(dt: float) -> void:
		for l in list:
			if l.on:
				l.life -= dt
				if l.life <= 0.0:
					l.on = false

	func record(s: int) -> void:
		for l in list:
			if l.on:
				var k: float = l.life / l.max
				tr.put(l.i, s, 0, Color(l.x, l.y, 1.0, l.k * k * k))
				tr.put(l.i, s, 1, Color(l.r * (0.55 + 0.45 * k), l.c, 0, 0))


func new_lamps() -> Lamps:
	return Lamps.new(samples())


func lamps(name: String, lm: Lamps) -> GPUParticles2D:
	var top := 4.0
	for l in lm.list:
		top = maxf(top, l.r)
	var pal := []
	for i in 8:
		pal.append(lm.cols[mini(i, lm.cols.size() - 1)] if lm.cols.size() else Color.WHITE)
	return track(name, lm.tr, ssh("lamps"), int(ceilf(top)) * 2 + 3, {"pal": pal}, {"layer": "light"})


## Run the original's update(dt) at its substeps from t = 0 to the end, calling record(s) at each of the 60 Hz samples
## (s = 0 before any update, as the original's first frame). clk[s] keeps the original's own clock at each sample (its
## t, summed a substep at a time): jt(t) gives it, for beats the original tests against its t.
var clk := PackedFloat64Array()


func run(update: Callable, record: Callable) -> void:
	var n := samples()
	clk.clear()
	var c := 0.0
	for s in n:
		if s > 0:
			update.call(SUB)
			update.call(SUB)
			c += SUB
			c += SUB
		clk.append(c)
		record.call(s)


func jt(t: float) -> float:
	return clk[clampi(roundi(t * HZ), 0, clk.size() - 1)] if clk.size() else t


## The original's Particles (src/core/sim.js), bit for bit: spawn() as it does (its seed drawn from R), update(dt)
## with its own physics and its own draws from R (grit that may skip off the floor, fire that leaves smoke), record(s)
## each sample. draw() makes its emitters: the back layer (soft kinds and PF.BACK) and the front, drawn as the original
## draws each kind (fx/spawn/_parts.gdshader), and their light (_parts_light.gdshader).
class Parts:
	const G := 950.0
	var R: RefCounted
	var list := []
	var t := 0.0
	var ground := INF
	var tb: Track
	var tf: Track
	var nb := 0
	var nf := 0
	var pal := Palette.new()
	var reach := {"back": 2.0, "front": 2.0}
	var lreach := {"back": 2.0, "front": 2.0}
	## the original's ps.draw(p) with no layer: every kind in one pass, in front
	var single := false

	func _init(rng: RefCounted, samples_: int, hz := 60.0) -> void:
		R = rng
		tb = Track.new(2, samples_, hz, 3)
		tf = Track.new(2, samples_, hz, 3)

	## col: a Color, or null (FIRE and SMOKE then take their own ramps)
	func spawn(k: int, x: float, y: float, vx: float, vy: float, life: float, col: Variant = Color.WHITE, size := 1.0, delay := 0.0, flag := 0) -> void:
		var sd: float = R.next() * 100.0
		var back: bool = not single and (k in [VAPOUR, DUST, SMOKE] or (flag & PBACK) != 0)
		var i := nb if back else nf
		if back:
			nb += 1
		else:
			nf += 1
		var ci := -1 if col == null else pal.index(col)
		(tb if back else tf).put_head(i, 1, Color(k, ci, size, flag))
		(tb if back else tf).put_head(i, 2, Color(sd, 0, 0, 0))
		var lay := "back" if back else "front"
		var rr := 2.0
		var lr := 0.0
		match k:
			SPARK:
				rr = 10.0
				lr = 3.0
			MOTE:
				rr = 16.0 * size + 1.0
				lr = 2.5 + size
			STREAK:
				rr = 8.0
				lr = 4.0
			VAPOUR, DUST:
				rr = size * 1.5 + 1.0
			STAR:
				rr = roundf(size) + 2.0
				lr = 4.0 + 2.0 * roundf(size) + 1.0
			EMBER:
				lr = 3.0 + size
			SMOKE:
				rr = size * 1.6 + 2.0
			FIRE:
				rr = size * 1.2 + 2.0
				lr = size * 2.4 + 3.0
		reach[lay] = maxf(reach[lay], rr)
		lreach[lay] = maxf(lreach[lay], lr)
		list.append({"k": k, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "col": col, "size": size, "seed": sd,
			"delay": delay, "flag": flag, "i": i, "back": back})

	func update(dt: float) -> void:
		t += dt
		for i in range(list.size() - 1, -1, -1):
			var p: Dictionary = list[i]
			if p.delay > 0:
				p.delay -= dt
				continue
			p.life -= dt
			if p.life <= 0:
				if p.k == FIRE and (p.flag & SMOKES):
					var big: bool = (p.flag & BIG) != 0
					var life: float = R.range(1.3, 2.3) if big else R.range(0.8, 1.4)
					spawn(SMOKE, p.x, p.y, p.vx * 0.6, p.vy * 0.6 - 6, life, null, p.size * (0.85 if big else 0.7), 0, BIG if big else 0)
				list.remove_at(i)
				continue
			match p.k:
				FIRE:
					p.vy -= 95 * dt
					p.vx += sin(t * 17 + p.seed) * 30 * dt
					p.vx -= p.vx * 5 * dt
					p.vy -= p.vy * 3.2 * dt
				GRIT:
					p.vy += G * dt
					p.vx -= p.vx * 0.8 * dt
					var ny: float = p.y + p.vy * dt
					p.x += p.vx * dt
					if p.vy > 0 and p.y <= ground and ny >= ground:
						p.y = ground - 0.25
						if p.vy > 130 and R.chance(0.4):
							p.vy = -p.vy * 0.25
							p.vx = p.vx * 0.5 + R.range(-10, 10)
						else:
							p.vx = 0.0
							p.vy = 0.0
							p.life = minf(p.life, 0.5)
					else:
						p.y = ny
					continue
				SPARK:
					p.vy += G * 0.45 * dt
					p.vx -= p.vx * 2.2 * dt
					p.vy -= p.vy * 2.2 * dt
					var ny: float = p.y + p.vy * dt
					p.x += p.vx * dt
					if p.vy > 0 and p.y <= ground and ny >= ground:
						p.vy = -p.vy * 0.45
						p.vx *= 0.7
						p.y = ground - 0.25
					else:
						p.y = ny
					continue
				STREAK:
					p.vx += p.vx * 3 * dt
					p.vy += p.vy * 3 * dt
				FLAKE:
					p.vx -= p.vx * 2.2 * dt
					p.vy -= p.vy * 2.2 * dt - 35 * dt
					p.x += sin(t * 2.5 + p.seed) * 7 * dt
				EMBER:
					p.vy += (-30 + sin(t * 3 + p.seed) * 20) * dt
					p.vx += cos(t * 2.3 + p.seed) * 45 * dt
					p.vx -= p.vx * 1.6 * dt
					p.vy -= p.vy * 1.6 * dt
				SMOKE:
					var big: bool = (p.flag & BIG) != 0
					p.vy -= (23.0 if big else 16.0) * dt
					p.vx += sin(t * 1.3 + p.seed) * 8 * dt
					p.vx -= p.vx * 1.6 * dt
					p.vy -= p.vy * 1.2 * dt
				MOTE:
					p.vx -= p.vx * 0.6 * dt
					p.vy -= p.vy * 0.6 * dt
				_:
					var drag := 4.0 if p.k in [VAPOUR, DUST, SMOKE] else 1.6
					p.vx -= p.vx * drag * dt
					p.vy -= p.vy * drag * dt + 5 * dt
			p.x += p.vx * dt
			p.y += p.vy * dt

	func record(s: int) -> void:
		for p in list:
			if p.delay > 0:
				continue
			var k: float = p.life / p.max
			var aux := 0.0
			var aux2 := 0.0
			match p.k:
				STAR:
					aux = 0.6 + 0.4 * sin(t * (8 + fmod(p.seed, 5.0)) + p.seed)
				EMBER:
					aux = 1.0 if (k < 0.25 and sin(t * 40 + p.seed) < 0) else 0.0
				FIRE:
					var age := 1.0 - k
					var heat := minf(0.999, pow(age, 0.62) + fmod(p.seed, 1.0) * 0.1)
					aux = float(mini(7, floori(heat * 8)))
					aux2 = p.size * (0.55 + 0.45 * minf(1.0, age * 7)) * (1 - age * 0.55)
			var tr: Track = tb if p.back else tf
			tr.put(p.i, s, 0, Color(p.x, p.y, 1.0, k))
			tr.put(p.i, s, 1, Color(p.vx, p.vy, aux, aux2))


func new_parts(hz := 30.0) -> Parts:
	return Parts.new(R, samples(), hz)


## The emitters of a Parts: o.sparks (the original's sparks ramp, head .. tail), o.haze (vapour's glow colour), o.names
## ([back, front]). The back layer goes behind the stand-in, the front in front; their light on top, as the original.
func parts(name: String, ps: Parts, o: Dictionary = {}) -> Array:
	var sp: Array = o.get("sparks", FIRE_RAMP.slice(1, 5).map(func(h: String) -> Color: return Color(h)))
	var params := {"cols": ps.pal.padded(48), "sparks": sp, "fire": FIRE_RAMP.map(func(h: String) -> Color: return Color(h)),
		"smoke": SMOKE_RAMP.map(func(h: String) -> Color: return Color(h)), "white": Color.WHITE}
	var lparams := params.duplicate()
	lparams["haze"] = o.get("haze", Color.BLACK)
	var out := []
	for lay in [["back", ps.tb, ps.nb, "Back"], ["front", ps.tf, ps.nf, ""]]:
		if lay[2] == 0:
			continue
		var tr: Track = lay[1]
		var q := int(ceilf(ps.reach[lay[0]])) * 2 + 1
		out.append(track(name + lay[3], tr, ssh("parts"), q, params, {"layer": "soft", "back": lay[0] == "back" and not o.get("front", false)}))
		if ps.lreach[lay[0]] > 0.0:
			var lq := int(ceilf(ps.lreach[lay[0]])) * 2 + 1
			out.append(track(name + lay[3] + "Light", tr, ssh("parts_light"), lq, lparams, {"layer": "light"}))
	return out


## The original's Bits (src/core/sim.js): rigid debris that tumbles, bounces and settles (kind 0 SHARD, 1 CHUNK, 2
## DRIP). add() as it does, step(dt) in its update, record(s); bits() draws them (fx/spawn/_shards.gdshader).
class BitsSim:
	const G := 950.0
	var list := []
	var n := 0
	var ground := INF
	var tr: Track
	var pal := Palette.new()

	func _init(samples_: int, hz := 60.0) -> void:
		tr = Track.new(2, samples_, hz, 2)

	func add(b: Dictionary) -> void:
		var q := {"kind": 0, "vx": 0.0, "vy": 0.0, "a": 0.0, "va": 0.0, "s": 1.0, "c": Color.WHITE, "g": 1.0, "drag": 0.0, "bounce": 0.0, "rest": false}
		q.merge(b, true)
		q.life = b.get("life", 1.0)
		q.max = q.life
		q.i = n
		q.on = true
		n += 1
		tr.put_head(q.i, 1, Color(q.kind, pal.index(q.c), q.s, 0))
		list.append(q)

	func step(dt: float) -> void:
		for i in range(list.size() - 1, -1, -1):
			var b: Dictionary = list[i]
			b.life -= dt
			if b.life <= 0:
				b.on = false
				list.remove_at(i)
				continue
			if b.rest:
				continue
			b.vy += G * b.g * dt
			b.vx -= b.vx * b.drag * dt
			b.vy -= b.vy * b.drag * dt
			b.x += b.vx * dt
			b.y += b.vy * dt
			b.a += b.va * dt
			var sp: float = b.vy
			if b.g <= 0 or b.y < ground or sp <= 0:
				continue
			b.y = ground - 0.01
			if b.kind == 2:
				b.life = 0.0
			elif b.bounce > 0 and sp > 70:
				b.vy = -sp * b.bounce
				b.vx *= 0.7
				b.va *= 0.6
			else:
				b.rest = true
				b.vx = 0.0
				b.vy = 0.0

	func record(s: int) -> void:
		for b in list:
			tr.put(b.i, s, 0, Color(b.x, b.y, 1.0, minf(1.0, b.life / 0.4)))
			tr.put(b.i, s, 1, Color(b.a, 0, 0, 0))


func new_bits(hz := 60.0) -> BitsSim:
	return BitsSim.new(samples(), hz)


## The emitter of a BitsSim: ramp (a CHUNK's shading, dark to bright, 5 colours), o: layer, back.
func bits(name: String, bs: BitsSim, chunk_ramp: Array = [], o: Dictionary = {}) -> GPUParticles2D:
	var reach := 2.0
	for b in bs.tr.heads:
		reach = maxf(reach, bs.tr.heads[b].b * 1.3 + 3.0)
	var rr := chunk_ramp.duplicate()
	if rr.is_empty():
		rr = ["#1c2030", "#3a4a66", "#6e86a8", "#a8c0dc", "#e8f2ff"].map(func(h: String) -> Color: return Color(h))
	return track(name, bs.tr, ssh("shards"), int(ceilf(reach)) * 2 + 1, {"cols": bs.pal.padded(16), "ramp": rr, "white": Color.WHITE}, o)


## A colour table for tracked particles whose colours are many (mixes of the body's own): index(c) adds it once.
class Palette:
	var cols := []

	func index(c: Color) -> int:
		var k := cols.find(c)
		if k < 0:
			cols.append(c)
			k = cols.size() - 1
		return k

	func padded(n: int) -> Array:
		var out := cols.duplicate()
		while out.size() < n:
			out.append(Color.BLACK)
		return out.slice(0, n)


func _odd_quad(n: int) -> Texture2D:
	var q := n | 1
	# the shaders draw the particle themselves: the quad only gives it its size (one byte a pixel, white)
	var img := Image.create(q, q, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	return asset("_quad%d" % q, img)


## Set a canvas material's uniforms as shape() does: colour arrays to the uniform's kind, colours kept by the snap.
func set_params(m: ShaderMaterial, params: Dictionary, lit := false) -> void:
	var types := {}
	for u in m.shader.get_shader_uniform_list():
		types[u.name] = u.type
	for k in params:
		var v: Variant = params[k]
		if v is int and types.get(k, TYPE_FLOAT) == TYPE_FLOAT:
			v = float(v)
		if v is PackedColorArray or (v is Array and v.size() and v.all(func(c): return c is Color)):
			var hinted: bool = types.get(k, TYPE_PACKED_COLOR_ARRAY) == TYPE_PACKED_COLOR_ARRAY
			var arr: Variant = PackedColorArray() if hinted else PackedVector4Array()
			for c in v:
				arr.append(c if hinted else Vector4(c.r, c.g, c.b, c.a))
				if not lit:
					keep_colour(c)
			v = arr
		if v is Color and not lit:
			keep_colour(v)
		m.set_shader_parameter(k, v)


## One GPU particle per body of the track, drawn by `shader` (a canvas shader including fx/spawn/_track.gdshaderinc).
## quad: the px square each particle may draw in. o: layer ("color", "soft": translucent, "light"), back, parent.
func track(name: String, tr: Track, shader: Shader, quad: int, params: Dictionary = {}, o: Dictionary = {}) -> GPUParticles2D:
	if tr.tex == null:
		tr.tex = asset("_" + name.to_snake_case(), tr.image())
	var layer: String = o.get("layer", "color")
	var po := {"amount": tr.n, "lifetime": root.duration, "one_shot": true, "explosiveness": 1.0, "local": true,
		"texture": _odd_quad(quad), "layer": layer, "back": o.get("back", false), "parent": o.get("parent"),
		"process_shader": ssh("track"), "process_params": {"data": tr.tex, "rows": tr.rows, "samples": tr.count, "hz": tr.hz, "head": tr.head, "width": Track.W}}
	var p := particles(name, po)
	p.interpolate = false
	p.preprocess = 0.0
	var m := ShaderMaterial.new()
	m.shader = shader
	m.resource_name = name
	var pr := {"data": tr.tex, "rows": float(tr.rows), "head": float(tr.head), "width": float(Track.W), "quad": Vector2(quad | 1, quad | 1)}
	if layer == "soft":
		pr["translucent"] = true
	pr.merge(params, true)
	set_params(m, pr, layer == "light")
	p.material = m
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	return p
