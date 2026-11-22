# reimagined-from: src/fx/pickups/potion.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Potion: A round glass flask of glowing brew rocks in the air: the brew sloshes behind the rock, bubbles rise and pop, light glows through the glass, wisps curl off the cork.
# loop, 2.40 s, 56x72 canvas, origin [28, 64], backdrop ground
# ramp palette: #1a0516 #3d0a33 #701560 #b0228f #f53cd1 #ff86e6 #ffd2f6 #ffffff
# The flask is a canvas shader running the original's flask pixel by pixel (fx/pickups/_flask.gdshader): cork, lip,
# neck and bulb, the brew under its sloshing surface, the glass catching the light; its hover, rock and slosh keyed
# every frame. The brew's light, the pool it throws on the floor and the shadow are keyed. The streak of light on the
# glass, the bubbles rising and popping, the wisps curling off the cork and the glint are particles placed frame by
# frame where the original draws them, with their glows.
extends "res://build/fx/pickups/_pickups.gd"

const RB := 7.0
const HOVER := 17.0
const CORK_TOP := -16.0
const GLASS := Color("#2a2236")
const CORK := ["#2a160c", "#4e2c16", "#7a4a26", "#a8703a", "#d09a5a"]


func pose(ph: float) -> Dictionary:
	return {"y": -HOVER - 1.4 * sin(ph * TAU), "tilt": 0.13 * sin(ph * TAU + 0.4)}


static func surface(x: float, ph: float) -> float:
	return -0.5 + 0.17 * sin(ph * TAU - 0.9) * x + 0.45 * sin(x * 0.85 + ph * TAU * 3.0)


func make() -> void:
	var seed_ := 5
	var W := Color.WHITE
	shadow("Shadow", func(i: int, t: float) -> Array:
		var y: float = pose(t / D).y
		return [0.0, 7.5, 0.8 - (-y - HOVER + 1.4) * 0.06], {"span": 12})
	# wisps curling up off the cork: thin trails that sway wider as they rise and fade
	var wisps := []
	for i in NF:
		var t := ft(i)
		var y: float = pose(t / D).y
		var r := []
		for j in 7:
			var g := rng([seed_ + 1, j, 911])
			var born := g.next() * D
			var life := g.range(1.2, 1.8)
			var age := jmod(t - born, D)
			if age >= life:
				r.resize(r.size() + 9)
				continue
			var q := rng([seed_ + 1, j])
			var side := q.sign()
			var f := q.range(3, 4.5)
			var ph0 := q.range(0, TAU)
			var vy := q.range(11, 16)
			var x0 := q.range(-1, 1)
			for k in 9:
				var a := age - k * 0.04
				if a < 0.0:
					r.append(null)
					continue
				var x := x0 + sin(a * f + ph0) * (0.8 + a * 3.2) * side
				var yy := y + CORK_TOP - 1.0 - a * vy
				var kk := (1.0 - a / life) * minf(1.0, a / 0.15) * (1.0 - k / 9.0)
				r.append(dot_e(x, yy, 8 if k == 0 else (6 if k < 3 else 5), kk * 1.4, [x, yy, 4.0, C[5], 0.3 * kk] if k == 0 else []))
		wisps.append(r)
	table("Wisps", K_DOT, wisps, {"back": true})
	glows("Glow", func(i: int, t: float) -> Array:
		var ph := t / D
		var y: float = pose(ph).y
		return [{"t": G_POOL, "c": C[5], "p": Vector2(0, 0.5), "r": 18.0, "ry": 3.0, "k": 0.3},
			{"c": C[4], "p": Vector2(0, y + 1.5), "r": 26.0, "k": 0.22},
			{"c": C[5], "p": Vector2(0, y + 2.0), "r": 10.0, "k": 0.38 + 0.08 * sin(ph * TAU * 2.0)}])
	var cork := PackedColorArray()
	for h in CORK:
		cork.append(Color(h))
	var flask := body("Flask", "flask", {"cork": cork, "glass": GLASS, "ink": Color("#120d1a"),
		"lip_l": mixc(W, C[6], 0.4), "lip_r": mixc(GLASS, C[5], 0.45), "neck_l": mixc(GLASS, C[6], 0.55), "neck_r": mixc(GLASS, C[5], 0.3),
		"wall_hi": mixc(W, C[6], 0.3), "wall_lit": mixc(GLASS, C[6], 0.5), "wall_dry": mixc(GLASS, C[5], 0.28)})
	per_frame(flask, "material:shader_parameter/cy", func(i: int, t: float) -> float: return pose(t / D).y)
	per_frame(flask, "material:shader_parameter/ct", func(i: int, t: float) -> float: return cos(pose(t / D).tilt))
	per_frame(flask, "material:shader_parameter/st", func(i: int, t: float) -> float: return sin(pose(t / D).tilt))
	per_frame(flask, "material:shader_parameter/ph", func(i: int, t: float) -> float: return t / D)
	# a curved streak of light on the glass and a pin-point; then the bubbles rising through the brew and popping
	var streak := []
	var bubbles := []
	var half_white := mixc(W, C[6], 0.5)
	for i in NF:
		var t := ft(i)
		var ph := t / D
		var q := pose(ph)
		var cy: float = q.y
		var tilt: float = q.tilt
		var r := []
		var a := 3.45
		while a < 4.35:
			r.append(dot_e(cos(a + tilt) * (RB - 2.2), cy + sin(a + tilt) * (RB - 2.2), 8 if (a > 3.7 and a < 4.1) else half_white))
			a += 0.04
		r.append(dot_e(jround(2.0 * cos(tilt) + 3.0 * sin(tilt)), jround(cy - 3.0), 8))
		streak.append(r)
		r = []
		for j in 10:
			var g := rng([seed_, j, 911])
			var born := g.next() * D
			var life := g.range(0.7, 1.3)
			var age := jmod(t - born, D)
			var b := []
			b.resize(8)
			if age < life:
				var rr_ := rng([seed_, j])
				var x0 := rr_.range(-4, 4)
				var r0 := rr_.range(0.6, 1.7)
				var vy := rr_.range(7, 13)
				var x := x0 + sin(age * rr_.range(5, 9) + rr_.range(0, TAU)) * 0.7
				var y := cy + 5.5 - vy * age
				var top := cy + surface(x, (t + age) / D)
				if y > top + 0.8:
					var rr := r0 * (0.7 + 0.5 * (age / life))
					if sqrt(x * x + (y - cy) * (y - cy)) <= RB - 1.5:
						var gl := [x + 0.5, y, 3.0, C[6], 0.15]
						if rr < 0.95:
							b[0] = dot_e(x, y, 6, 1.0, gl)
						else:
							b[0] = dot_e(x, y, 3, 1.0, gl)
							b[1] = dot_e(x + 1.0, y, 6)
							b[2] = dot_e(x, y - 1.0, 8)
							b[3] = dot_e(x + 1.0, y - 1.0, 6)
							if rr > 1.4:
								b[4] = dot_e(x - 1.0, y, 5)
								b[5] = dot_e(x, y + 1.0, 4)
				else:
					# the pop: a little arc of light and two flecks thrown up
					var k := clampf((top + 0.8 - y) / 3.0, 0.0, 1.0)
					if k < 1.0:
						var n := 0
						var aa := PI
						while aa < TAU:
							b[n] = dot_e(x + cos(aa) * (1.0 + k * 2.0), top - 0.5 + sin(aa) * (1.0 + k * 2.0) * 0.5, 8 if k < 0.5 else 6, 1.2 - k)
							n += 1
							aa += 0.6
						b.append(dot_e(x - 1.0, top - 1.5 - k * 3.0, 6, 1.0 - k))
						b.append(dot_e(x + 1.5, top - 2.0 - k * 4.0, 8, 1.0 - k))
			b.resize(10)
			r += b
		bubbles.append(r)
	table("Streak", K_DOT, streak)
	table("Bubbles", K_DOT, bubbles)
	var rows := []
	for i in NF:
		var t := ft(i)
		var g := jmod(t / D + 0.2, 0.5) / 0.5
		rows.append([glint_e(-4.0, pose(t / D).y - 4.0, 2.6 * sin((g / 0.16) * PI), 8, 0.4) if g < 0.16 else null])
	table("Glint", K_GLINT, rows)
