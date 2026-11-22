# reimagined-from: src/fx/ui/level-up.js@073eb7535ddfa4500150474847085e0c4a7ee62d
# Level up: Gold gathers at the feet and bursts up as a pillar of light round the hero; rings climb it, LEVEL UP! drops in letter by letter, a shine sweeps it, sparkles twinkle.
# one-shot, 3.20 s, 176x138 canvas, origin [88, 114], backdrop ground, stand-in 2
# ramp palette: #2a1405 #5c3008 #9a5a0e #d48e18 #f5b92c #ffde5e #fff4bc #ffffff
# The pillar is a canvas shader (fx/ui/_column.gdshader: its walls, core and streaming strands dot by dot on the
# original's own hash noise), keyed every frame. LEVEL UP! is the drawWord shader (fx/ui/_word.gdshader), each
# letter's drop, bounce, squash, pop and the shine keyed every frame from the original's physics replayed at its
# 120 Hz steps. The gathering streaks, the floor rings and climbing halos, the plate of light, the flare, the
# rays, the hero's flash, gold rim and halo, and every spark, mote, ember and star of the original's simulation are
# frame-table particles (_ui.gd); the warm light on the body is a light shader over its mask
# (fx/ui/_actor_light.gdshader); every other light is a light table.
extends "res://build/fx/ui/_ui.gd"

const REL := 0.28
const RET := 1.02
const GONE := 1.34
const TOPH := 100.0
const TY := -68.0
const DROP := 0.5
const STAG := 0.05
const LANDED := 1.06
const SHINE := 1.24
const EXIT := 2.3


static func width_at(t: float) -> float:
	return 0.0 if t < REL else 12.0 * (1.0 + 0.4 * exp(-(t - REL) * 10.0)) * (1.0 - 0.82 * smooth(RET - 0.12, RET + 0.16, t))


func make() -> void:
	var W := Color.WHITE
	var R := JsRng.new(int(meta.options.seed))
	var shadow := scalec(C[0], 0.5)
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]], 0.0)
	var lights := lights_new()
	# the stand-in (src/core/actor.js stockActor(2)): its mask and colours, feet at the origin
	var aimg: Image = load(EFFECT.STAND_INS[2]).get_image()
	var AW := aimg.get_width()
	var AH := aimg.get_height()
	var AX := -floorf(AW / 2.0)
	var AY := -float(AH)
	var has := func(i: int, j: int) -> bool: return i >= 0 and j >= 0 and i < AW and j < AH and aimg.get_pixel(i, j).a > 0.5
	var wd := spell(String(meta.options.text))
	var BASE := TY + 14.0
	var X0: float = -wd.w
	var gls := glyphs_of(wd)
	var lets := []
	for i in gls.size():
		var L: Dictionary = gls[i]
		lets.append({"w": L.w, "cx": X0 + (L.x + L.w / 2.0) * 2.0, "born": DROP + i * STAG, "pop": EXIT + i * 0.04, "off": -18.0, "v": 60.0, "sq": 0.0,
			"flash": 0.0, "on": false, "landed": false, "rest": false, "burst": false})
	var right: float = X0 + wd.w * 2.0
	var sats := []
	for i in 8:
		var s := 1.0 if i % 2 else -1.0
		var x := s * R.range(20, 60)
		var y := TY + 7.0 + (R.sign() * R.range(11, 18) if absf(x) < 50.0 else R.range(-14, 14))
		var t0 := SHINE - 0.1 + i * 0.13 + R.range(0, 0.05)
		var dur := R.range(0.32, 0.5)
		sats.append({"x": x, "y": y, "t0": t0, "dur": dur, "L": R.range(3, 6)})
	var halos := []
	var st := {"released": false, "next_halo": REL + 0.03, "gather": 0.0}
	var rush := []
	var spawn_ := func(k: int, x: float, y: float, vx: float, vy: float, life: float, col := Color.WHITE, size := 1.0, flag := 0) -> void:
		spawn(ps, k, x, y, vx, vy, minf(life, D - 0.05 - T), col, size, 0.0, flag)
	# the strands of light up the pillar: the original's rand-rolled constants
	var sa := PackedVector4Array()
	var sb := PackedVector4Array()
	for i in 9:
		sa.append(Vector4((i / 8.0 - 0.5) * 1.5 + (rand([i, 1]) - 0.5) * 0.16, 170.0 + rand([i, 2]) * 170.0, 10.0 + rand([i, 3]) * 16.0, 0.3 + rand([i, 4]) * 0.35))
		sb.append(Vector4(rand([i, 5]), 1.0 if rand([i, 6]) < 0.35 else 2.0, 0.5 + rand([i, 7]) * 0.42, 0.0))
	var cr := canvas_rect()
	var gback1 := group("RaysRings")
	var col := shape("Pillar", ush("column"), cr.size, {"C": C, "sa": sa, "sb": sb}, {"at": cr.get_center(), "back": true})
	var gback2 := group("PlateBack")
	var gf1 := group("RingsFront")
	var grim := group("Rim")
	var body_light := shape("BodyLight", ush("actor_light"), cr.size, {"body": load(EFFECT.STAND_INS[2]), "at": Vector2(AX, AY), "c": C[5],
		"canvas": canvas_v4()}, {"at": cr.get_center()})
	var gf2 := group("Front")
	var wt := word("Title", gls.map(func(L: Dictionary) -> Dictionary: return L.g), "big", {"fill": [C[3], C[4], C[5], C[6]], "edge": W, "under": C[2],
		"outline": C[0], "shadow": shadow, "glint": C[6]})
	var gtop := group("Sparkles")

	var draw_rush := func(back: bool) -> void:
		for m in rush:
			if m.back != back:
				continue
			var sp: float = sqrt(m.vx * m.vx + m.vy * m.vy)
			var ux: float = m.vx / sp
			var uy: float = m.vy / sp
			var L: float = m.len
			pline(m.x - ux * L, m.y - uy * L, m.x - ux * L * 0.4, m.y - uy * L * 0.4, m.c)
			pline(m.x - ux * L * 0.35, m.y - uy * L * 0.35, m.x, m.y, W)
			pglow(m.x, m.y, 4, C[5], 0.25)

	var upd := func(dt: float) -> void:
		var t := T
		st.gather += dt * 420.0 if t < REL else 0.0
		while st.gather >= 1.0:
			var kind := R.next()
			var sp := R.range(140, 250) * (1.0 + t * 2.0)
			var x := 0.0
			var y := 0.0
			var tx := 0.0
			var ty := 0.0
			var skip := false
			if kind < 0.42:
				var an := R.range(0, TAU)
				var Dd := R.range(22, 70)
				x = cos(an) * Dd
				y = -1.0 - absf(sin(an)) * Dd * 0.1
				tx = cos(an) * 3.0
				ty = -1.0
			elif kind < 0.84:
				var an := R.range(0, TAU)
				var Dd := R.range(34, 64)
				x = cos(an) * Dd
				y = minf(-3.0, -20.0 + sin(an) * Dd * 0.85)
				tx = cos(an) * 11.0
				ty = -20.0 + sin(an) * 14.0
			else:
				if t < REL * 0.4:
					skip = true
				else:
					x = R.range(-9, 9)
					y = -1.0
					tx = x * 0.7
					ty = -R.range(26, 44)
			if not skip:
				var dx := tx - x
				var dy := ty - y
				var l := sqrt(dx * dx + dy * dy)
				if l == 0.0:
					l = 1.0
				var m := {"x": x, "y": y, "vx": (dx / l) * sp, "vy": (dy / l) * sp, "life": minf(l / sp, REL + 0.06 - t)}
				m.len = R.range(5, 9)
				m.c = C[6] if R.chance(0.45) else C[5]
				m.back = kind > 0.84 and R.chance(0.5)
				rush.append(m)
			st.gather -= 1.0
		for i in range(rush.size() - 1, -1, -1):
			var m: Dictionary = rush[i]
			m.life -= dt
			if m.life <= 0.0:
				rush.remove_at(i)
			else:
				m.x += m.vx * dt
				m.y += m.vy * dt
		if t < REL and R.chance(0.12):
			spawn_.call(STAR, R.range(-30, 30), -R.range(0, 3), 0.0, -R.range(10, 30), R.range(0.3, 0.5), C[6], 0.6)
		if not st.released and t >= REL:
			st.released = true
			lights_add(lights, 0, -24, 90, C[5], 0.6, 0.7)
			lights_add(lights, 0, -8, 40, W, 0.6, 0.12)
			for i in 22:
				var an := (i / 22.0) * TAU + R.range(-0.12, 0.12)
				var sp := R.range(260, 460)
				var y0 := -18.0 + sin(an) * 8.0
				var vy := sin(an) * sp * 0.8
				var life := minf(minf(R.range(0.1, 0.2), (-y0 / vy) if vy > 0.0 else ((y0 + 104.0) / -vy if vy < 0.0 else 1.0)), 78.0 / absf(cos(an) * sp))
				spawn_.call(MOTE, cos(an) * 6.0, y0, cos(an) * sp, vy, life, C[7] if R.chance(0.4) else C[6], 1.0, PF_BACK if (an > 0.3 and an < PI - 0.3) else 0)
			for i in 26:
				var an := -PI / 2.0 + R.range(-1.3, 1.3)
				var sp := R.range(120, 290)
				spawn_.call(SPARK, R.range(-5, 5), -2.0, cos(an) * sp, sin(an) * sp, R.range(0.35, 0.8))
			for i in 16:
				var x := R.range(-10, 10)
				var y := R.range(-36, -4)
				var vx := R.range(-30, 30)
				var vy := -R.range(15, 60)
				var life := R.range(0.6, 1.3)
				var c: Color = R.pick([C[7], C[6], C[5]])
				var size := R.range(1.5, 2.6) if R.chance(0.35) else R.range(0.4, 0.9)
				spawn_.call(STAR, x, y, vx, vy, life, c, size, PF_BACK if R.chance(0.4) else 0)
		var Wd := width_at(t)
		if t >= st.next_halo and t < RET - 0.1:
			halos.append(t)
			st.next_halo += 0.16
		if t > REL and t < RET + 0.1 and R.chance(0.5):
			var s := R.sign()
			var y := R.range(-4, -60)
			var vy := -R.range(140, 260)
			var x := s * R.range(0.75, 1.6) * Wd
			var life := minf(R.range(0.16, 0.32), (y + 96.0) / -vy)
			var c := C[7] if R.chance(0.5) else C[6]
			var size := R.range(0.6, 1)
			spawn_.call(MOTE, x, y, 0.0, vy, life, c, size, PF_BACK if R.chance(0.5) else 0)
		if t > REL and t < 2.4 and R.chance(0.14 * (1.0 - seg(t, 1.6, 2.4))):
			var x := R.range(-20, 20)
			var y := -R.range(1, 30)
			var vx := R.range(-15, 15)
			var vy := -R.range(20, 55)
			var life := R.range(0.8, 1.6)
			var size := R.range(1, 2)
			spawn_.call(EMBER, x, y, vx, vy, life, C[5], size, PF_BACK if R.chance(0.4) else 0)
		if t > REL + 0.1 and t < 2.2 and R.chance(0.09):
			for n in 12:
				var i := R.int_(0, AW - 1)
				var j := R.int_(0, AH - 1)
				if not has.call(i, j):
					continue
				var vx := R.range(-8, 8)
				var vy := -R.range(14, 34)
				var life := R.range(0.6, 1.1)
				var c: Color = R.pick([C[7], C[6], C[5]])
				var size := 1.5 if R.chance(0.2) else 0.6
				spawn_.call(STAR, AX + i + 0.5, AY + j + 0.5, vx, vy, life, c, size, PF_BACK if R.chance(0.5) else 0)
				break
		if t > 1.0 and t < 2.5 and R.chance(0.13):
			var up := R.chance(0.6)
			var x := R.range(-58, 58) if up else R.range(-20, 20)
			var y := TY + 7.0 + R.range(-16, 16) if up else R.range(-44, -6)
			var vx := R.range(-6, 6)
			var vy := -R.range(4, 14)
			var life := R.range(0.4, 0.8)
			var c: Color = R.pick([C[7], C[6], C[6], C[5]])
			var size := R.range(1.5, 2.4) if R.chance(0.3) else 0.6
			spawn_.call(STAR, x, y, vx, vy, life, c, size, PF_BACK if R.chance(0.3) else 0)
		for L in lets:
			if t < L.born:
				continue
			L.on = true
			if not L.rest:
				L.v += 1700.0 * dt
				L.off += L.v * dt
				if L.off >= 0.0 and L.v > 0.0:
					L.off = 0.0
					if L.v > 110.0:
						L.sq = 1.0
						if not L.landed:
							L.landed = true
							L.flash = 1.0
							lights_add(lights, L.cx, BASE - 7.0, 18, C[5], 0.55, 0.25)
							for s in [-1.0, 1.0]:
								var x: float = L.cx + s * L.w
								var y := BASE - R.range(0, 3)
								var vx: float = s * R.range(15, 40)
								var vy := -R.range(5, 25)
								var life := R.range(0.25, 0.45)
								spawn_.call(STAR, x, y, vx, vy, life, C[6], R.range(0.5, 1.2))
						L.v = -L.v * 0.3
					else:
						L.v = 0.0
						L.rest = true
			L.sq = maxf(0.0, L.sq - dt / 0.1)
			L.flash = maxf(0.0, L.flash - dt / 0.12)
			if not L.burst and t >= L.pop + 0.06:
				L.burst = true
				for i in 3:
					var an := R.range(0, TAU)
					var sp := R.range(20, 55)
					var x: float = L.cx + R.range(-3, 3)
					var y := BASE - 7.0 + R.range(-4, 4)
					var life := R.range(0.3, 0.6)
					var c: Color = R.pick([C[7], C[6]])
					spawn_.call(STAR, x, y, cos(an) * sp, sin(an) * sp - 15.0, life, c, 0.6 if i else R.range(1.2, 2))
		sim_update(ps, dt)
		lights_update(lights, dt)

	var ramp := Array(C)
	var bands := func(back: bool) -> void:
		var keep := (func(g: float) -> bool: return sin(g) < 0.0) if back else (func(g: float) -> bool: return sin(g) >= 0.0)
		var t := T
		if t < REL:
			var k := seg(t, 0.02, REL)
			pband(0, 0, 4.0 + 52.0 * (1.0 - in_quad(k)), 0.2, 1.5, k * 1.1, ramp, keep)
		for dd in [[0.0, 72.0, 4.0], [0.08, 46.0, 2.5]]:
			var k: float = (t - REL - dd[0]) / 0.55
			if k > 0.0 and k < 1.0:
				pband(0, 0, 5.0 + dd[1] * out_cubic(k), 0.2, maxf(1.0, dd[2] * (1.0 - k)), 1.15 - k, ramp, keep, k < 0.15)
		for h0 in halos:
			var k: float = (t - h0) / 0.6
			if k > 0.0 and k < 1.0:
				pband(0, -2.0 - 72.0 * out_quad(k), (width_at(t) * 1.45 + 4.0) * (1.0 - 0.4 * k), 0.3, 1.5, (1.0 - k) * 1.4, ramp, keep, k < 0.12)

	var drw := func(_f: int) -> void:
		var t := T
		# drawBack
		lay = "back1"
		var rk := out_expo(seg(t, LANDED, LANDED + 0.2)) * (1.0 - in_quad(seg(t, EXIT - 0.15, EXIT + 0.1)))
		if rk > 0.02:
			var cx := 0.0
			var cy := TY + 7.0
			for i in 20:
				var an := (i / 20.0) * TAU + 0.08
				var ca := cos(an)
				var sa_ := sin(an)
				if absf(sa_) < 0.4:
					continue
				var r0 := 1.0 / sqrt(pow(ca / 52.0, 2.0) + pow(sa_ / 12.0, 2.0)) + 2.0 * rk
				var ln := (15.0 + 7.0 * rand([i, 9]) if i % 2 == 0 else 7.0 + 4.0 * rand([i, 8])) * rk
				if ln < 1.0:
					continue
				var sh := 0.75 + 0.25 * sin(t * 7.0 + i * 2.1)
				var x0 := cx + ca * r0
				var y0 := cy + sa_ * r0
				pline(x0, y0, x0 + ca * ln, y0 + sa_ * ln, [C[7], C[6], C[5]], {"t": [0.3, 0.6], "al": [0.55, 1.3 * sh, 0.0, 1.3 * sh / 0.45, -1.3 * sh / 0.45]})
		bands.call(true)
		# column()
		var a := t - REL
		var on := a >= 0.0 and t <= GONE
		fk(col, "material:shader_parameter/on", on)
		if on:
			var top := -TOPH * out_expo(clampf(a / 0.12, 0.0, 1.0))
			var bot := -TOPH * in_cubic(seg(t, RET, GONE))
			var Wd := width_at(t)
			var k := 1.0 - smooth(RET, GONE, t)
			pglow_line(0, top, 0, minf(bot, -34.0), Wd * 1.6 + 6.0, C[5], 0.2 * k + 0.06)
			pglow_line(0, top, 0, minf(bot, -40.0), 5, W, 0.18 * k)
			fk(col, "material:shader_parameter/hot", a < 0.04)
			fk(col, "material:shader_parameter/t", t)
			fk(col, "material:shader_parameter/age", a)
			fk(col, "material:shader_parameter/top", top)
			fk(col, "material:shader_parameter/bot", bot)
			fk(col, "material:shader_parameter/W", Wd)
			fk(col, "material:shader_parameter/held", t < RET)
			var wrow := PackedFloat32Array()
			var nrow := PackedFloat32Array()
			var wcell := PackedFloat32Array()
			wcell.resize(200)
			for yy in range(-100, 0):
				var y := float(yy)
				var wr := Wd * (1.0 - 0.3 * (-y / TOPH)) + 0.9 * noise2(y * 0.2, t * 12.0, 3)
				wrow.append(wr)
				for side in 2:
					var s := -1.0 if side == 0 else 1.0
					var xw := s * wr
					wcell[side * 100 + yy + 100] = float(int(floorf(xw) + 64.0) | (int(floorf(xw + s) + 64.0) << 7) | (int(floorf(xw - s) + 64.0) << 14))
				nrow.append(float((1 if noise2(y * 0.3, t * 14.0, 5) > -0.2 else 0) | (2 if noise2(y * 0.25, t * 9.0, 8) > 0.25 else 0)
					| (4 if fract(y * 0.06 + t * 3.4) < 0.78 else 0) | (8 if fract(y * 0.06 + t * 3.4 + 0.5) < 0.78 else 0)))
			fk(col, "material:shader_parameter/wrow", wrow)
			fk(col, "material:shader_parameter/nrow", nrow)
			fk(col, "material:shader_parameter/wcell", wcell)
			var soff := PackedFloat32Array()
			for j in 9:
				soff.append(fract((t * sa[j].y) / sa[j].z + sb[j].x))
			fk(col, "material:shader_parameter/soff", soff)
		# plate()
		lay = "back2"
		var pk := 0.55 * seg(t, 0.05, REL) if t < REL else 1.0 - smooth(RET - 0.1, GONE + 0.2, t)
		if pk > 0.02:
			var rx := 9.0 + 9.0 * pk + sin(t * 9.0)
			_put(_e(Q_PLATE, 0, 0, 1.0, [C[6], C[5], C[4]], [rx, 2.2, pk], ceilf(rx) + 1.0))
			pglow(0, -1, rx * 2.2, C[4], 0.35 * pk)
		sim_draw(ps, "back", "soft")
		draw_rush.call(true)
		# draw
		lay = "front1"
		bands.call(false)
		var lit := smooth(REL - 0.02, REL + 0.04, t) * (1.0 - smooth(RET, 2.5, t))
		var tk := 0.0 if t < REL else (1.0 if t < REL + 0.06 else exp(-(t - REL - 0.06) / 0.07))
		if tk > 0.12:
			var cut := 0.0 if tk > 0.6 else (0.22 if tk > 0.3 else 0.5)
			for j in AH:
				for i in AW:
					if not has.call(i, j):
						continue
					var l := luma(aimg.get_pixel(i, j))
					if l < cut:
						continue
					pdot(AX + i, AY + j, (W if tk > 0.8 else C[6]) if l > 0.5 else (C[5] if l > 0.22 else C[4]))
		var lk := 0.1 * seg(t, 0.05, REL) * (1.0 - lit) + 0.06 * lit
		var rim := 0.6 * lit
		lay = "rim"
		fk(body_light, "material:shader_parameter/k", lk)
		if rim > 0.01:
			for j in AH:
				for i in AW:
					if not has.call(i, j):
						continue
					if rim <= 0.01 or not has.call(i - 1, j) or not has.call(i + 1, j) or not has.call(i, j - 1):
						continue
					if has.call(i - 2, j) and has.call(i + 2, j) and has.call(i, j - 2):
						continue
					var f := rim * (0.75 + 0.35 * noise(j * 0.6 - t * 8.0, i * 3))
					if f > 0.25:
						pdot(AX + i, AY + j, mixc(aimg.get_pixel(i, j), C[5], minf(0.85, f)))
		lay = "front2"
		var hk := 0.85 * lit * (1.0 - smooth(RET, GONE + 0.3, t)) + 0.3 * lit
		if hk > 0.02:
			for my in range(-1, AH + 1):
				for mx in range(-1, AW + 1):
					if not has.call(mx, my) and (has.call(mx - 1, my) or has.call(mx + 1, my) or has.call(mx, my - 1) or has.call(mx, my + 1)):
						pdot(AX + mx, AY + my, C[5], hk * (0.75 + 0.45 * noise(my * 0.45 - t * 7.0, mx * 3)))
		if t < REL:
			var k := seg(t, 0.05, REL)
			var beat := 1.0 + 0.4 * exp(-pow(t - REL * 0.6, 2.0) / 0.001)
			psparkle(0, -2, (1.0 + 4.0 * k * k) * beat, C[6], C[5], 0.3 + 0.4 * k)
		elif t < REL + 0.22:
			var aa := (t - REL) / 0.22
			pflare(0, -4, 28.0 * pow(1.0 - aa, 1.5), 1.0 - aa, ramp)
			pglow(0, -16, 48, W, 0.3 * (1.0 - aa))
		sim_draw(ps, "front")
		draw_rush.call(false)
		# the title
		var items := []
		var done := (t - LANDED) / 0.12
		for L in lets:
			if not L.on:
				items.append(null)
				continue
			var sx := 2.0
			var sy := 2.0
			var flash: float = L.flash
			if not L.landed and L.v > 150.0:
				sx = 1.8
				sy = 2.3
			if L.sq > 0.0:
				sx = 2.0 * (1.0 + 0.22 * L.sq)
				sy = 2.0 * (1.0 - 0.22 * L.sq)
			var pu: float = (t - L.pop) / 0.07
			var hop := seg(t, L.pop - 0.1, L.pop)
			if pu >= 1.0:
				items.append(null)
				continue
			if hop > 0.0 and pu <= 0.0:
				sx = 2.0 * (1.0 - 0.1 * hop)
				sy = 2.0 * (1.0 + 0.15 * hop)
			if pu > 0.0:
				sx = 2.0 * (1.0 + 0.3 * pu)
				sy = sx
				flash = 1.0
			flash = maxf(flash, 1.0 - done if (done > 0.0 and done < 1.0) else 0.0)
			var hh := 7.0 * sy
			var ww: float = L.w * sx
			items.append({"x": L.cx - ww / 2.0, "y": BASE + L.off - hh - 3.0 * out_quad(hop), "sx": sx, "sy": sy, "a": clampf((t - L.born) / 0.05, 0.0, 1.0), "flash": flash})
		var shs := seg(t, SHINE, SHINE + 0.34)
		var shine: Variant = X0 - 14.0 + (right - X0 + 30.0) * in_out_sine(shs) if (shs > 0.0 and shs < 1.0) else null
		word_at(wt, items, shine, TY)
		if shine != null and shine > X0 and shine < right:
			pglow_line(shine, TY, shine + 8.4, BASE, 9, C[6], 0.3)
		var hold := smooth(0.9, 1.2, t) * (1.0 - smooth(EXIT, EXIT + 0.4, t))
		if hold > 0.0:
			pglow(0, TY + 7.0, 50, C[5], 0.22 * hold + (0.3 * (1.0 - done) if (done > 0.0 and done < 1.0) else 0.0))
		lay = "top"
		for L in lets:
			var u: float = (t - L.pop - 0.07) / 0.16
			if u > 0.0 and u < 1.0:
				psparkle(L.cx, BASE - 7.0, 6.0 * (1.0 - u) * (1.0 - u), C[6], C[5], 0.5)
		var g := (t - SHINE - 0.3) / 0.26
		if g > 0.0 and g < 1.0:
			psparkle(right - 2.0, TY + 1.0, 7.0 * sin(g * PI), C[6], C[5], 0.6)
		for s in sats:
			var u: float = (t - s.t0) / s.dur
			if u > 0.0 and u < 1.0:
				psparkle(s.x, s.y, s.L * pow(sin(u * PI), 0.7), C[6], C[5], 0.5)
		lights_draw(lights)

	run(upd, drw)
	utable("RaysRings", "back1", {"parent": gback1, "back": true})
	utable("PlateBack", "back2", {"parent": gback2, "back": true})
	utable("Smoke", "soft", {"parent": gback2, "back": true, "soft": true})
	utable("RingsFront", "front1", {"parent": gf1})
	utable("Rim", "rim", {"parent": grim, "raw": true})
	utable("Front", "front2", {"parent": gf2})
	utable("Sparkles", "top", {"parent": gtop})
	light_table()
	flush_keys()
