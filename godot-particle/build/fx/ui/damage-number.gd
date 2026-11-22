# reimagined-from: src/fx/ui/damage-number.js@3f026840a40959e48e9ca9a8d1da59734157a1f6
# Damage number: a red -27 punches out of a hit spark, white for a frame, arcs up, lands with a squash, hops once and
# fades out as it lifts.
# The number is the drawWord shader (fx/ui/_word.gdshader: the original's big font, bevel, outline and shadow) whose
# place, squash, flash and fade replay the original's little physics at its 120 Hz steps, keyed every frame. The hit
# (two frames of a fat spiky star, a glint, a ring), the sparks and the two stars kicked up where it lands (the
# original's simulation replayed) are frame-table particles (_ui.gd); every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const LAND := -8.0
const FADE := 0.84


func make() -> void:
	var W := Color.WHITE
	var R := JsRng.new(int(meta.options.seed))
	var wd := spell(String(meta.options.text))
	var ps := sim_new(R, [C[7], C[6], C[4], C[2]])
	var lights := lights_new()
	var n := {"x": 0.0, "y": LAND, "vx": 34.0, "vy": -175.0, "sq": 0.0, "hops": 0}
	var spikes := []
	for i in 9:
		var an := (i / 9.0) * TAU + R.range(-0.2, 0.2)
		spikes.append([an, R.range(8, 14)])
	var st := {"hit": false}
	var gl := glyphs_of(wd)
	var ghit := group("Hit")
	var num := word("Number", gl.map(func(L: Dictionary) -> Dictionary: return L.g), "big", {"fill": [C[3], C[3], C[4], C[5]], "edge": C[6], "under": C[2],
		"outline": C[0], "shadow": scalec(C[0], 0.5)})

	var upd := func(dt: float) -> void:
		if not st.hit:
			st.hit = true
			lights_add(lights, 0, -4, 30, C[5], 0.7, 0.25)
			lights_add(lights, 0, -4, 14, W, 0.6, 0.08)
			for i in 9:
				var an := R.range(-PI * 0.95, -0.05) + (PI * 0.08 if i % 2 else 0.0)
				var sp := R.range(90, 200)
				spawn(ps, SPARK, 0, -4, cos(an) * sp, sin(an) * sp, R.range(0.1, 0.25))
		if n.hops < 2:
			n.vy += 900.0 * dt
			n.vx -= n.vx * 2.0 * dt
			n.x += n.vx * dt
			n.y += n.vy * dt
			if n.y >= LAND and n.vy > 0.0:
				n.y = LAND
				n.sq = 1.0
				n.hops += 1
				n.vy = -n.vy * 0.36 if n.hops < 2 else 0.0
				if n.hops == 1:
					for s in [-1.0, 1.0]:
						var x: float = n.x + s * 14.0
						var y := LAND + R.range(-2, 1)
						var vx: float = s * R.range(15, 35)
						var vy := -R.range(5, 20)
						var life := R.range(0.2, 0.35)
						spawn(ps, STAR, x, y, vx, vy, life, C[6], R.range(0.5, 1.2))
		n.sq = maxf(0.0, n.sq - dt / 0.09)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		lay = "hit"
		if t < 0.07:
			var big := t < 0.035
			for i in spikes.size():
				var an: float = spikes[i][0]
				var l: float = spikes[i][1] * (1.0 if big else 1.3)
				var ca := cos(an)
				var sa := sin(an)
				if big:
					pline(-sa, -4.0 + ca, ca * l * 0.7 - sa, -4.0 + sa * l * 0.7 + ca, C[4])
					pline(sa, -4.0 - ca, ca * l * 0.7 + sa, -4.0 + sa * l * 0.7 - ca, C[4])
				var q := 0.0 if big else l * 0.45
				pline(ca * q, -4.0 + sa * q, ca * l, -4.0 + sa * l, W if big else (C[6] if i % 2 else C[5]))
			if big:
				pcircle(0, -4, 3.2, W)
		elif t < 0.16:
			psparkle(0, -4, 5.0 * (1.0 - (t - 0.07) / 0.09), W, C[5], 0.6)
		var rk := t / 0.22
		if rk < 1.0:
			pring(0, -4, 3.0 + 10.0 * out_cubic(rk), maxf(1.0, 2.0 * (1.0 - rk)), W if rk < 0.4 else C[5], 1.2 - rk)
		sim_draw(ps)
		var out := seg(t, FADE, D - 0.04)
		if out < 1.0:
			var s := 2.0 + 1.4 * exp(-t * 22.0) * cos(t * 30.0)
			var sx := s
			var sy := s
			if n.sq > 0.0:
				sx = s * (1.0 + 0.18 * n.sq)
				sy = s * (1.0 - 0.2 * n.sq)
			elif n.hops < 2 and absf(n.vy) > 120.0:
				sx = s * 0.92
				sy = s * 1.1
			var ww: float = wd.w * sx
			var H := 7.0 * sy
			var x0: float = n.x - ww / 2.0
			var y0: float = n.y - H - 6.0 * in_quad(out)
			var flash := 1.0 if t < 0.035 else (0.4 if t < 0.07 else 0.0)
			var items := []
			for L in gl:
				items.append({"x": x0 + L.x * sx, "y": y0, "sx": sx, "sy": sy, "flash": flash, "a": 1.0 - out})
			word_at(num, items)
			pglow(n.x, y0 + H / 2.0, 18, C[4], 0.3 * (1.0 - out) + (0.4 * (1.0 - t / 0.1) if t < 0.1 else 0.0))
		else:
			word_at(num, [])
		lights_draw(lights)

	run(upd, drw)
	utable("Hit", "hit", {"parent": ghit})
	light_table()
	flush_keys()
