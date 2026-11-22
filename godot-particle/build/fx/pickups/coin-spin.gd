# reimagined-from: src/fx/pickups/coin-spin.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Coin spin: A thick gold coin turning on its edge: an embossed star face, a reeded rim showing as it goes edge-on, a flash sweeping the face, bobbing over its shadow.
# loop, 1.60 s, 56x56 canvas, origin [28, 48], backdrop ground
# ramp palette: #1e1206 #4a2c08 #86520c #c48412 #f0b424 #ffe066 #fff6c4 #ffffff
# The coin is a canvas shader running the original's coin3d() pixel by pixel (fx/pickups/_coin_spin.gdshader), its
# place and turn keyed every frame; its warm halo and the flash's light are keyed lights; the flash's star glint and
# the five twinkles round it are particles placed frame by frame where the original draws them, each with its glow.
extends "res://build/fx/pickups/_pickups.gd"

const R := 7.0
const TH := 3.0
const HOVER := 17.0


func pose(t: float) -> Dictionary:
	var ph := t / D
	return {"y": -HOVER - 2.0 * sin(ph * TAU), "th": ph * TAU}


## coin3d()'s flash: the brightest the face's sheen gets this frame (0..1).
func flash(x: float, y: float, theta: float) -> float:
	var ct := cos(theta)
	var st := sin(theta)
	var sg := -1.0 if ct < 0.0 else 1.0
	var act := absf(ct)
	var xc := (TH / 2.0) * st * sg
	var nfx := st * sg
	var ln := sqrt(0.55 * 0.55 + 0.45 * 0.45 + 0.7 * 0.7)
	var hx := -0.55 / ln
	var hz := 0.7 / ln + 1.0
	var hn := sqrt(hx * hx + hz * hz)
	var X := jround(x)
	var Y := jround(y)
	var B := ceilf(R + TH) + 2.0
	var best := 0.0
	for py in range(int(Y - B), int(Y + B) + 1):
		var sy := -(py + 0.5 - Y)
		if absf(sy) > R:
			continue
		var s := sqrt(1.0 - (sy / R) * (sy / R))
		var hw := R * s * act
		for px in range(int(X - B), int(X + B) + 1):
			var sx := px + 0.5 - X
			if absf(sx - xc) <= hw and act > 0.08:
				var fx := (sx - xc) / act
				var tx := nfx + (fx / R) * 0.3 * act
				best = maxf(best, pow(maxf(0.0, (tx * hx + act * hz) / hn / sqrt(tx * tx + act * act)), 130.0))
	return best


func make() -> void:
	var seed_ := 3
	shadow("Shadow", func(i: int, t: float) -> Array:
		var q := pose(t)
		var th: float = q.th
		return [0.0, 2.5 + 4.5 * absf(cos(th)) + 1.5 * absf(sin(th)), 0.85 - (-q.y - HOVER + 2.0) * 0.06], {"span": 12})
	glows("Glow", func(i: int, t: float) -> Array:
		var q := pose(t)
		var y: float = q.y
		var fl := flash(0.0, y, q.th)
		return [{"c": C[4], "p": Vector2(0, y), "r": 20.0, "k": 0.3 + 0.12 * absf(cos(q.th))},
			{"c": C[6], "p": Vector2(-1, y - 1), "r": 12.0, "k": 0.35 * fl}])
	var coin := body("Coin", "coin_spin", {"cx": 0.0, "cy": 0.0, "ct": 1.0, "st": 0.0, "radius": R, "thick": TH})
	per_frame(coin, "material:shader_parameter/cy", func(i: int, t: float) -> float: return jround(pose(t).y))
	per_frame(coin, "material:shader_parameter/ct", func(i: int, t: float) -> float: return cos(pose(t).th))
	per_frame(coin, "material:shader_parameter/st", func(i: int, t: float) -> float: return sin(pose(t).th))
	# the flash's star glint, then the twinkles round it one after another
	var rows := []
	for i in NF:
		var t := ft(i)
		var q := pose(t)
		var y: float = q.y
		var fl := flash(0.0, y, q.th)
		var r := []
		r.append(glint_e(-4.0, y - 4.0, 1.0 + 3.2 * fl, 6, 0.5 * fl) if fl > 0.3 else null)
		for j in 5:
			var life := 0.35
			var age := jmod(t - (j / 5.0) * D - rand([j, seed_, 3]) * 0.08, D)
			if age > life:
				r.append(null)
				continue
			var a := rand([j, seed_, 1]) * TAU + j * 2.1
			var d := 10.0 + rand([j, seed_, 2]) * 5.0
			var k := sin((age / life) * PI)
			r.append(glint_e(cos(a) * d, y + sin(a) * d * 0.85 - age * 8.0, jround(2.0 * k), 6 if j % 2 else 8, 0.35 * k))
		rows.append(r)
	table("Glints", K_GLINT, rows)
