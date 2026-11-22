# reimagined-from: src/fx/pickups/heart-pickup.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Heart pickup: A plump glossy heart hovering over its shadow beats lub-dub: a big squash and stretch, a smaller echo, light and a thin ring pulsing out, tiny hearts drifting off.
# loop, 1.20 s, 56x60 canvas, origin [28, 52], backdrop ground
# ramp palette: #1a0408 #4a0a14 #8a1222 #d02436 #ff4a56 #ff8a8e #ffd0cc #ffffff
# The heart is a canvas shader running the original's pillow shading over its heart curve (fx/pickups/_heart.gdshader),
# its squash, stretch and hover keyed every frame from the original's lub-dub, with the ring that snaps out on the
# big beat; its light and the ring's are keyed lights. The tiny hearts drifting off and the glint on its shoulder are
# particles placed frame by frame where the original draws them, each with its glow.
extends "res://build/fx/pickups/_pickups.gd"

const HOVER := 18.0
const HW := 7.2
const LUB := 0.04
const DUB := 0.24


static func beat(ph: float, at_: float, s: float) -> float:
	var u := ph - at_
	if u < 0.0 or u > 0.3:
		return 0.0
	return s * exp(-u * 16.0) * cos(u * 34.0)


static func pulse(ph: float) -> float:
	return beat(ph, LUB, 1.0) + beat(ph, DUB, 0.55) + beat(ph + 1.0, LUB, 1.0)


func hover(t: float) -> float:
	return -HOVER - 1.2 * sin((t / D) * TAU)


func make() -> void:
	var seed_ := 4
	shadow("Shadow", func(i: int, t: float) -> Array: return [0.0, 8.0 + 1.5 * pulse(t / D), 0.8], {"span": 14})
	# tiny hearts floating off from behind it
	var minis := []
	for i in NF:
		var t := ft(i)
		var y := hover(t)
		var r := []
		for j in 4:
			var g := rng([seed_, j, 911])
			var born := g.next() * D
			var life := 0.95
			var age := jmod(t - born, D)
			if age >= life:
				r.append(null)
				continue
			var q := rng([seed_, j])
			var side := 1.0 if j % 2 else -1.0
			var k := age / life
			var x := side * (q.range(2, 5) + age * q.range(9, 15))
			x += sin(age * 7.0 + q.range(0, TAU)) * 1.5
			var yy := y - 5.0 - age * q.range(14, 19)
			var a := minf(1.0, age / 0.12) * (1.0 - k * k)
			r.append({"x": jround(x - 2.5), "y": jround(yy - 2.0), "c": 5 if k < 0.5 else 4, "c2": 8 if k < 0.3 else 6, "a": a * 1.3,
				"reach": 5.0, "lp": Vector2(x, yy), "lr": 5.0, "lc": C[4], "lk": 0.3 * a})
		minis.append(r)
	table("MiniHearts", K_MINI, minis, {"back": true})
	glows("Glow", func(i: int, t: float) -> Array:
		var ph := t / D
		var cy := jround(hover(t))
		var b := maxf(0.0, pulse(ph))
		var l := [{"c": C[4], "p": Vector2(0, cy), "r": 22.0 + 6.0 * b, "k": 0.26 + 0.3 * b}]
		var u := jmod(ph - LUB, 1.0)
		if u < 0.28:
			var k := u / 0.28
			l.append({"t": G_RING, "c": C[4], "p": Vector2(0, cy), "r": 9.0 + 8.0 * (1.0 - pow(1.0 - k, 3.0)), "w": 4.0, "k": 0.25 * (1.0 - k)})
		return l)
	var heart := body("Heart", "heart", {"ink": Color("#12060c"), "ring_c": C[6]})
	per_frame(heart, "material:shader_parameter/cy", func(i: int, t: float) -> float: return jround(hover(t)))
	per_frame(heart, "material:shader_parameter/hw", func(i: int, t: float) -> float: return HW * (1.0 + 0.16 * pulse(t / D)))
	per_frame(heart, "material:shader_parameter/hh", func(i: int, t: float) -> float: return HW * (1.0 - 0.13 * pulse(t / D)))
	var ring := func(t: float) -> float: return jmod(t / D - LUB, 1.0) / 0.28
	per_frame(heart, "material:shader_parameter/ring_r", func(i: int, t: float) -> float:
		var k: float = ring.call(t)
		return 9.0 + 8.0 * (1.0 - pow(1.0 - k, 3.0)) if k < 1.0 else 0.0)
	per_frame(heart, "material:shader_parameter/ring_a", func(i: int, t: float) -> float:
		var k: float = ring.call(t)
		return 0.85 * (1.0 - k) if k < 1.0 else 0.0)
	per_frame(heart, "material:shader_parameter/ring_c", func(i: int, t: float) -> Color: return C[6] if ring.call(t) < 0.2 else C[5])
	# a glint on its shoulder after each beat
	var rows := []
	for i in NF:
		var t := ft(i)
		var g := jmod(t / D - LUB - 0.08, 0.5)
		rows.append([glint_e(-3.5, jround(hover(t)) - 4.0, 2.6 * sin((g / 0.12) * PI), 8, 0.45) if g < 0.12 else null])
	table("Glint", K_GLINT, rows)
