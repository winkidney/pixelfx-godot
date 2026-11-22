# reimagined-from: src/fx/critters/bat.js@bb60862a9fe26d3e00fe58773a460dbcd266bc5c
# Bat: a bat flaps in four snappy wing frames along a figure-eight, its body bobbing on each beat.
# The bat is the original's own body cells (critter(), lifted by _bodies.mjs), and on the downbeat the see-through
# echo of the wings it just left (a second lifted part, the original's own recoloured echo). Everything round it is
# native: the fading streak of red light its eyes leave along its flight is a light shader running the original's
# glow lines back along the path off the keyed clock (fx/critters/_bat_streak.gdshader); the moonlit dust is
# particles placed frame by frame on the original's cycle, with their glows; the eyes' glow, the moonlight on its head
# and the glints winking in its eye are keyed lights and particles.
extends "res://build/fx/critters/_critters.gd"

const FLAPS := 6.0
const LIFTS := [1.0, 0.0, -2.0, -1.0]


func at(t: float) -> Vector2:
	var a := (t / D) * TAU
	return Vector2(22.0 * sin(a), 7.0 * sin(2.0 * a))


func frame_at(t: float) -> int:
	return int(floorf(jmod((t / D) * FLAPS, 1.0) * 4.0)) % 4


## where the original draws the bat: rounded from doubles (a Vector2 is single precision, and 7 sin(2a) lands on a
## .5 now and then)
func cell(t: float) -> Vector2:
	var a := (t / D) * TAU
	return Vector2(jround(22.0 * sin(a)), jround(7.0 * sin(2.0 * a) + LIFTS[frame_at(t)]))


func make() -> void:
	var E: PackedColorArray = root.ramps.eyes
	var streak := shape("EyeStreak", csh("bat_streak"), Vector2(root.canvas_size), {"period": D, "color": E[1], "canvas": canvas_v4()},
		{"at": -Vector2(root.origin) + Vector2(root.canvas_size) / 2.0})
	per_frame(streak, "material:shader_parameter/t", func(i: int, t: float) -> float: return t)
	var dust := []
	var glints := []
	for f in NF:
		var t := ft(f)
		var r := []
		cycle(t, D, 9, 12, D, func(age: float, L: float, q: JsRng, _i: int) -> void:
			var x := q.range(-50, 50)
			x += sin(age * 1.1 + q.next() * 6.0) * 3.0
			var y := q.range(-34, 34)
			y += age * q.range(-2, 3)
			var tw := sin(age * 2.6 + q.next() * 6.0)
			var a := minf(minf(1.0, age * 2.0), (L - age) * 2.0) * (0.4 + 0.5 * tw)
			r.append(dot_e(x, y, 6 if tw > 0.7 else 5, a, [x, y, 3.0, 5, 0.2 * a] if tw > 0.5 else [])))
		dust.append(r)
		var P := cell(t)
		var g := []
		for g0 in [0.3, 1.5]:
			var k := jmod(t - g0, D) / 0.24
			var s := sin(PI * k) if k < 1.0 else 0.0
			g.append_array(sparkle_es(P.x - 2.0, P.y - 1.0, 1.0 + 2.5 * s, E[3], E[2], 0.4 * s, 4) if k < 1.0 else sparkle_es(0, 0, 0, 8, 8, 0.0, 4))
		glints.append(g)
	table("Dust", K_DOT, dust)
	critter("Echo", {"file": "echo"})
	critter()
	glows("Glow", func(i: int, t: float) -> Array:
		var P := cell(t)
		var out := [{"c": C[5], "p": P + Vector2(-3, -6), "r": 10.0, "k": 0.12}]
		for ex in [-1.5, 1.5]:
			out.append({"c": E[1], "p": P + Vector2(ex, -0.5), "r": 7.0, "k": 0.6})
			out.append({"c": E[2], "p": P + Vector2(ex, -0.5), "r": 2.5, "k": 0.5})
		out.append({"c": E[0], "p": P, "r": 22.0, "k": 0.25})
		return out)
	table("Glints", K_DOT, glints, {"extra": E})
