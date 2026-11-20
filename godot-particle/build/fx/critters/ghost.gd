# reimagined-from: src/fx/critters/ghost.js
# Ghost: a see-through sheet ghost drifts and bobs, its hem rippling and trailing, eyes glancing about, motes
# trickling off its hem, a cold glow round it.
# loop, 2.40 s, 96x100 canvas, origin [48, 90], backdrop ground
# The ghost is the original's own body cells, translucent where it is (critter()). The motes trickling off the hem
# are particles placed frame by frame on the original's cycle, each with its glow; the cold glow round it and the
# floor lit under it are keyed lights; its shadow a keyed soft ellipse that thins as it rises.
extends "res://build/fx/critters/_critters.gd"

const HOVER := 14.0
const TOP := 30.0


func at(t: float) -> Vector2:
	var a := (t / D) * TAU
	return Vector2(4.0 * sin(a), -HOVER - 3.0 * sin(2.0 * a + 0.8))


func make() -> void:
	blob("Shadow", 0.0, 1.6, C[0], 16.0, func(i: int, t: float) -> Array:
		var S := at(t)
		var h := clampf((-S.y - 8.0) / 16.0, 0.0, 1.0)
		return [S.x, 11.0 - 3.0 * h, 0.55 - 0.2 * h])
	critter()
	var rows := []
	for f in NF:
		var t := ft(f)
		var r := []
		cycle(t, D, 12, 4, func(g: JsRng) -> float: return g.range(1.0, 1.7), func(age: float, L: float, q: JsRng, i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var k := age / L
			var x0 := S0.x + q.range(-10, 10)
			var y0 := S0.y + 1.5
			var x := x0 + sin(age * 2.2 + i) * 2.4
			var y := y0 + q.range(5, 11) * age - 3.0 * age * age
			var a := minf(1.0, k * 6.0) * minf(1.0, (1.0 - k) * 2.2)
			var tw := 0.6 + 0.4 * sin(age * 8.0 + i * 1.7)
			r.append(dot_e(x, y, 6 if tw > 0.8 else 5, a, [x, y, 7.0, 4, 0.42 * a * tw]))
			r.append(dot_e(x, y - 1.0, 4, a * 0.7) if q.chance(0.3) else null))
		rows.append(r)
	table("Motes", K_DOT, rows)
	glows("Glow", func(i: int, t: float) -> Array:
		var S := at(t)
		var h := clampf((-S.y - 8.0) / 16.0, 0.0, 1.0)
		var out := [{"c": C[3], "p": Vector2(S.x, S.y - TOP * 0.55), "r": 54.0, "k": 0.3}, {"c": C[5], "p": Vector2(S.x - 3.0, S.y - TOP * 0.72), "r": 14.0, "k": 0.12}]
		for x in range(-24, 25, 6):
			out.append({"c": C[4], "p": Vector2(S.x + x, -1.0), "r": 16.0, "k": 0.14 * (1.0 - absf(x) / 34.0) * (1.0 - 0.4 * h)})
		return out)
