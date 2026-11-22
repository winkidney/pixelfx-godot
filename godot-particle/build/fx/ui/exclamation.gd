# reimagined-from: src/fx/ui/exclamation.js@d5dd3a8444b0b8b459f464e707a91920e0bf3095
# Exclamation: A bold ! springs up off the hero's head, stretching as it shoots up and squashing as it lands; surprise ticks flick out, it wobbles, then pops away.
# one-shot, 1.40 s, 84x104 canvas, origin [42.0, 92.0], backdrop ground, stand-in 2
# ramp palette: #2a1405 #6a2e06 #b85a0a #f08c14 #ffc23a #ffe580 #fff6c8 #ffffff
# The mark is a canvas shader (fx/ui/_bang.gdshader, the original's own pixel function) whose foot, stretch, squash
# and wobble are keyed every frame from the original's spring, replayed at its 120 Hz steps. The surprise ticks, the
# stars it throws off the head and pops into, and its glint are frame-table particles (_ui.gd); the lights are a
# light table.
extends "res://build/fx/ui/_ui.gd"

const HEAD := -40.0
const REST := -45.0
const POP := 1.1


func make() -> void:
	var W := Color.WHITE
	var R := JsRng.new(int(meta.options.seed))
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]])
	var lights := lights_new()
	var m := {"y": HEAD, "vy": -420.0, "sq": 0.0, "landed": false}
	var st := {"popped": false, "sprung": false}
	var end: float = D - 0.05
	var ticks := group("Ticks")
	var bang := shape("Bang", ush("bang"), canvas_rect().size, {"C": C}, {"at": canvas_rect().get_center()})
	var front := group("Front")

	var upd := func(dt: float) -> void:
		if T < POP:
			m.vy += (-(m.y - REST) * 900.0 - m.vy * 14.0) * dt
			m.y += m.vy * dt
			if not m.landed and m.vy > 0.0:
				m.landed = true
				m.sq = 1.0
		m.sq = maxf(0.0, m.sq - dt / 0.12)
		if not st.sprung and T >= 0.04:
			st.sprung = true
			lights_add(lights, 0, HEAD - 4, 26, C[5], 0.6, 0.25)
			for i in 8:
				var an := -PI / 2.0 + R.range(-1.3, 1.3)
				var sp := R.range(40, 90)
				spawn(ps, STAR, R.range(-4, 4), HEAD - 2, cos(an) * sp, sin(an) * sp, R.range(0.2, 0.4), R.pick([C[7], C[6], C[5]]), 0.6 if i % 3 else 1.3)
		if not st.popped and T >= POP + 0.05:
			st.popped = true
			lights_add(lights, 0, REST - 13, 28, C[5], 0.5, 0.2)
			for i in 7:
				var an := (i / 7.0) * TAU + R.range(-0.2, 0.2)
				var sp := R.range(30, 60)
				spawn(ps, STAR, cos(an) * 5, REST - 13 + sin(an) * 9, cos(an) * sp, sin(an) * sp, minf(R.range(0.2, 0.35), end - T), R.pick([C[7], C[6], C[5]]), 0.6 if i % 3 else 1.4)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var k := T
		lay = "ticks"
		for tl in [[0.04, 6.0], [0.48, 4.5]]:
			var u: float = (k - tl[0]) / 0.24
			if u <= 0.0 or u >= 1.0:
				continue
			for s in [-1.0, 1.0]:
				for i in 3:
					var an: float = -PI / 2.0 + s * (0.55 + i * 0.42)
					var r0 := 14.0 + 7.0 * out_cubic(u)
					var L: float = tl[1] * sin(u * PI) * (1.0 if i == 1 else 0.75)
					var cy := REST - 13.0
					if L < 0.8:
						continue
					pline(cos(an) * r0, cy + sin(an) * r0, cos(an) * (r0 + L), cy + sin(an) * (r0 + L), [W, C[5]], {"t": [0.5, 2.0]})
		lay = "front"
		var pu := (k - POP) / 0.06
		var on := false
		if pu < 1.0:
			var speed := minf(1.0, absf(m.vy) / 420.0)
			var up := speed if m.vy < 0.0 else 0.0
			var sx: float = 1.0 - 0.3 * up + 0.3 * m.sq
			var sy: float = 1.0 + 0.45 * up - 0.28 * m.sq
			if k < 0.05:
				sx *= k / 0.05
				sy *= k / 0.05
			if pu > 0.0:
				sx = 1.0 + 0.3 * pu
				sy = sx
			var wob := 0.28 * exp(-k * 4.0) * sin(k * 26.0)
			var white := k < 0.06 or pu > 0.0
			if sx > 0.1:
				on = true
				fk(bang, "material:shader_parameter/x", 0.0)
				fk(bang, "material:shader_parameter/y", float(m.y))
				fk(bang, "material:shader_parameter/sx", sx)
				fk(bang, "material:shader_parameter/sy", sy)
				fk(bang, "material:shader_parameter/ang", wob)
				fk(bang, "material:shader_parameter/white", white)
			pglow(0, m.y - 13.0, 20, C[5], 0.35 + (0.3 if white else 0.0))
			if k > 0.6 and k < 0.85:
				psparkle(-3, m.y - 22.0, 3.5 * sin(((k - 0.6) / 0.25) * PI), C[7], C[6], 0.4)
		fk(bang, "material:shader_parameter/on", on)
		sim_draw(ps)
		lights_draw(lights)

	run(upd, drw)
	utable("Ticks", "ticks", {"parent": ticks})
	utable("Stars", "front", {"parent": front})
	light_table()
	flush_keys()
