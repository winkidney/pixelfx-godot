# reimagined-from: src/fx/ui/achievement.js@982a080f01c33b3ad2d543e779f6412e1caa87a1
# Achievement: A toast slides in on speed lines and settles; a gold medal pops onto it in a burst of sparkles, a shine sweeps the whole toast, then it slides away.
# one-shot, 2.40 s, 220x72 canvas, origin [110, 36], backdrop dark
# ramp palette: #2a1405 #5c3008 #9a5a0e #d48e18 #f5b92c #ffde5e #fff4bc #ffffff
# ramp ribbon: #0c1430 #1f3a7a #2f66c4 #5aa0f0 #a6d4ff
# The toast is a plate shader (fx/ui/_plate.gdshader, _lib.js panel), its words the drawWord shader (fx/ui/_word,
# the original's mini font, bevel, outline and the shine sweeping across), the medal its own shader (fx/ui/_medal:
# straps, rim, raised star), all keyed every frame from the original's slide, spring and shine. The speed lines, the
# gold edge, the stars bursting off the medal and its glint are frame-table particles replayed from the original's
# own update at its 120 Hz steps (_ui.gd); every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const PW := 130.0
const PH := 34.0
const PX := -PW / 2.0
const PY := -PH / 2.0
const IN := 0.2
const MEDAL := 0.26
const SHINE := 0.95
const OUT := 1.92
const MX := PX + 17.0
const MY := 2.0


func make() -> void:
	var W := Color.WHITE
	var G := C
	var B: PackedColorArray = root.ramps.ribbon
	var R := JsRng.new(int(meta.options.seed))
	var ps := sim_new(R, [G[7], G[6], G[5], G[3]])
	var lights := lights_new()
	var ink := [Color("#0d0a14"), Color("#5a4f74"), Color("#2a2338"), Color("#211b2d"), Color("#15111c")]
	var title := spell(String(meta.options.title), "mini")
	var sub := spell(String(meta.options.text), "mini")
	var TX := PX + 34.0
	var st := {"popped": false}
	var end: float = D - 0.05
	var x_at := func(t: float) -> float:
		if t < IN:
			return 30.0 * pow(1.0 - t / IN, 3.0)
		if t < OUT:
			return -3.0 * exp(-(t - IN) * 12.0) * sin((t - IN) * 30.0)
		if seg(t, OUT, OUT + 0.06) < 1.0:
			return -3.0 * seg(t, OUT, OUT + 0.06)
		return -3.0 + 33.0 * in_quad(seg(t, OUT + 0.06, OUT + 0.24))
	var cr := canvas_rect()
	var glines := group("SpeedLines")
	var plate := shape("Plate", ush("plate"), cr.size, {"ink": ink, "r": 4.0}, {"at": cr.get_center()})
	var gdeco := group("Edge")
	var tl := glyphs_of(title)
	var sl := glyphs_of(sub)
	var wt := word("Title", tl.map(func(L: Dictionary) -> Dictionary: return L.g), "mini",
		{"fill": [G[4], G[5], G[6]], "edge": G[7], "under": G[3], "outline": ink[0], "glint": G[7]})
	var ws := word("Text", sl.map(func(L: Dictionary) -> Dictionary: return L.g), "mini",
		{"fill": [Color("#9a94b0"), Color("#d8d4e6"), W], "edge": W, "under": Color("#6e6886"), "outline": ink[0], "glint": W})
	var medal := shape("Medal", ush("medal"), cr.size, {"G": G, "B": B, "py_top": PY}, {"at": cr.get_center()})
	var front := group("Front")

	var upd := func(dt: float) -> void:
		var t := T
		if not st.popped and t >= MEDAL + 0.06:
			st.popped = true
			lights_add(lights, MX, MY, 36, G[5], 0.7, 0.4)
			for i in 12:
				var an := (i / 12.0) * TAU + R.range(-0.2, 0.2)
				var sp := R.range(40, 90)
				spawn(ps, STAR, MX + cos(an) * 9, MY + sin(an) * 9, cos(an) * sp, sin(an) * sp * 0.6, R.range(0.25, 0.45), R.pick([G[7], G[6], G[5]]), 0.6 if i % 3 else R.range(1.2, 1.8))
		if t > 0.5 and t < OUT and R.chance(0.05):
			spawn(ps, STAR, MX + R.range(-11, 11), MY + R.range(-11, 9), 0, -R.range(4, 10), minf(R.range(0.3, 0.5), end - t), G[6], 1.4 if R.chance(0.3) else 0.6)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var x: float = x_at.call(t)
		var out := t > OUT + 0.06
		var a := 0.5 if t < 0.05 else (1.0 - seg(t, OUT + 0.12, OUT + 0.24) if out else 1.0)
		fk(plate, "material:shader_parameter/on", a > 0.0)
		fk(medal, "material:shader_parameter/on", false)
		if a <= 0.0:
			word_at(wt, [])
			word_at(ws, [])
			return
		var moving := t < IN * 0.8 or out
		lay = "lines"
		if moving:
			for i in 8:
				var fr := floorf(t * 30.0)
				var y := PY + 3.0 + rand([fr, i, 1]) * (PH - 6.0)
				var L := 10.0 + rand([fr, i, 2]) * 26.0
				var x0 := x + PW / 2.0 + 2.0 + rand([i, 3]) * 6.0
				pline(x0, y, minf(106.0, x0 + L), y, [W, G[6], G[4]], {"t": [0.3, 0.6], "al": [2.0, 1.1, -1.0, 1.1, -1.0], "a": a})
		var sh := seg(t, SHINE, SHINE + 0.36)
		var shine: Variant = PX - 12.0 + (PW + 30.0) * in_out_sine(sh) if (sh > 0.0 and sh < 1.0) else null
		fk(plate, "material:shader_parameter/rc", Vector4(PX + x, PY, PW, PH))
		fk(plate, "material:shader_parameter/a", a)
		fk(plate, "material:shader_parameter/has_shine", shine != null)
		fk(plate, "material:shader_parameter/shine", float(shine) + x if shine != null else 0.0)
		lay = "deco"
		pline(PX + x + 4.0, PY + 1.0, PX + x + PW - 5.0, PY + 1.0, G[4], {"a": a})
		pdot(PX + x + 3.0, PY + 1.0, G[2])
		var ti := []
		for L in tl:
			ti.append({"x": TX + x + L.x * 2.0, "y": PY + 5.0, "sx": 2.0, "sy": 2.0, "a": a})
		word_at(wt, ti, float(shine) + x if shine != null else null, PY)
		var si := []
		for L in sl:
			si.append({"x": TX + x + L.x * 2.0, "y": PY + 19.0, "sx": 2.0, "sy": 2.0, "a": a})
		word_at(ws, si, float(shine) + x if shine != null else null, PY)
		lay = "front"
		var mk := t - MEDAL
		if mk > 0.0:
			var s := 1.5 if mk < 0.035 else 1.0 + 0.35 * exp(-mk * 16.0) * cos(mk * 28.0)
			fk(medal, "material:shader_parameter/on", true)
			var lo := floorf(MX + x) - 8.0
			while absf(lo + 0.5 - (MX + x)) >= 4.5 * s:
				lo += 1.0
			var hi := lo
			while absf(hi + 1.5 - (MX + x)) < 4.5 * s:
				hi += 1.0
			fk(medal, "material:shader_parameter/inner", Vector2(lo, hi))
			var mx := MX + x
			var r0 := floorf(PY + 1.0)
			var rows := PackedVector4Array()
			for j in 16:
				var span := []
				for sd in [-1.0, 1.0]:
					var first := INF
					var last := -INF
					for cxi in range(int(floorf(mx - 12.0 * s)), int(ceilf(mx + 12.0 * s)) + 1):
						if _in_strap(cxi + 0.5, r0 + j + 0.5, mx, MY, s, sd):
							first = minf(first, cxi)
							last = maxf(last, cxi)
					span.append_array([first, last] if first < INF else [1.0, 0.0])
				rows.append(Vector4(span[0], span[1], span[2], span[3]))
			fk(medal, "material:shader_parameter/row0", r0)
			fk(medal, "material:shader_parameter/rows", rows)
			fk(medal, "material:shader_parameter/xx", Vector2(jround(MX + x), ((MX + x) - jround(MX + x)) * 1e6))
			fk(medal, "material:shader_parameter/y", MY)
			fk(medal, "material:shader_parameter/s", s)
			var ln := PackedVector4Array()
			for sd in [-1.0, 1.0]:
				for w in [[2.0, 4.0], [7.0, 9.0]]:
					ln.append(Vector4(floorf(MX + x + sd * w[0] * s), floorf(MY - 10.0 * s + 2.0), floorf(MX + x + sd * w[1] * s), floorf(PY + 1.0)))
			fk(medal, "material:shader_parameter/ln", ln)
			fk(medal, "material:shader_parameter/white", mk < 0.07)
			fk(medal, "material:shader_parameter/has_shine", shine != null)
			fk(medal, "material:shader_parameter/shine", float(shine) - MX + 4.0 if shine != null else 0.0)
			if shine != null:
				var smx := MX + x
				var sh_m: float = float(shine) - MX + 4.0
				var sr0 := floorf(MY - 10.0 * s - 1.0)
				var rows_ := PackedVector2Array()
				for j in 40:
					var dy := sr0 + j + 0.5 - MY
					var first := INF
					var last := -INF
					for cxi in range(int(floorf(smx - 20.0)), int(ceilf(smx + 20.0)) + 1):
						if absf((cxi + 0.5 - smx) - dy * 0.6 - sh_m) < 1.2:
							first = minf(first, cxi)
							last = maxf(last, cxi)
					rows_.append(Vector2(first, last) if first < INF else Vector2(1, 0))
				fk(medal, "material:shader_parameter/shine_row0", sr0)
				fk(medal, "material:shader_parameter/shine_rows", rows_)
			pglow(MX + x, MY, 20, G[5], 0.3 * a + (0.5 * (1.0 - mk / 0.15) if mk < 0.15 else 0.0))
			var g := fmod(t - 1.5, 0.9) / 0.9
			if t > 1.5 and g < 0.25:
				psparkle(MX + x - 4.0, MY - 4.0, 4.0 * sin((g / 0.25) * PI), G[7], G[6], 0.5)
		sim_draw(ps)
		lights_draw(lights)

	run(upd, drw)
	utable("SpeedLines", "lines", {"parent": glines})
	utable("Edge", "deco", {"parent": gdeco})
	utable("Front", "front", {"parent": front})
	light_table()
	flush_keys()


## The original's even-odd test of a strap's quad (achievement.js medal), in doubles.
static func _in_strap(px: float, py: float, x: float, y: float, s: float, sd: float) -> bool:
	var r := 10.0 * s
	var P := [[x + sd * 2.0 * s, y - r + 2.0], [x + sd * 7.0 * s, y - r + 2.0], [x + sd * 9.0 * s, PY + 1.0], [x + sd * 4.0 * s, PY + 1.0]]
	var inside := false
	var j := 3
	for i in 4:
		var xi: float = P[i][0]
		var yi: float = P[i][1]
		var xj: float = P[j][0]
		var yj: float = P[j][1]
		if (yi > py) != (yj > py) and px < ((xj - xi) * (py - yi)) / (yj - yi) + xi:
			inside = not inside
		j = i
	return inside
