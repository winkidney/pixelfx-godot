# reimagined-from: src/fx/critters/jellyfish.js
# Jellyfish: A see-through jellyfish pulses: its bell squeezes to shove it up and relaxes as it sinks, frilled arms
# and long tentacles trailing, a glow inside, bubbles drifting by.
# loop, 3.20 s, 96x120 canvas, origin [48, 38], backdrop dark
# The bell and its frilled arms are the original's own body cells, in two parts (critter(): the back arms and the
# bell, then the front arms). The long tentacles are lines, segment by segment along the original's trailing strands
# (each point following where its root was a moment ago), with the stinging cells glinting on the front ones; the
# lamps round the margin, the swirl of light and plankton each squeeze shoves out, the bubbles squeezed out and
# wobbling past and the specks in the water are particles placed frame by frame, each with its glow; the light inside
# the bell and the cool glow round it are keyed lights.
extends "res://build/fx/critters/_critters.gd"

const W0 := 32.0
const H0 := 18.0

var BEAT := 0.0
var G: PackedColorArray


func squeeze(u: float) -> float:
	if u < 0.16:
		return out_cubic(u / 0.16)
	if u < 0.22:
		return 1.0
	if u < 0.72:
		return lerpf(1.0, -0.14, in_out_sine((u - 0.22) / 0.5))
	return lerpf(-0.14, 0.0, in_out_sine((u - 0.72) / 0.28))


func lift(u: float) -> float:
	return -6.0 * out_cubic(seg(u, 0.04, 0.42)) if u < 0.42 else -6.0 + 6.0 * in_out_sine((u - 0.42) / 0.58)


func bell(t: float) -> Dictionary:
	t = jmod(t, D)
	var u := fmod(t, BEAT) / BEAT
	var c := squeeze(u)
	return {"x": 2.0 * sin((t / D) * TAU), "y": lift(u), "c": c, "W": W0 * (1.0 - 0.3 * c), "H": H0 * (1.0 + 0.24 * c)}


func half_w(h: float, B: Dictionary) -> float:
	if h > B.H:
		return -1.0
	var hw: float = (B.W / 2.0) * sqrt(maxf(0.0, 1.0 - (maxf(0.0, h) / B.H) ** 2))
	if h < B.H * 0.3:
		hw -= B.c * 2.4 * (1.0 - h / (B.H * 0.3))
	return hw


## a strand hanging from the bell: off(B) -> [x, y] its root on the bell
func strand(t: float, off: Callable, ln: float, step: float, lag: float, sway: float, ph: float, pull: float) -> Array:
	var pts := []
	var B1 := bell(t)
	var o1: Array = off.call(B1)
	var s := 0.0
	while s <= ln:
		var B := bell(t - s * lag)
		var relax := 1.0 - clampf(B.c, 0.0, 1.0)
		var ox := lerpf(o1[0], off.call(B)[0], 0.4)
		var w := (0.3 + s * sway) * (0.55 + 0.65 * relax) * sin((t / D) * TAU * 2.0 - s * 0.11 + ph)
		pts.append(Vector2(B.x + ox + w + ox * s * (0.009 * relax - 0.005 * pull * B.c), B.y + o1[1] + s * (0.88 + 0.05 * B.c)))
		s += step
	return pts


func make() -> void:
	BEAT = D / 2.0
	G = root.ramps.glow
	var specks := []
	var swirl := []
	var tback := []
	var tfront := []
	var lamps := []
	var bubbles := []
	for f in NF:
		var t := ft(f)
		var B := bell(t)
		# specks drifting in the water
		var sr := []
		cycle(t, D, 16, 6, D, func(age: float, L: float, r: JsRng, _i: int) -> void:
			var x := r.range(-42, 42)
			x += sin(age * 0.8 + r.next() * 6.0) * 3.0
			var y := r.range(-34, 66)
			y += age * r.range(1, 4)
			var tw := sin(age * 2.2 + r.next() * 6.0)
			var a := minf(minf(1.0, age * 2.0), (L - age) * 2.0) * (0.35 + 0.35 * tw)
			sr.append(dot_e(x, y, G[2] if tw > 0.8 else C[3], a) if a > 0.0 else null))
		specks.append(sr)
		# each squeeze shoves out a swirl of light with plankton glinting in it, and squeezes out a few bubbles
		var wr := []
		for b in 2:
			var age := jmod(t - b * BEAT - 0.05, D)
			if age > 0.9:
				continue
			var B0 := bell(b * BEAT + 0.05)
			var e := out_cubic(age / 0.9)
			var k := 1.0 - age / 0.9
			var cx: float = B0.x
			var cy: float = B0.y + 3.0 + 14.0 * e
			var rx: float = B0.W * 0.32 + 9.0 * e
			var ry := 1.5 + 2.5 * e
			for j in 8:
				var a := (j / 8.0) * TAU + e * 0.8
				var gx := cx + cos(a) * rx
				var gy := cy + sin(a) * ry
				wr.append(dot_e(gx, gy, C[5], 0.0, [gx, gy, 5.0 + 3.0 * e, C[5], 0.14 * k]))
			for j in 7:
				var a := (j / 7.0) * TAU + e * 2.4 + b
				var x := cx + cos(a) * rx * 1.05
				var y := cy + sin(a) * ry * 1.4 - cos(a * 2.0) * 0.6
				if k < 0.15 and j % 2:
					continue
				wr.append(dot_e(x, y, G[3] if sin(a) > 0.0 else G[2], minf(1.0, k * 2.5), [x, y, 3.0, G[2], 0.3 * k]))
			for i in 4:
				var r := rng([1, b, i, 13])
				var L := r.range(1.4, 2.2)
				var ag := jmod(t - b * BEAT - 0.08 - i * 0.04, D)
				if ag > L:
					continue
				var rad := r.range(0.6, 1.5)
				var sx := r.sign()
				var x0: float = B0.W * 0.4 + r.range(0, 4)
				x0 += ag * r.range(4, 10)
				var x: float = B0.x + sx * x0
				var y: float = B0.y + 2.0 - (14.0 + 10.0 * rad) * ag + 6.0 * exp(-ag * 4.0)
				if y < -33.0:
					continue
				wr.append_array(bubble_es(x + sin(ag * 5.0 + i) * 0.8, y, rad, [G[3], G[3], G[2], G[1]], minf(minf(1.0, ag * 6.0), minf((L - ag) * 3.0, (y + 33.0) / 6.0))))
		swirl.append(wr)
		# the tentacles: back ones dimmer, behind the bell; front ones over it with stinging cells glinting
		var br := []
		var fr := []
		for i in 9:
			var r := rng([1, i, 4])
			var q := -0.88 + (1.76 * i) / 8.0 + r.range(-0.05, 0.05)
			var back := i % 2 == 1
			var ln := r.range(36, 50)
			var ph := r.range(0, TAU)
			var pts := strand(t, func(bb: Dictionary) -> Array: return [q * half_w(0.5, bb), 0.5], ln, 1.5, 0.022, 0.065, ph, 1.0)
			var n := pts.size()
			var out: Array = br if back else fr
			for kk in range(1, n):
				var u := kk / float(n - 1)
				var c: Color
				if back:
					c = C[3] if u < 0.3 else (C[2] if u < 0.7 else C[1])
				else:
					c = C[5] if u < 0.2 else (C[4] if u < 0.45 else (C[3] if u < 0.78 else C[2]))
				out.append(line_e(pts[kk - 1].x, pts[kk - 1].y, pts[kk].x, pts[kk].y, c))
			if not back:
				var kk := 3
				while kk < n:
					var tw := sin((t / D) * TAU * 2.0 - kk * 0.5 + i * 1.7)
					if tw >= 0.3:
						out.append(dot_e(pts[kk].x, pts[kk].y, G[3] if tw > 0.8 else G[2], 1.0, [pts[kk].x, pts[kk].y, 3.5, G[2], 0.35 * tw]))
					kk += 4
		tback.append(br)
		tfront.append(fr)
		# the little lamps round the margin
		var lr := []
		for s in [-1.0, 1.0]:
			for q in [0.14, 0.42, 0.78]:
				var x: float = B.x + s * half_w(0.5, B) * q
				var y: float = B.y + 1.0
				var tw: float = 0.6 + 0.4 * sin((t / D) * TAU * 3.0 + q * 9.0 + s)
				lr.append(dot_e(x, y, G[3] if tw > 0.85 else G[2], 1.0, [x, y, 4.0, G[2], 0.4 * tw]))
		lamps.append(lr)
		# bubbles wobbling up past it
		var bb := []
		cycle(t, D, 7, 7, func(g: JsRng) -> float: return g.range(1.8, 3.0), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var rad := r.range(0.6, 1.4) if r.chance(0.6) else r.range(1.6, 2.6)
			var x0 := r.range(-30, 30)
			var y0 := r.range(10, 70)
			var v := 20.0 + 13.0 * rad
			var end := minf(L, (y0 + 30.0) / v)
			if age > end:
				return
			var ph := r.next() * TAU
			var x := x0 + sin(age * (4.0 + 2.0 / rad) + ph) * (0.6 + rad * 0.8)
			var y := y0 - v * age
			bb.append_array(bubble_es(x, y, rad, [G[3], G[3], G[2], G[1]], minf(minf(1.0, age * 3.0), (end - age) * 3.0), 0.1 * sin(age * 9.0 + ph))))
		bubbles.append(bb)
	table("Specks", K_DOT, specks, {"extra": G})
	table("Swirl", K_DOT, swirl, {"extra": G})
	table("TentaclesBack", K_LINE, tback, {"extra": G, "light": false})
	critter()
	glows("BellLight", func(i: int, t: float) -> Array:
		var B := bell(t)
		var pulse: float = 0.5 + 0.5 * B.c
		var p := Vector2(B.x, B.y - B.H * 0.45)
		return [{"c": C[4], "p": p, "r": 30.0 + 6.0 * B.c, "k": 0.22 + 0.12 * pulse}, {"c": C[6], "p": p, "r": 11.0, "k": 0.14 + 0.16 * pulse},
			{"c": C[3], "p": Vector2(B.x, B.y + 6.0), "r": 58.0, "k": 0.14}])
	table("Lamps", K_DOT, lamps, {"extra": G})
	critter("Front", {"file": "front"})
	table("TentaclesFront", K_LINE, tfront, {"extra": G})
	table("Bubbles", K_DOT, bubbles, {"extra": G})
