# reimagined-from: src/fx/pickups/xp-orb.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# XP orb: A small glowing orb races a figure-eight, a comet tail tapering behind it along its path, flecks shed from the tail winking out, its light following it over the floor.
# loop, 1.80 s, 72x56 canvas, origin [36, 48], backdrop ground
# ramp palette: #0c1806 #1e3a0a #36620e #5c9614 #8cd024 #c4f060 #effcc0 #ffffff
# The orb and its comet tail are a canvas shader that runs the original's path backwards from the keyed clock (the
# tail is the orb's own path behind it: 60 discs cooling down the ramp and a white core line); the light along the
# tail is its light twin. The flecks shed from the tail and the glint on the orb are particles placed frame by frame
# where the original draws them, each with its glow; the shadow and the pool of light follow it over the floor.
extends "res://build/fx/pickups/_pickups.gd"

const A := 16.0
const B := 9.0
const HOVER := 20.0


func at(t: float) -> Vector2:
	var a := (t / D) * TAU
	return Vector2(A * sin(a), -HOVER + B * sin(a) * cos(a) - 1.2 * cos(a * 2.0))


func make() -> void:
	var seed_ := 2
	# behind: its shadow, its light on the floor, the flecks shed from the tail
	shadow("Shadow", func(i: int, t: float) -> Array: return [at(t).x, 3.5, 0.55])
	var flecks := []
	for i in NF:
		var t := ft(i)
		var r := []
		for j in 16:
			var g := rng([seed_, j, 911])
			var born := g.next() * D
			var life := g.range(0.35, 0.7)
			var age := jmod(t - born, D)
			if age >= life:
				r.append(null)
				continue
			var q := rng([seed_, j])
			var f := at(t - age)
			var k := 1.0 - age / life
			var tw := sin(age * q.range(20, 30) + q.range(0, TAU))
			var x2 := f.x + q.range(-2, 2) + age * q.range(-6, 6)
			var y2 := f.y + q.range(-2, 2) + age * q.range(4, 10)
			var c := 8 if (tw > 0.6 and k > 0.5) else (6 if k > 0.5 else 5)
			r.append(dot_e(x2, y2, c, 1.0 if tw * k > -0.2 else 0.0, [x2 + 0.5, y2 + 0.5, 3.0, C[5], 0.3 * k]))
		flecks.append(r)
	table("Flecks", K_DOT, flecks, {"back": true})
	glows("Glow", func(i: int, t: float) -> Array:
		var p := at(t)
		var beat := 0.5 + 0.5 * sin((t / D) * TAU * 3.0)
		return [{"t": G_POOL, "c": C[5], "p": Vector2(p.x, 0.5), "r": 14.0, "ry": 3.0, "k": 0.3},
			{"c": C[5], "p": p, "r": 16.0 + 3.0 * beat, "k": 0.36 + 0.14 * beat}])
	# the comet and the light along its tail
	var comet := body("Comet", "xp_orb", {"dur": D, "t": 0.0, "ink": Color("#0a1406")})
	per_frame(comet, "material:shader_parameter/t", func(i: int, t: float) -> float: return t)
	var cr := canvas_rect()
	var tail := shape("TailLight", psh("xp_orb_light"), cr.size, {"dur": D, "t": 0.0, "glow_c": C[5], "canvas": canvas_v4()},
		{"at": cr.position + cr.size / 2.0})
	per_frame(tail, "material:shader_parameter/t", func(i: int, t: float) -> float: return t)
	# a glint on the orb now and then
	var rows := []
	for i in NF:
		var t := ft(i)
		var p := at(t)
		var g := fmod((t / D) * 3.0, 1.0)
		rows.append([glint_e(jround(p.x) - 2.0, jround(p.y) - 2.0, 2.4 * sin((g / 0.12) * PI), 8, 0.4) if g < 0.12 else null])
	table("Glint", K_GLINT, rows)
