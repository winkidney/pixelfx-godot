# reimagined-from: src/fx/ui/heart-lost.js@dc4ffa2c6ab6c786823cdddf7d4d83752cd66dd3
# Heart lost: A HUD heart is hit: it flashes white and jolts, a crack runs down it, it splits into two halves that tumble away, leaving an empty socket that fades.
# one-shot, 1.50 s, 96x88 canvas, origin [48.0, 34.0], backdrop dark
# ramp palette: #1a0508 #4a0b12 #8c1420 #d42a2e #ff5a4a #ff9a86 #ffd8cc #ffffff
# The heart, its halves and the socket are one canvas shader (fx/ui/_heart_lost.gdshader: the original's mask, shading
# and crack) keyed every frame from the original's shake, tremble and the halves' tumble, replayed at its 120 Hz
# steps. Sparks, shards, red dust, stars and embers are frame-table particles from the original's own simulation
# (_ui.gd); the ring and the beat's glint too; the lights are a light table.
extends "res://build/fx/ui/_ui.gd"

const HIT := 0.14
const CRACK := 0.24
const SPLIT := 0.5
const MASK := [
	"....xxxx...xxxx....",
	"..xxxxxxx.xxxxxxx..",
	".xxxxxxxxxxxxxxxxx.",
	"xxxxxxxxxxxxxxxxxxx",
	"xxxxxxxxxxxxxxxxxxx",
	"xxxxxxxxxxxxxxxxxxx",
	"xxxxxxxxxxxxxxxxxxx",
	".xxxxxxxxxxxxxxxxx.",
	"..xxxxxxxxxxxxxxx..",
	"...xxxxxxxxxxxxx...",
	"....xxxxxxxxxxx....",
	".....xxxxxxxxx.....",
	"......xxxxxxx......",
	".......xxxxx.......",
	"........xxx........",
	".........x.........",
]
const CRACK_X := [9, 9, 10, 9, 8, 8, 9, 10, 10, 9, 8, 9, 9, 10, 9, 9]
const OX := -9.5
const OY := -8.0


func make() -> void:
	var W := Color.WHITE
	var seed_: int = int(meta.options.seed)
	var R := JsRng.new(seed_)
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]])
	var bits := bits_new()
	var lights := lights_new()
	var halves := []
	for s in [-1.0, 1.0]:
		var h := {"s": s, "x": s * 4.5, "y": 0.0}
		h.vx = s * R.range(55, 70)
		h.vy = -R.range(60, 80)
		h.a = 0.0
		h.va = s * R.range(2.2, 3.2)
		halves.append(h)
	var st := {"hit": false, "split": false, "gone": false}
	var end: float = D - 0.05
	var img := Image.create(19, 16, false, Image.FORMAT_R8)
	for j in 16:
		for i in 19:
			if MASK[j][i] == "x":
				img.set_pixel(i, j, Color(1, 0, 0))
	var cx := PackedFloat32Array()
	for v in CRACK_X:
		cx.append(float(v))
	var heart := shape("Heart", ush("heart_lost"), canvas_rect().size, {"C": C, "S": [Color("#0d0a14"), Color("#2a2338"), Color("#3c3350")],
		"mask": asset("_mask", img), "crack_x": cx}, {"at": canvas_rect().get_center()})
	var front := group("Front")
	var gbits := group("Shards")
	var gsoft := group("Dust")
	var gps := group("Particles")

	var upd := func(dt: float) -> void:
		var t := T
		if not st.hit and t >= HIT:
			st.hit = true
			lights_add(lights, 0, 0, 40, C[5], 0.6, 0.3)
			for i in 8:
				var an := R.range(0, TAU)
				var sp := R.range(80, 170)
				spawn(ps, SPARK, cos(an) * 9, sin(an) * 7, cos(an) * sp, sin(an) * sp - 30, R.range(0.1, 0.22))
		if not st.split and t >= SPLIT:
			st.split = true
			lights_add(lights, 0, 0, 44, W, 0.6, 0.12)
			lights_add(lights, 0, 0, 50, C[5], 0.5, 0.4)
			for i in 12:
				var j := R.int_(1, 14)
				var an := -PI / 2.0 + R.range(-1.4, 1.4)
				var sp := R.range(40, 100)
				var o := {"kind": 0, "x": CRACK_X[j] + OX, "y": j + OY, "vx": cos(an) * sp, "vy": sin(an) * sp, "g": 0.5, "drag": 1.0}
				o.life = R.range(0.35, 0.55)
				o.a = R.range(0, TAU)
				o.va = R.range(-20, 20)
				o.s = R.range(1.5, 3)
				o.c = R.pick([C[6], C[5], C[4], C[3]])
				bits_add(bits, o)
			for i in 5:
				spawn(ps, DUST, R.range(-2, 2), R.range(-6, 6), R.range(-25, 25), R.range(-20, 5), R.range(0.35, 0.6), C[2], R.range(2, 3.5))
			for i in 6:
				var an := R.range(0, TAU)
				var sp := R.range(30, 70)
				spawn(ps, STAR, cos(an) * 4, sin(an) * 4, cos(an) * sp, sin(an) * sp, R.range(0.25, 0.45), R.pick([C[7], C[6]]), 0.6 if i % 2 else 1.4)
		if st.split and not st.gone and t >= 0.95:
			st.gone = true
			for h in halves:
				for i in 5:
					var an := R.range(0, TAU)
					var sp := R.range(20, 50)
					spawn(ps, STAR, h.x + cos(an) * 4, h.y + sin(an) * 4, cos(an) * sp, sin(an) * sp - 10, minf(R.range(0.2, 0.35), end - t), R.pick([C[7], C[6], C[5]]), 0.6 if i else 1.3)
		if st.split:
			for h in halves:
				h.vy += 520.0 * dt
				h.vx -= h.vx * 0.6 * dt
				h.x += h.vx * dt
				h.y += h.vy * dt
				h.a += h.va * dt
				if t < 0.92 and R.chance(0.05):
					spawn(ps, EMBER, h.x, h.y, R.range(-10, 10), R.range(-10, 5), minf(R.range(0.3, 0.5), end - t), C[4], 1)
		bits_update(bits, dt)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var jj := shake(t, 3, HIT, 0.25, seed_)
		var tremble := jround(sin(t * 90.0)) if (t > CRACK and t < SPLIT) else 0.0
		fk(heart, "material:shader_parameter/sk", seg(t, SPLIT - 0.05, SPLIT + 0.1) * (1.0 - seg(t, 1.15, 1.4)))
		var pa := PackedVector4Array([Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)])
		var pb := PackedVector4Array([Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)])
		lay = "front"
		if t < SPLIT:
			var beat := 1.0 + 0.08 * maxf(0.0, sin(t * 22.0)) if t < HIT else 1.0
			var white := t >= HIT and t < HIT + 0.07
			pa[0] = Vector4(0, jj[0] + tremble, jj[1], 0)
			pb[0] = Vector4(1.0 if white else 0.0, seg(t, CRACK, SPLIT - 0.06), 1, 1)
			pglow(0, 0, 18 * beat, C[4], 0.3 + (0.5 if white else 0.0))
			if t < HIT:
				psparkle(-6, -5, 2.5 * maxf(0.0, sin(t * 22.0)), C[7], C[6], 0.3)
		else:
			var fade := 1.0 - seg(t, 0.9, 1.0)
			var white := t < SPLIT + 0.05
			if fade > 0.0:
				for k in 2:
					var h: Dictionary = halves[k]
					pa[k] = Vector4(h.s, h.x, h.y, h.a)
					pb[k] = Vector4(1.0 if white else 0.0, 0, fade, 1)
			var rk := (t - SPLIT) / 0.3
			if rk < 1.0:
				pring(0, 0, 8.0 + 16.0 * out_cubic(rk), maxf(1.0, 2.0 * (1.0 - rk)), W if rk < 0.3 else C[5], 1.2 - rk)
		fk(heart, "material:shader_parameter/pa", pa)
		fk(heart, "material:shader_parameter/pb", pb)
		lay = "bits"
		bits_draw(bits)
		lay = "ps"
		sim_draw(ps, "", "soft")
		lights_draw(lights)

	run(upd, drw)
	utable("Front", "front", {"parent": front})
	utable("Shards", "bits", {"parent": gbits})
	utable("Dust", "soft", {"parent": gsoft, "soft": true})
	utable("Particles", "ps", {"parent": gps})
	light_table()
	flush_keys()
