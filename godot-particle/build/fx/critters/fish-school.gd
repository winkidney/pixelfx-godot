# reimagined-from: src/fx/critters/fish-school.js
# Fish school: A school of fish holds station in two depth rows: bodies wag into swinging tails, one darts ahead now
# and then, bubbles rise and caustic light ripples over them.
# loop, 4.80 s, 136x80 canvas, origin [68, 40], backdrop dark
# The fish are the original's own body cells (critter(), the back row dimmed into the water as it dims them); the
# bubbles they let go are particles placed frame by frame on the original's cycle (dots, shaded 2 x 2s and lit rims,
# each with its glow); the caustics a light shader running the original's ripple (fx/critters/_caustics.gdshader);
# the slanting shafts and the water's light one keyed light shader.
extends "res://build/fx/critters/_critters.gd"

const SCHOOL := [
	[-34.0, -16.0, 0.72, true, 0.1], [2.0, -20.0, 0.68, true, 0.55], [30.0, -10.0, 0.7, true, 0.3],
	[-22.0, 4.0, 1.0, false, 0.8], [12.0, -4.0, 1.0, false, 0.2], [-40.0, -2.0, 0.95, false, 0.45], [26.0, 14.0, 0.96, false, 0.65],
]


func place(f: Array, i: int, t: float) -> Vector2:
	var a := (t / D) * TAU
	var dt := jmod(t - fmod(i * 0.71 * D, D), D)
	var dart := 0.0
	if i == 4:
		dart = out_cubic(dt / 0.25) if dt < 0.25 else (1.0 - in_out_sine((dt - 0.25) / 1.35) if dt < 1.6 else 0.0)
	return Vector2(f[0] + 3.0 * sin(a + f[4] * TAU) + 8.0 * dart, f[1] + 1.8 * sin(2.0 * a + f[4] * 5.0))


func make() -> void:
	glows("Shafts", func(i: int, t: float) -> Array:
		var out := []
		for s in [[-30.0, 10.0, 0.0], [14.0, 7.0, 2.1], [44.0, 12.0, 4.0]]:
			var sw: float = sin((t / D) * TAU + s[2]) * 4.0
			out.append({"t": G_LINE, "c": C[4], "p": Vector2(s[0] + sw - 12.0, -40.0), "q": Vector2(s[0] + sw + 8.0, 40.0), "r": s[1], "k": 0.05})
		return out)
	critter()
	var rows := []
	for f in NF:
		var t := ft(f)
		var r := []
		cycle(t, D, 9, 14, func(g: JsRng) -> float: return g.range(1.6, 2.6), func(age: float, L: float, q: JsRng, i: int) -> void:
			var fi: Array = SCHOOL[i % SCHOOL.size()]
			var P := place(fi, i % SCHOOL.size(), jmod(t - age, D))
			var rad: float = q.range(0.6, 1.6) * fi[2]
			var ph := q.next() * TAU
			var x := P.x + 1.0 + sin(age * (4.0 + 2.0 / rad) + ph) * (0.5 + rad * 0.7)
			var y := P.y - 1.0 - (16.0 + 12.0 * rad) * age
			if y < -38.0:
				return
			r.append_array(bubble_es(x, y, rad, [6, 5, 4, 3], minf(minf(1.0, age * 4.0), minf((L - age) * 3.0, (y + 38.0) / 4.0)))))
		rows.append(r)
	table("Bubbles", K_DOT, rows)
	var cs := shape("Caustics", csh("caustics"), Vector2(132, 76), {"c3": C[3], "c4": C[4]}, {"at": Vector2(0, 0)})
	loop_t(cs)
	glows("Water", func(i: int, t: float) -> Array:
		return [{"c": C[2], "p": Vector2(0, -8), "r": 74.0, "k": 0.2}, {"c": C[3], "p": Vector2(-6, -18), "r": 40.0, "k": 0.1}])
