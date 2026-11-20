# reimagined-from: src/fx/critters/snake.js
# Snake: A snake slithers along the floor, head raised: humps rise and roll back down its patterned body to the tail,
# dust puffs where it touches down, its forked tongue flicks.
# loop, 2.40 s, 136x56 canvas, origin [68, 48], backdrop ground
# The snake is the original's own body cells (critter()). Its forked tongue is a line and two forks placed frame by
# frame; the dust scuffed up where each hump presses down is particles on the original's cycle, drawn as its smoke
# puffs (soft discs); the shadow along its length is one soft shader of the original's 36 ellipses, each keyed
# softer under the humps; the glint in its eye a keyed light.
extends "res://build/fx/critters/_critters.gd"

const HEAD := 30.0
const LEN := 70.0
const TONGUE := Color("#e8304a")
const DUSTC := Color("#8a7f92")

var K := TAU / 30.0
var WV := 0.0


func lift(u: float, t: float) -> float:
	var wave := pow(maxf(0.0, sin(K * u - WV * t)), 0.85)
	var env := smoothx(8.0, 18.0, u) * (1.0 - smoothx(LEN - 14.0, LEN - 2.0, u))
	var neck := 6.0 * (1.0 - u / 12.0) ** 2 if u < 12.0 else 0.0
	return 7.0 * wave * env + neck


static func radius(u: float) -> float:
	return 3.3 if u < 6.0 else lerpf(3.4, 0.6, pow((u - 6.0) / (LEN - 6.0), 1.3))


func bob(t: float) -> float:
	return 0.8 * sin(WV * t)


func tongue(t: float) -> float:
	for t0 in [0.3, 1.5]:
		var k: float = (t - t0) / 0.5
		if k >= 0.0 and k < 1.0:
			return pow(maxf(0.0, sin(k * PI * 3.0)), 0.6)
	return 0.0


func make() -> void:
	WV = (TAU * 2.0) / D
	# the shadow along its length (u = 2, 4 .. 70), softer under the humps, and one under the head
	var n := 36
	var sh := shape("Shadow", csh("shadows"), Vector2(124, 8), {"y": -0.2, "ry": 1.2, "count": n, "ink": C[0], "translucent": true},
		{"at": Vector2(-10, 0), "back": true})
	per_frame(sh, "material:shader_parameter/sh", func(i: int, t: float) -> PackedVector4Array:
		var out := PackedVector4Array()
		var u := 2.0
		while u <= LEN:
			var h := lift(u, t)
			out.append(Vector4(HEAD - u, 2.2 + radius(u) * 0.4, 0.5 * (1.0 - clampf(h / 10.0, 0.0, 1.0)) + 0.1, 0.0))
			u += 2.0
		out.append(Vector4(HEAD + 2.0, 5.0, 0.35, 0.0))
		while out.size() < 40:
			out.append(Vector4.ZERO)
		return out)
	sh.material.set_shader_parameter("count", 36)
	var tg := []
	var dust := []
	var dcols := smoke_cols(DUSTC)
	for f in NF:
		var t := ft(f)
		var hb := bob(t)
		var e := tongue(t)
		var tr := []
		if e > 0.05:
			var tx := HEAD + 7.5
			var ty := -8.2 + hb
			var L := 7.0 * e
			var wig := sin(t * 60.0) * 0.6 * e
			tr.append(line_e(tx, ty, tx + L, ty + wig, TONGUE))
			if L > 3.0:
				tr.append(dot_e(tx + L + 1.0, ty + wig - 1.0, TONGUE))
				tr.append(dot_e(tx + L + 1.0, ty + wig + 1.0, TONGUE))
		tg.append(tr)
		var dr := []
		cycle(t, D, 26, 8, func(g: JsRng) -> float: return g.range(0.6, 1.1), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var born := jmod(t - age, D)
			var m := r.int_(0, 2)
			var u := (PI + WV * born + m * TAU) / K
			if u < 18.0 or u > LEN - 10.0:
				return
			var x := HEAD - u + r.range(-2, 2)
			x -= r.range(6, 16) * age
			var y := -0.5 - age * r.range(3, 8)
			dr.append_array(smoke_es(x, y, age, L, DUSTC, r.range(1.8, 3.4), false, dcols)))
		dust.append(dr)
	table("Tongue", K_LINE, tg, {"light": false})
	critter()
	table("Dust", K_DISC, dust, {"soft": true, "extra": dcols, "light": false})
	var B: PackedColorArray = root.ramps.belly
	glows("EyeGlint", func(i: int, t: float) -> Array:
		return [{"c": B[2], "p": Vector2(HEAD + 3.5, -11.0 + bob(t)), "r": 4.0, "k": 0.35}])
