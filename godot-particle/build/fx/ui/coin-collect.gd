# reimagined-from: src/fx/ui/coin-collect.js@7bed56e70ec15538b8147f3f8caf16fd2811993b
# Coin collect: A coin bursts into a fountain of spinning coins that hang, then zip one by one into a HUD counter that pops and ticks up, glints and folds away.
# one-shot, 2.45 s, 176x116 canvas, origin [60, 102], backdrop ground
# ramp palette: #2a1405 #5c3008 #9a5a0e #d48e18 #f5b92c #ffde5e #fff4bc #ffffff
# The coins are particles: the big coin, the fountain of spinning coins (thrown, hanging, bobbing, then flying an
# arc into the HUD, each turned by its own spin) and the HUD's icon are a coin kind of the frame-table particles
# (_ui.gd, drawn by fx/ui/_bits.gdshader with the original's own coin shading), replayed from the original's update at
# its 120 Hz steps, with their trails, glints, the floor ring, the pop, the flare, the sparks, dust and stars. The HUD
# plate is fx/ui/_plate.gdshader and the count the drawWord shader (fx/ui/_word.gdshader), one word for each number
# it ticks through; every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const POP := 0.3
const FLY0 := 0.58
const GAP := 0.075
const FLY := 0.28
const FOLD := 2.0
const CY := -16.0
const HX := 50.0
const HY := -88.0
const HW := 60.0
const HH := 22.0
const IX := HX + 12.0
const IY := HY + 11.0


func make() -> void:
	var W := Color.WHITE
	var R := JsRng.new(int(meta.options.seed))
	var N := clampi(int(roundf(float(meta.options.count))), 1, 12)
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]], 0.0)
	var lights := lights_new()
	var end: float = D - 0.05
	var ink := [Color("#0d0a14"), Color("#4a4060"), Color("#2a2338"), Color("#1e1929"), Color("#141019")]
	var coins := []
	for i in N:
		var s := (i / float(maxi(1, N - 1))) * 2.0 - 1.0
		var c := {"x": 0.0, "y": CY}
		c.vx = s * R.range(55, 90) + R.range(-12, 12)
		c.vy = -R.range(170, 285)
		c.ph = R.range(0, TAU)
		c.spin = R.range(9, 14) * R.sign()
		c.state = 0
		c.t0 = FLY0 + i * GAP
		c.fx = 0.0
		c.fy = 0.0
		c.trail = []
		c.bob = R.range(0, TAU)
		coins.append(c)
	var from := int(roundf(float(meta.options.from)))
	var st := {"popped": false, "count": from, "bump": 0.0, "flash": 0.0}
	var cr := canvas_rect()
	var gback := group("FloorRingBack", {"back": true})
	var gf := group("Coins")
	var plate := shape("Plate", ush("plate"), cr.size, {"ink": ink}, {"at": cr.get_center()})
	var ghud := group("Icon")
	var words := {}
	for n in range(from, from + N + 1):
		var sp := spell("x" + str(n))
		words[n] = [sp, word("Count%d" % n, glyphs_of(sp).map(func(L: Dictionary) -> Dictionary: return L.g), "big",
			{"fill": [C[4], C[5], C[6], C[7]], "edge": W, "under": C[3], "outline": ink[0]})]
	var gfront := group("Stars")

	var upd := func(dt: float) -> void:
		var t := T
		if not st.popped and t >= POP:
			st.popped = true
			lights_add(lights, 0, CY, 46, W, 0.8, 0.14)
			lights_add(lights, 0, CY, 48, C[5], 0.6, 0.5)
			for i in 14:
				var an := (i / 14.0) * TAU + R.range(-0.2, 0.2)
				var sp := R.range(80, 170)
				spawn(ps, SPARK, cos(an) * 3, CY + sin(an) * 3, cos(an) * sp, sin(an) * sp - 30.0, R.range(0.15, 0.35))
			for i in 4:
				spawn(ps, DUST, R.range(-6, 6), -1, R.sign() * R.range(15, 40), -R.range(2, 8), R.range(0.3, 0.5), Color("#5a4f6e"), R.range(1.5, 2.5))
			for i in 10:
				var an := (i / 10.0) * TAU + R.range(-0.2, 0.2)
				var sp := R.range(70, 130)
				var down := 0.25 if sin(an) > 0.0 else 1.0
				spawn(ps, STAR, cos(an) * 6, CY + sin(an) * 6, cos(an) * sp, sin(an) * sp * down, R.range(0.35, 0.6), R.pick([C[7], C[6], C[5]]), 0.6 if i % 3 else R.range(1.2, 2))
		for c in coins:
			if not st.popped or c.state == 3:
				continue
			c.ph += c.spin * dt
			if c.state < 2:
				if c.state == 0:
					c.vy += 640.0 * dt
					c.vx -= c.vx * 2.2 * dt
					if c.vy > 0.0:
						c.state = 1
				else:
					c.vy -= c.vy * 7.0 * dt
					c.vx -= c.vx * 4.0 * dt
				c.x += c.vx * dt
				c.y += c.vy * dt
				if t >= c.t0:
					c.state = 2
					c.fx = c.x
					c.fy = c.y + sin(t * 6.0 + c.bob) * 1.5
			if c.state == 2:
				var u := clampf((t - c.t0) / FLY, 0.0, 1.0)
				var e := u * u
				var mx: float = c.fx + (IX - c.fx) * 0.35
				var my: float = minf(c.fy, IY) - 26.0
				c.x = (1.0 - e) * (1.0 - e) * c.fx + 2.0 * (1.0 - e) * e * mx + e * e * IX
				c.y = (1.0 - e) * (1.0 - e) * c.fy + 2.0 * (1.0 - e) * e * my + e * e * IY
				c.trail.push_front([c.x, c.y])
				if c.trail.size() > 7:
					c.trail.pop_back()
				if R.chance(0.25):
					spawn(ps, STAR, c.x + R.range(-2, 2), c.y + R.range(-2, 2), R.range(-8, 8), R.range(-4, 10), R.range(0.2, 0.4), R.pick([C[7], C[6]]), 0.6)
				if u >= 1.0:
					c.state = 3
					st.count += 1
					st.bump = 1.0
					st.flash = 1.0
					lights_add(lights, IX, IY, 26, C[5], 0.6, 0.25)
					for i in 3:
						var an := R.range(0, TAU)
						var sp := R.range(18, 40)
						spawn(ps, STAR, IX + cos(an) * 5, IY + sin(an) * 5, cos(an) * sp, sin(an) * sp, minf(R.range(0.25, 0.45), end - t), R.pick([C[7], C[6]]), 0.6 if i else R.range(1.2, 1.8))
		st.bump = maxf(0.0, st.bump - dt / 0.14)
		st.flash = maxf(0.0, st.flash - dt / 0.07)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var k := (t - POP) / 0.45
		lay = "back"
		if k > 0.0 and k < 1.0:
			pband(0, 0, 4.0 + 34.0 * out_cubic(k), 0.22, maxf(1.0, 3.0 * (1.0 - k)), 1.15 - k, Array(C), func(g: float) -> bool: return sin(g) < 0.0)
		sim_draw(ps, "back", "soft-back")
		lay = "coins"
		if k > 0.0 and k < 1.0:
			pband(0, 0, 4.0 + 34.0 * out_cubic(k), 0.22, maxf(1.0, 3.0 * (1.0 - k)), 1.15 - k, Array(C), func(g: float) -> bool: return sin(g) >= 0.0)
		if t < POP + 0.02:
			var y := CY + sin(t * 9.0) * 1.5
			var w := absf(cos(t * 7.0))
			poval(0, 0.5, 6.0 - 0.5 * sin(t * 9.0), 1.3, Color("#0d0a14"), -1.0, 0.6)
			for i in 2:
				var an := t * 7.0 + i * PI
				if sin(an) < 0.0:
					pdot(cos(an) * 11.0, y + sin(an) * 3.0, C[4])
			pcoin(0, y, 7, maxf(0.12, w), t > POP - 0.04)
			for i in 2:
				var an := t * 7.0 + i * PI
				if sin(an) >= 0.0:
					pdot(cos(an) * 11.0, y + sin(an) * 3.0, C[7])
					pglow(cos(an) * 11.0, y + sin(an) * 3.0, 4, C[5], 0.4)
			pglow(0, y, 20, C[5], 0.45 + 0.4 * seg(t, POP - 0.15, POP))
			if t > 0.06 and t < 0.2:
				psparkle(-3, y - 3.0, 3.5 * sin(((t - 0.06) / 0.14) * PI), C[7], C[6], 0.4)
		var pk := (t - POP) / 0.1
		if pk > 0.0 and pk < 1.0:
			pcircle(0, CY, 13.0 * (1.0 - pk) + 1.0, W if pk < 0.5 else C[6])
		var fk_ := (t - POP) / 0.2
		if fk_ > 0.0 and fk_ < 1.0:
			pflare(0, CY, 26.0 * pow(1.0 - fk_, 1.5), 1.0 - fk_, Array(C))
		var rk := (t - POP - 0.03) / 0.35
		if rk > 0.0 and rk < 1.0:
			pring(0, CY, 6.0 + 22.0 * out_cubic(rk), maxf(1.0, 2.0 * (1.0 - rk)), W if rk < 0.3 else C[6], 1.2 - rk)
		for c in coins:
			if not st.popped or c.state == 3:
				continue
			var tr: Array = c.trail
			for i in range(1, tr.size()):
				pline(tr[i - 1][0], tr[i - 1][1], tr[i][0], tr[i][1], C[6] if i < 3 else C[4], {"a": 1.2 - i / 7.0})
			var hover: float = sin(t * 6.0 + c.bob) * 1.5 if c.state == 1 else 0.0
			var w := absf(cos(c.ph))
			pcoin(c.x, c.y + hover, 5, maxf(0.15, w))
			pglow(c.x, c.y + hover, 10, C[5], 0.5 if c.state == 2 else 0.32)
			var gl := fmod(t * 1.7 + c.bob, 1.0)
			if c.state == 1 and gl < 0.12 and w > 0.5:
				psparkle(c.x - 1.0, c.y + hover - 2.0, 3.0 * sin((gl / 0.12) * PI), C[7], C[6], 0.4)
		var open := out_back(seg(t, 0.06, 0.26), 2.2) * (1.0 - in_back(seg(t, FOLD, FOLD + 0.2), 2))
		fk(plate, "material:shader_parameter/on", open > 0.04)
		var shown := -1
		lay = "hud"
		if open > 0.04:
			var h := HH * open
			var y0 := HY + (HH - h) / 2.0
			var sh := seg(t, 1.5, 1.76)
			fk(plate, "material:shader_parameter/rc", Vector4(HX, y0, HW, h))
			fk(plate, "material:shader_parameter/r", minf(4.0, h / 2.0))
			fk(plate, "material:shader_parameter/has_shine", sh > 0.0 and sh < 1.0)
			fk(plate, "material:shader_parameter/shine", HX - 6.0 + (HW + 16.0) * sh)
			if open > 0.7:
				var bump: float = st.bump
				pcoin(IX, IY, 5.5 * (1.0 + 0.3 * bump), 1, st.flash > 0.5)
				pglow(IX, IY, 14, C[5], 0.25 + 0.4 * bump)
				if bump > 0.0:
					pring(IX, IY, 7.0 + 8.0 * (1.0 - bump), 1, W if bump > 0.6 else C[6], bump * 1.3)
				var s := 2.0 * (1.0 + 0.22 * bump)
				var wp: Array = words[st.count]
				var sp: Dictionary = wp[0]
				var ww: float = sp.w * s
				var x0 := IX + 9.0
				var ty := IY - 7.0 * s / 2.0
				var items := []
				for L in glyphs_of(sp):
					items.append({"x": x0 + L.x * s, "y": ty, "sx": s, "sy": s, "flash": 1.0 if st.flash > 0.5 else 0.0})
				word_at(wp[1], items)
				shown = st.count
				if bump > 0.0:
					pglow(x0 + ww / 2.0, IY, 16, C[5], 0.3 * bump)
		for n in words:
			if n != shown:
				word_at(words[n][1], [])
		lay = "front"
		sim_draw(ps, "front")
		lights_draw(lights)

	run(upd, drw)
	utable("FloorRingBack", "back", {"parent": gback, "back": true})
	utable("Dust", "soft-back", {"parent": gback, "back": true, "soft": true})
	utable("Coins", "coins", {"parent": gf})
	utable("Icon", "hud", {"parent": ghud})
	utable("Stars", "front", {"parent": gfront})
	light_table()
	flush_keys()
