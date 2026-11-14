# reimagined-from: src/fx/scifi/emp-blast.js@77abd6a70a1981082d5bb7da665563fae4756128
# EMP blast: A disc charge ticks, pops white, and a bubble of rolling scanlines swells out with arcs crawling its skin; it strobes, tears and shorts out into falling dead pixels.
# one-shot, 3.20 s, 152x116 canvas, origin [76.0, 84.0], backdrop ground
# The original's update() is replayed here at its own 120 Hz steps with its own seeded generator, so every spawn,
# arc and dead pixel happens when and where it does there. Its particles (streaks gathering to the charge, motes,
# sparks, smoke, the fizzing dead charge) and the dead pixels the bubble shorts into are GPU particles moved by its
# physics (_ghost.gdshader, drawn by _bits.gdshader). The charge, the bubble (glass, rolling lines, tears, junk,
# strobing), the pop's disc, ring and star, and the arcs (its own bolt paths, stroked as strokeArc) are shaders
# reading each frame's state (fx/scifi/_emp.gdshader, light in _emp_light.gdshader); the pop's and the break's
# flashes are keyed glows.
extends "res://build/fx/scifi/_scifi.gd"

const POP := 0.42
const GROW := 0.32
const STROBE := 1.25
const BREAK := 1.58

var RM := 56.0
var SD := 33


func radius(t: float) -> float:
	return 0.0 if t < POP else RM * (0.12 + 0.88 * out_expo(clampf((t - POP) / GROW, 0.0, 1.0))) * (1.0 + 0.04 * clampf((t - POP - GROW) / 0.8, 0.0, 1.0))


func off_at(t: float) -> bool:
	return t > STROBE and t < BREAK and rand([SD, int(floor(t * 30.0))]) < 0.2 + 0.5 * ((t - STROBE) / (BREAK - STROBE))


func make() -> void:
	var D: float = root.duration
	SD = meta.options.seed
	RM = meta.options.radius
	var FR := Color(meta.options.fringe)
	var NF := int(round(D * 30.0))
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var R := JsRng.new(SD)
	var dt := (1.0 / 30.0) / 4.0
	ghosts_begin(0.0)
	var spawn := func(t: float, k: int, x: float, y: float, vx: float, vy: float, life: float, col: Variant = Color.WHITE, size := 1.0, delay := 0.0) -> void:
		var sd := R.next() * 100.0
		var n := 0
		var dl := delay
		while dl > 0.0:
			dl -= dt
			n += 1
		ghost(t + (n - 1) * dt, k, x, y, vx, vy, life, col, size, 0, {"seed": sd})

	var t := 0.0
	var popped := false
	var broke := false
	var next_arc := 0.0
	var star := []
	var star_at := -1
	var arcs := []
	var lights := []
	var frames := []
	for i in NF:
		if i > 0:
			for sub in 4:
				t += dt
				if t < POP - 0.05 and R.chance(0.6):
					var a := R.range(-PI, 0)
					var dd := R.range(16, 40)
					var T := R.range(0.14, 0.22)
					var v := (dd * 3.0) / (exp(3.0 * T) - 1.0)
					var c: Color = C[6] if R.chance(0.5) else C[5]
					spawn.call(t, STREAK, cos(a) * dd, -5.0 + sin(a) * dd * 0.7, -cos(a) * v, -sin(a) * v * 0.7, T, c)
				var sa := t - POP
				var sf := int(floor(t * 30.0))
				if sa >= 0.0 and sa < 0.26 and sf != star_at:
					star_at = sf
					var ln := out_back(sa / 0.05, 2.0) if sa < 0.05 else 1.0 - (sa - 0.05) / 0.26
					star = []
					for k in 7:
						var a := -PI + (k / 6.0) * PI + rand([SD, k, 3]) * 0.3 - 0.15 + R.range(-0.1, 0.1)
						var L := (20.0 + 16.0 * rand([SD, k, 5])) * maxf(0.15, ln)
						star.append(bolt_path(R, 0, -7, cos(a) * L, minf(-1.0, -7.0 + sin(a) * L), 0.28, 4))
				if sa >= 0.26:
					star = []
				if t >= POP and not popped:
					popped = true
					for k in 16:
						var a := R.range(-PI, 0)
						var sp := R.range(50, 150)
						var life := R.range(0.3, 0.6)
						var c: Color = R.pick([Color.WHITE, C[6], C[5]])
						spawn.call(t, MOTE, 0, -7, cos(a) * sp, sin(a) * sp, life, c, 0.8)
					lights.append([t - dt, Vector2(0, -20), 72.0, C[4], 0.9, 0.5])
					lights.append([t - dt, Vector2(0, -7), 30.0, Color.WHITE, 0.9, 0.12])
					for k in 60:
						var a := R.range(-PI, 0)
						var sp := R.range(90, 220)
						spawn.call(t, SPARK, 0, -7, cos(a) * sp, sin(a) * sp, R.range(0.2, 0.6))
					for k in 6:
						var x := R.range(-3, 3)
						var vx := R.range(-12, 12)
						var vy := -R.range(10, 24)
						var life := R.range(1, 1.6)
						var sz := R.range(2.5, 4)
						spawn.call(t, SMOKE, x, -4, vx, vy, life, Color("#3c3a52"), sz, R.range(0.05, 0.3))
				if popped and not broke and t >= next_arc:
					next_arc = t + (R.range(0.02, 0.05) if t > STROBE else R.range(0.05, 0.11))
					var r := radius(t)
					var a0 := R.range(0.1, PI - 0.1)
					var a1 := a0 + R.sign() * R.range(0.25, 0.6)
					var rr := r * R.range(0.92, 1)
					var pts := bolt_path(R, cos(a0) * rr, -sin(a0) * rr, cos(a1) * rr, -maxf(0.05, sin(a1)) * rr, 0.3, 4)
					arcs.append({"t": t, "pts": pts, "life": R.range(0.05, 0.1)})
					if R.chance(0.35):
						var vx := R.range(-80, 80)
						var vy := R.range(-90, 10)
						spawn.call(t, SPARK, cos(a1) * rr, -maxf(0.05, sin(a1)) * rr, vx, vy, R.range(0.15, 0.3))
				if t >= BREAK and not broke:
					broke = true
					var r := radius(t)
					lights.append([t - dt, Vector2(0, -r * 0.4), r * 1.3, C[5], 0.8, 0.3])
					for k in 70:
						var a := R.range(0.05, PI - 0.05)
						var d := r * R.range(0.6, 1)
						var vx := cos(a) * R.range(5, 25)
						var vy := -R.range(0, 20)
						var life := R.range(0.4, 1)
						var s := 2.0 if R.chance(0.3) else 1.0
						var c: Color = R.pick([Color.WHITE, C[6], C[5], C[4]])
						var ph := R.range(0, 9)
						ghost(t - dt, DEAD, cos(a) * d, -sin(a) * d, vx, vy, life, c, s, 0, {"frames": ph})
					for k in 6:
						var a0 := R.range(0.1, PI - 0.1)
						var a1 := a0 + R.range(-0.5, 0.5)
						var pts := bolt_path(R, cos(a0) * r, -sin(a0) * r, cos(a1) * r * 0.6, -maxf(0.05, sin(a1)) * r * 0.6, 0.35, 4)
						arcs.append({"t": t, "pts": pts, "life": 0.1})
					for k in 8:
						var x := R.range(-3, 3)
						var vx := R.range(-6, 6)
						var vy := -R.range(8, 18)
						var life := R.range(0.8, 1.2)
						var sz := R.range(2, 3.4)
						spawn.call(t, SMOKE, x, -4, vx, vy, life, Color("#2f2c3c"), sz, R.range(0, 0.35))
				if broke and t < D - 0.8 and R.chance(0.05):
					var x := R.range(-3, 3)
					var vx := R.range(-60, 60)
					var vy := -R.range(40, 120)
					spawn.call(t, SPARK, x, -3, vx, vy, R.range(0.15, 0.3))
				var keep := []
				for c in arcs:
					if not (t - c.t > c.life):
						keep.append(c)
				arcs = keep
		# this frame as the original draws it
		var fr := {"t": t, "strokes": []}
		if t < POP:
			var k := t / POP
			var r := 1.0 + 3.2 * k * k
			var f := int(floor(t * 30.0))
			var rr := JsRng.new(SD * 97 + f)
			for j in 1 + int(floor(k * 3.0)):
				var a := rr.range(0, TAU)
				var l := r + 2.0 + rr.range(2, 6) * k
				fr.strokes.append([bolt_path(rr, cos(a) * r, -7.0 + sin(a) * r, cos(a) * l, -7.0 + sin(a) * l, 0.4, 2), 0, 0.7])
		for b in star:
			fr.strokes.append([b, 1, 1.0 - (t - POP) / 0.3])
		for c in arcs:
			fr.strokes.append([c.pts, 2, 1.0 - (t - c.t) / (c.life + 0.03)])
		frames.append(fr)

	# each frame's state and arcs, for the shaders
	var data := Image.create(NF, 10, false, Image.FORMAT_RGBAF)
	var npts := 0
	for fr in frames:
		var n := 0
		for s in fr.strokes:
			n += s[0].size()
		npts = maxi(npts, n + 1)
	var aw := maxi(8, npts)
	var arcimg := Image.create(aw, NF, false, Image.FORMAT_RGBAF)
	for i in NF:
		var fr: Dictionary = frames[i]
		var tt: float = fr.t
		var r := radius(tt)
		var vis := r > 1.0 and tt < BREAK and not off_at(tt)
		data.set_pixel(i, 0, Color(tt, r, 0.0 if vis else 1.0, 1.0 if vis else 0.0))
		var slot := int(floor(tt * 30.0))
		var tears := {}
		var order := []
		for k in 2 + (4 if tt > STROBE else 0):
			var y := int(floor(-rand([SD, slot, k]) * r))
			var s := (-1.0 if rand([SD, slot, k, 1]) < 0.5 else 1.0) * (2.0 + floorf(rand([SD, slot, k, 2]) * 4.0))
			if not tears.has(y):
				order.append(y)
			tears[y] = s
		var tl := []
		for y in order:
			tl += [float(y), tears[y]]
		while tl.size() < 12:
			tl += [9999.0, 0.0]
		for k in 3:
			data.set_pixel(i, 1 + k, Color(tl[k * 4], tl[k * 4 + 1], tl[k * 4 + 2], tl[k * 4 + 3]))
		for k in 3:
			var kk := rand([SD, slot, k, 7])
			if kk > 0.5:
				data.set_pixel(i, 7 + k, Color(0, 0, 0, 0))
				continue
			var a := rand([SD, slot, k, 8]) * PI
			var d := rand([SD, slot, k, 9]) * r * 0.85
			var bx := floorf(cos(a) * d + 0.5)
			var by := floorf(-sin(a) * d + 0.5)
			data.set_pixel(i, 4 + k, Color(bx, by, 2.0 + floorf(kk * 8.0), 1.0 + floorf(kk * 4.0)))
			data.set_pixel(i, 7 + k, Color(1.0 if kk < 0.2 else 0.0, 1.0, 0, 0))
		var j := 0
		var sid := 0
		for s in fr.strokes:
			for p in s[0]:
				arcimg.set_pixel(j, i, Color(p.x, p.y, sid + 1000 * s[1], s[2]))
				j += 1
			sid += 1
		arcimg.set_pixel(j, i, Color(0, 0, -1, 0))
	var dtex := asset("_state", data)
	var atex := asset("_arcs", arcimg)
	keep_colour(FR)

	var params := {"frame": 0.0, "data": dtex, "arcs": atex, "arc_width": aw, "pal": C, "fringe": FR, "rm": RM}
	var p0 := params.duplicate()
	p0.mode = 0
	var far := shape("BubbleFar", sh("emp"), canvas, p0, {"at": mid})
	ghosts({"only": "back", "back": false, "floor": 0.0, "sparks": [Color.WHITE, C[6], C[5], C[4]], "haze": C[5]})
	var p1 := params.duplicate()
	p1.mode = 1
	var front := shape("Blast", sh("emp"), canvas, p1, {"at": mid})
	ghosts({"only": "front", "back": false, "floor": 0.0, "sparks": [Color.WHITE, C[6], C[5], C[4]], "cool": C[3]})
	var lp := params.duplicate()
	lp.erase("fringe")
	lp.erase("rm")
	var lit := shape("Light", sh("emp_light"), canvas, lp, {"at": mid})
	for n in [far, front, lit]:
		keyf(n, "material:shader_parameter/frame", func(tt: float) -> float: return float(int(roundf(tt * 30.0))), 0.0, -1.0, 30.0, "nearest")
	var li := 0
	for l in lights:
		light_add("Flash%d" % li, l[1], l[2], l[3], l[4], l[5], l[0])
		li += 1
