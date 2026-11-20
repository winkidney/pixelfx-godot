# reimagined-from: src/fx/critters/eyeball.js
# Eyeball: a floating eyeball on its optic nerve darts its look between targets, blinks, its iris glowing, motes of
# green light wheeling round it on a tilted orbit.
# loop, 3.20 s, 96x108 canvas, origin [48, 100], backdrop ground
# The eye and its nerve are the original's own body cells (critter()); the motes wheeling round it are particles
# placed frame by frame on the original's orbit, each a head with its glow and a streak of line segments fading
# behind; the iris glow, the halo and the green light on the floor are one keyed light shader; its shadow a keyed
# soft ellipse on the floor.
extends "res://build/fx/critters/_critters.gd"

const LOOKS := [[0.0, 0.0, 0.0], [0.55, 4.2, -1.2], [1.15, -4.4, 0.8], [1.95, 1.2, 3.4], [2.5, -2.0, -3.4], [3.0, 0.0, 0.0]]
const R := 13.0
const HOVER := 48.0


func look(t: float) -> Vector2:
	var i := LOOKS.size() - 1
	while i > 0 and t < LOOKS[i][0]:
		i -= 1
	var a: Array = LOOKS[i]
	var b: Array = LOOKS[(i + LOOKS.size() - 1) % LOOKS.size()]
	var u := out_back(clampf((t - a[0]) / 0.08, 0.0, 1.0), 2.2)
	return Vector2(lerpf(b[1], a[1], u), lerpf(b[2], a[2], u))


func lid(t: float) -> float:
	return sin(PI * ((t - 1.74) / 0.18)) if (t > 1.74 and t < 1.92) else 0.0


func at(t: float) -> Vector2:
	var a := (t / D) * TAU
	return Vector2(1.5 * sin(a), -HOVER - 3.0 * sin(2.0 * a + 0.4))


func make() -> void:
	var I: PackedColorArray = root.ramps.iris
	blob("Shadow", 0.0, 1.5, Color("#0d0a12"), 16.0, func(i: int, t: float) -> Array: return [at(t).x, 10.0, 0.5])
	critter()
	# motes: a head (its glow) and up to five fading streak segments behind it, drawn as the original draws them
	var rows := []
	for f in NF:
		var t := ft(f)
		var S := at(t)
		var r := []
		for i in 8:
			var sp := (1.0 if i % 2 else -1.0) * (1.0 if i % 3 else 2.0)
			var a0 := (i * TAU) / 8.0
			var rr := 19.0 + (i % 3) * 2.0
			var prev: Variant = null
			for k in range(5, -1, -1):
				var a := (t / D) * TAU * sp + a0 - sp * k * 0.035
				var z := sin(a)
				var x := S.x + cos(a) * rr
				var y := S.y + z * 5.0 - cos(a) * 3.0
				var e: Variant = null
				if z < 0.0 and Vector2(x - S.x, y - S.y).length() < R + 1.0:
					prev = null
				else:
					if prev != null and k > 0:
						e = line_e(prev.x, prev.y, x, y, I[2], 0.4 + (5 - k) * 0.12)
					elif k == 0:
						e = dot_e(x, y, I[4] if z > 0.0 else I[3], 1.0, [x, y, 5.0, I[3], 0.45])
					prev = Vector2(x, y)
				if k < 5 or e != null:
					r.append(e)
		rows.append(r)
	table("Motes", K_LINE, rows, {"extra": I})
	glows("Glow", func(i: int, t: float) -> Array:
		var S := at(t)
		var L := look(t)
		var snap := 0.0
		for q in LOOKS:
			snap = maxf(snap, maxf(0.0, 1.0 - absf(jmod(t - q[0] + D / 2.0, D) - D / 2.0) / 0.2))
		var op := 1.0 - lid(t)
		var out := [{"c": I[3], "p": S + L, "r": 15.0, "k": (0.5 + 0.3 * snap) * op}, {"c": I[4], "p": S + L, "r": 5.0, "k": 0.4 * op},
			{"c": I[1], "p": S, "r": 50.0, "k": 0.3}]
		for x in range(-26, 27, 6):
			out.append({"c": I[2], "p": Vector2(S.x + x, -1.0), "r": 18.0, "k": 0.15 * (1.0 - absf(x) / 34.0)})
		return out)
