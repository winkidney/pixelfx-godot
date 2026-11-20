# reimagined-from: src/fx/critters/frog.js
# Frog: A frog puffs its throat, blinks, crouches and leaps to snap a buzzing fly out of the air, then lands with a
# squash and a puff of dust, gulps and settles.
# loop, 2.60 s, 112x88 canvas, origin [56, 80], backdrop ground
# The frog is the original's own body cells (critter()). Its tongue whipping out to the fly, the fly buzzing, the
# dust thrown along the floor at take-off and landing (soft discs, as the original's smoke puffs) and the grit
# bouncing are particles placed frame by frame from the original's formulas; its shadow a keyed soft ellipse that
# shrinks and fades as it leaps.
extends "res://build/fx/critters/_critters.gd"

const T_CROUCH := 0.95
const T_UP := 1.2
const T_LAND := 1.62
const T_SNAP := 1.4
const T_BACK := 1.95
const G := 1000.0
const TONGUE := Color("#e8607a")
const FLY := Color("#141018")
const WINGS := Color("#c8d0e0")
const DUSTC := Color("#8a7f92")

var HOP := (G * (T_LAND - T_UP) ** 2) / 8.0


func by_(t: float) -> float:
	if t >= T_UP and t < T_LAND:
		var q := (t - T_UP) / (T_LAND - T_UP)
		return -HOP * 4.0 * q * (1.0 - q)
	return 0.0


func fly_at(t: float) -> Variant:
	if t > T_SNAP and t < T_BACK:
		return null
	var a := (t / D) * TAU * 3.0
	var home := Vector2(16.0 + 6.0 * sin(a), -40.0 + 3.0 * sin(2.0 * a))
	var inn := jmod(t - T_BACK, D)
	if inn < 0.45:
		var u := out_cubic(inn / 0.45)
		return Vector2(lerpf(-52.0, home.x, u), lerpf(-46.0, home.y, u) + sin(inn * 30.0) * 1.5)
	return home


func make() -> void:
	blob("Shadow", -0.2, 1.6, C[0], 16.0, func(i: int, t: float) -> Array:
		var h := clampf(-by_(t) / HOP, 0.0, 1.0)
		return [0.0, 13.0 * (1.0 - 0.35 * h), 0.6 - 0.3 * h])
	critter()
	var tongue := []
	var tip := []
	var bits := []
	var dust := []
	var dcols := smoke_cols(DUSTC)
	var tdark := mixc(TONGUE, C[0], 0.4)
	for f in NF:
		var t := ft(f)
		var by := by_(t)
		var tr := []
		var pr := []
		var ts := (t - T_SNAP + 0.06) / 0.14
		if ts > 0.0 and ts < 1.0:
			var fp: Vector2 = fly_at(T_SNAP - 0.001)
			var e := sin(PI * ts)
			var my := by - 8.0
			var x1 := lerpf(11.0, fp.x, e)
			var y1 := lerpf(my, fp.y, e)
			tr.append(line_e(11.0, my, x1, y1, TONGUE))
			tr.append(line_e(11.0, my + 1.0, x1, y1 + 1.0, tdark))
			pr.append(disc_e(x1, y1, 1.4, TONGUE))
		tongue.append(tr)
		tip.append(pr)
		var br := []
		var fp2: Variant = fly_at(t)
		if fp2 != null:
			var flap := sin(t * 90.0) > 0.0
			br.append(dot_e(fp2.x, fp2.y, FLY, 1.0, [fp2.x, fp2.y, 3.0, WINGS, 0.15]))
			br.append(dot_e(fp2.x + 1.0, fp2.y, FLY))
			br.append(dot_e(fp2.x, fp2.y - (1.0 if flap else 0.0), WINGS, 0.8))
			br.append(dot_e(fp2.x + 1.0, fp2.y - (0.0 if flap else 1.0), WINGS, 0.8))
		var dr := []
		for b in [[T_UP, 7, 0.6], [T_LAND, 18, 1.0]]:
			var t0: float = b[0]
			var pw: float = b[2]
			var age := jmod(t - t0, D)
			for i in int(b[1]):
				var r := rng([1, i, t0 * 100.0])
				var L := r.range(0.6, 1.1) * pw
				if age > L:
					continue
				var s := r.sign()
				var v := r.range(24, 70) * pw
				var x := s * (7.0 + (v / 3.5) * (1.0 - exp(-age * 3.5)))
				var y := -1.5 - r.range(1, 5) * age
				var size := r.range(2.2, 4.2) * (0.65 + 0.35 * pw)
				if age < L:
					dr.append_array(smoke_es(x, y, age, L, DUSTC, size, true, dcols))
			if pw == 1.0:
				for i in 8:
					var r := rng([1, i, 909])
					var gx := r.range(-8, 8)
					var gvx := r.range(-40, 40)
					var q := toss(gx, -1.0, gvx, -r.range(30, 70), age, 700.0, -0.5)
					if age < 0.7:
						br.append(dot_e(q.x, q.y, Color("#6a6074") if i % 2 else Color("#9a90a4"), (1.4 - age * 2.0) if q.landed else 1.0))
		bits.append(br)
		dust.append(dr)
	table("Tongue", K_LINE, tongue, {"light": false})
	table("TongueTip", K_DISC, tip, {"light": false})
	table("Bits", K_DOT, bits)
	table("Dust", K_DISC, dust, {"soft": true, "extra": dcols, "light": false})
