# reimagined-from: src/fx/melee/whip-crack.js@92794f205ad2aa49b6e98a0abc48152570b98ec7
# Whip crack: A whip rolls out to the right as a loop running down its length, faster and faster, until the tip flips over and cracks: a white pop, a ring of air, sparks and a puff of smoke.
# one-shot, 0.85 s, 192x80 canvas, origin [30.0, 68.0], backdrop ground, stand-in 2
# The whip is fx/melee/_whip.gdshader: the original's curve (straight, the running loop, folded back; recoil and sag)
# from the loop's position keyed on its accelerating run, drawn three times (two dotted afterimages a beat behind);
# the tip's white streak is Line2Ds on the tip's last positions; the crack is the impact star (fx/melee/_star), a
# ring of dots (fx/melee/_dotring), slivers and light; sparks, a puff of smoke and twinkles are the original's spawns
# replayed on GPU particles (fx/melee/_kinds.gdshader).
extends "res://build/fx/melee/_melee.gd"

const ROLL0 := 0.02
const ROLL := 0.19
const CRACK := ROLL0 + ROLL
const RECOIL := 0.16
const HX := 11.0
const HY := -21.0

var L := 76.0


func lam(t: float) -> float:
	return L * (0.34 + 0.66 * in_quad((t - ROLL0) / ROLL))


func recoil(t: float) -> float:
	return smooth(CRACK + 0.04, CRACK + 0.04 + RECOIL, t)


## The whip's tip at t (the last point of the original's shape()).
func tip_at(t: float) -> Vector2:
	var l := lam(t)
	var r := 6.5 - 3.5 * (l / L)
	var s := floorf(L * (1.0 - recoil(t) * 0.85))
	if s <= l:
		return Vector2(HX + s, HY - sin(PI * s / maxf(l, 1.0)) * 2.5 * (1.0 - l / L))
	if s <= l + PI * r:
		var th := (s - l) / r
		return Vector2(HX + l + sin(th) * r, HY + r - cos(th) * r)
	return Vector2(HX + l - (s - l - PI * r), HY + 2.0 * r)


func make() -> void:
	L = meta.options.length
	var TIP := Vector2(HX + L, HY - 1.0)
	var end := CRACK + 0.04 + RECOIL
	var spikes := []
	var angs := [0, 0.8, 1.6, 2.4, 3.14, 3.9, 4.7, 5.5]
	for i in angs.size():
		spikes.append([angs[i] + R.rf(-0.15, 0.15), (13.0 if i == 0 else 6.0 if i % 2 else 9.0) + R.rf(0, 3), 1.4 + R.rf(0, 0.5)])
	var sl := []
	for a in [-1.2, -0.3, 0.5, 1.3]:
		sl.append([a + R.rf(-0.2, 0.2), R.rf(4, 6), R.rf(80, 120), R.rf(0.4, 0.7)])

	# afterimages of the whip a beat and two beats back, then the whip
	var lo := Vector2(HX - 4, HY - 12)
	var hi := Vector2(HX + L + 12, HY + 22)
	for w in [[0.03, C[1], 0.5, "After2"], [0.015, C[2], 0.7, "After1"], [0.0, C[4], 1.0, "Whip"]]:
		var lag: float = w[0]
		var main: bool = lag == 0.0
		var a: float = w[2]
		var n := shape(w[3], mel_shader("whip"), hi - lo, {"hand": Vector2(HX, HY), "Lw": L, "dotted": 0.0 if main else 1.0, "dcol": w[1],
			"c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5]}, {"at": (lo + hi) / 2.0})
		keyd(n, ["l", "len", "recoil", "fade"], func(t: float) -> Dictionary:
			var tt := maxf(0.0, t - lag)
			var f := (1.0 - smooth(end - 0.06, end, t)) if main else (a if t < CRACK else 0.0)
			return {"l": lam(tt), "len": L * (1.0 - recoil(tt) * 0.85), "recoil": recoil(tt), "fade": f if t < end else 0.0}, 0.0, end + 0.02)
		key(n, "material:shader_parameter/before", [[0.0, 1.0], [CRACK, 0.0]], "nearest")
	# the running loop is the fastest part: it shines
	glow_path("LoopLight", 13, C[4], func(t: float) -> Array:
		var l := lam(t)
		var r := 6.5 - 3.5 * (l / L)
		return [Vector2(HX + l + r, HY + r), 12.0, 0.4], 0.0, CRACK)
	# the tip's path just before the crack: a white-hot streak
	var trail := []
	var t := 0.0
	while t < CRACK + 0.01:
		t += 1.0 / 120.0
		if t > CRACK - 0.05 and t < CRACK + 0.01:
			trail.append([tip_at(t), t])
	for i in range(1, trail.size()):
		var a: Vector2 = trail[i - 1][0]
		var b: Vector2 = trail[i][0]
		var born: float = trail[i][1]
		seg_line("Tip%d" % i, func(tt: float) -> Array:
			var k := 1.0 - (tt - born) / 0.06
			return [a, b, Color.WHITE if k > 0.6 else C[5], k], born, born + 0.06)

	# the crack: a white pop, a ring of air, slivers
	impact_star("Pop", TIP, spikes, 24, func(tt: float) -> Array:
		if tt - CRACK < 0.035:
			return [1.0, 1.0, 0.0, Color.WHITE, C[5], C[6], C[4]]
		return [1.3, 0.5, 0.0, C[6], C[5], C[5], C[3]], CRACK, CRACK + 0.07)
	var r0 := CRACK + 0.02
	dot_ring("Air", TIP, 22, func(tt: float) -> Array:
		var k := (tt - r0) / 0.18
		var col: Color = Color.WHITE if k < 0.25 else C[5] if k < 0.5 else C[4] if k < 0.75 else C[3]
		return [4.0 + 16.0 * out_cubic(k), maxf(1.0, 2.2 * (1.0 - k)), col, 1.15 - k], r0, r0 + 0.18, {"ry_k": 0.8})
	glow_path("AirLight", 27, C[4], func(tt: float) -> Array:
		var k := (tt - r0) / 0.18
		return [TIP, 4.0 + 16.0 * out_cubic(k) + 6.0, 0.25 * (1.0 - k)], r0, r0 + 0.18)
	slivers("Slivers", TIP, sl, CRACK + 0.04, 0.12, C[6], C[5], C[5])
	glow_path("PopLight", 27, C[5], func(tt: float) -> Array: return [TIP, 26.0, 0.7 * exp(-(tt - CRACK) / 0.04)], CRACK, CRACK + 0.15)

	light_burst("Flash", CRACK, TIP, 46, C[4], 0.6, 0.3)
	light_burst("White", CRACK, TIP, 14, Color.WHITE, 0.8, 0.07)
	var sparks := []
	for i in 16:
		var a := R.rf(-1.3, 1.2)
		var v := R.rf(130, 300)
		sparks.append(sp(TIP.x, TIP.y, cos(a) * v, sin(a) * v - 40.0, R.rf(0.12, 0.36)))
	var smoke := []
	for i in 3:
		smoke.append(sp(TIP.x + R.rf(-2, 3), TIP.y + R.rf(-2, 2), R.rf(10, 40), -R.rf(6, 18), R.rf(0.5, 0.8), C[2], R.rf(2.5, 4), R.rf(0.02, 0.06)))
	var stars := []
	for i in 4:
		stars.append(sp(TIP.x + R.rf(-8, 10), TIP.y + R.rf(-8, 8), 0, -3, R.rf(0.2, 0.4), C[5] if R.chance(0.5) else Color.WHITE, R.rf(0.8, 1.8), R.rf(0.05, 0.2)))
	burst("Sparks", SPARK, CRACK, sparks)
	burst("Puff", SMOKE, CRACK, smoke)
	burst("Stars", STAR, CRACK, stars)
