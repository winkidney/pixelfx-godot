# reimagined-from: src/fx/spawn/soul-rise.js@9521e7525defda730f201405173d38754923cd41
# Soul rise: The body's outline flares and dims, then a pale glowing copy of it lifts out, stretching as its legs melt into a rippling wisp, shedding motes until it thins into light.
# one-shot, 3.20 s, 96x140 canvas, origin [48.0, 126.0], backdrop ground, stand-in 2
# ramp palette: #101a33 #1f3563 #35609e #5c96d4 #94c8f0 #d2f0ff #ffffff
# The original's own update() runs here with its seeded draws. Over the stand-in its outline flares and its body is
# left dimmed (fx/spawn/_soul.gdshader mode 0); the soul is the body's own picture in pale light, lifted, stretched,
# swaying, its legs melting into a wisp and thinning away as the original draws it (mode 1), with its light keyed on
# the original's formulas. The motes and stars it sheds are the original's Particles, tracked (_parts); the ring as it
# tears loose, the impacts' band shader; its lights tracked (_lamps).
extends "res://build/fx/spawn/_spawn.gd"

const LEAVE := 0.35
const TOP := 2.05
const GONE := 2.55
const SHADOW := Color8(0x0c, 0x0f, 0x1e)

var height := 50.0
var Hh := 38.0
var body_y := -38.0


func lift(t: float) -> float:
	return height * in_out_sine(clamp01((t - LEAVE) / (TOP - LEAVE)))


static func stretch(t: float) -> float:
	return 1 + 0.22 * in_out_sine(clamp01((t - LEAVE) / (TOP - LEAVE)))


static func sway(t: float, row: float) -> float:
	return sin(t * 3 - row * 0.12) * 2.2 * smooth(LEAVE, LEAVE + 0.5, t)


static func melt(t: float) -> float:
	return smooth(LEAVE + 0.1, LEAVE + 0.9, t)


static func thin(t: float) -> float:
	return smooth(TOP - 0.25, GONE, t)


static func luma(c: Color) -> float:
	return (0.299 * c.r8 + 0.587 * c.g8 + 0.114 * c.b8) / 255.0


func make() -> void:
	var Wc := Color.WHITE
	height = float(meta.options.height)
	R = JsRng.new(int(meta.options.seed))
	var body := body_of(C)
	var rim := rim_of(body)
	var W: int = body.w
	Hh = body.h
	body_y = body.y
	var waist := floori(Hh * 0.6 + 0.5)
	var tone := Image.create(W, int(Hh), false, Image.FORMAT_RGBAF)
	for b in body.list:
		tone.set_pixel(b.mx, b.my, Color(6 if b.edge else 3 + mini(2, floori(luma(b.c) * 3.6)), 0, 0, 1))
	var ps := new_parts()
	ps.ground = 0.0
	ps.single = true
	var lm := new_lamps()
	var st := {"t": 0.0, "left": false}
	var dur: float = root.duration

	var step := func(dt: float) -> void:
		st.t += dt
		var t: float = st.t
		if not st.left and t >= LEAVE:
			st.left = true
			lm.add(0, -20, 50, C[4], 0.85, 0.55)
			lm.add(0, -20, 24, Wc, 0.8, 0.12)
			for i in 10:
				var c: Dictionary = R.pick(rim)
				var vx := R.range(-20, 20)
				var vy := -R.range(20, 60)
				var life := R.range(0.4, 0.8)
				var col: Color = R.pick([Wc, C[5]])
				var sz := R.range(0.8, 1.8)
				ps.spawn(STAR, c.x, c.y, vx, vy, life, col, sz)
		# motes come off its edges as it rises, and pour off it as it thins
		if t > LEAVE and t < GONE:
			var s := stretch(t)
			var y0 := body_y * s - lift(t)
			var th := thin(t)
			for n in (3 if th > 0 else 1):
				if not R.chance(0.9 if th > 0 else 0.5):
					continue
				var c: Dictionary = R.pick(rim)
				var row: float = c.my
				if row / Hh < 1 - th * 1.1 - 0.05 and th > 0:
					continue
				var x: float = c.x * (1 - 0.12 * (s - 1) * 4) + sway(t, row)
				var y: float = y0 + c.my * s
				var life := minf(minf(R.range(0.5, 1.1), dur - 0.1 - t), (y + 120) / 60)
				if life > 0.1:
					var k := MOTE if R.chance(0.7) else STAR
					var vx := R.range(-12, 12)
					var vy := -R.range(25, 60)
					var col: Color = R.pick([Wc, C[5], C[5], C[4]])
					var sz := R.range(0.5, 1)
					ps.spawn(k, x, y, vx, vy, life, col, sz)
		ps.update(dt)
		lm.step(dt)
	var rec := func(s: int) -> void:
		ps.record(s)
		lm.record(s)
	run(step, rec)
	var u := "material:shader_parameter/"
	var pal := []
	for i in 7:
		pal.append(C[i])

	# behind: a pale pool on the floor while it leaves, the ring's far half
	var pool := glow_path("Pool", Vector2(0, -1), Vector2(0, -1), 26, C[4])
	keyf(pool, u + "k", func(t: float) -> float: return 0.3 * smooth(0, LEAVE, jt(t)) * (1 - smooth(LEAVE + 0.4, TOP, jt(t))))
	ring_half("RingBack", 1.0, true)
	# over the stand-in: its outline flaring, then its body dimmed
	var tex_tone := asset("_tone", tone)
	var ov := shape("Body", ssh("soul"), Vector2(W + 2, Hh + 2), {"mode": 0, "tone": tex_tone, "origin": Vector2(body.x, body_y), "shadow": SHADOW,
		"pal": pal, "white": Wc, "translucent": true}, {"at": Vector2(0, body_y + Hh / 2.0)})
	keyf(ov, u + "t", func(t: float) -> float: return jt(t), 0.0, LEAVE + 0.34, 60.0, "nearest")
	keyf(ov, u + "flare", func(t: float) -> float:
		var tt := jt(t)
		return (tt / LEAVE if tt < LEAVE else 1 - (tt - LEAVE) / 0.3) if tt < LEAVE + 0.3 else -1.0, 0.0, LEAVE + 0.34, 60.0, "nearest")
	keyf(ov, u + "dim", func(t: float) -> float: return smooth(LEAVE, LEAVE + 0.6, jt(t)) * (1 - smooth(GONE, dur - 0.1, jt(t))), 0.0, -1.0, 60.0, "nearest")
	var fg := glow_path("FlareLight", Vector2(0, -19), Vector2(0, -19), 26, C[4])
	keyf(fg, u + "k", func(t: float) -> float:
		var tt := jt(t)
		return 0.45 * (tt / LEAVE if tt < LEAVE else 1 - (tt - LEAVE) / 0.3) if tt < LEAVE + 0.3 else 0.0, 0.0, LEAVE + 0.4)
	ring_half("RingFront", -1.0, false)
	# the soul and its light
	var top_most := body_y * 1.22 - height - 2
	var sh := Vector2(64, ceilf(-top_most) + 16)
	var soul := shape("Soul", ssh("soul"), sh, {"mode": 1, "tone": tex_tone, "origin": Vector2(body.x, body_y), "waist": float(waist), "leave_t": LEAVE,
		"pal": pal, "white": Wc, "translucent": true}, {"at": Vector2(0, floorf(top_most) + sh.y / 2.0)})
	var on := func(t: float) -> bool: return jt(t) >= LEAVE and jt(t) <= GONE + 0.1
	keyf(soul, "visible", on, 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "s", func(t: float) -> float: return stretch(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "lift", func(t: float) -> float: return lift(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "melt", func(t: float) -> float: return melt(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "thin", func(t: float) -> float: return thin(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "fade_in", func(t: float) -> float: return clamp01((jt(t) - LEAVE) / 0.15), 0.0, -1.0, 60.0, "nearest")
	keyf(soul, u + "sway_k", func(t: float) -> float: return smooth(LEAVE, LEAVE + 0.5, jt(t)), 0.0, -1.0, 60.0, "nearest")
	var cy := func(t: float) -> float: return body_y * stretch(jt(t)) - lift(jt(t)) + Hh * stretch(jt(t)) * 0.45
	for g in [["SoulLight", 0.0, 30.0, C[4], 0.42], ["SoulHot", 6.0, 14.0, C[5], 0.3]]:
		var gl := glow_path(g[0], Vector2(-3, top_most), Vector2(3, 0), g[2], g[3])
		var up: float = g[1]
		var kk: float = g[4]
		keyf(gl, u + "a", func(t: float) -> Vector2: return Vector2(sway(jt(t), 10), cy.call(t) - up), 0.0, -1.0, 60.0, "nearest")
		keyf(gl, u + "b", func(t: float) -> Vector2: return Vector2(sway(jt(t), 10), cy.call(t) - up), 0.0, -1.0, 60.0, "nearest")
		keyf(gl, u + "k", func(t: float) -> float: return kk * clamp01((jt(t) - LEAVE) / 0.15) * (1 - thin(jt(t))) if on.call(t) else 0.0, 0.0, -1.0, 60.0, "nearest")
	# the motes and stars, the lights
	parts("Parts", ps, {"sparks": [Wc, C[5], C[4], C[3]], "front": true})
	lamps("Lights", lm)


## The ring of light across the floor as it tears loose (band(): 6 -> 32 px over 0.5 s): side 1 the far half
## (behind), -1 the near half.
func ring_half(name: String, side: float, back: bool) -> void:
	var b := shape(name, sh("band"), Vector2(72, 16), {"mid": Vector2(0, 0), "radius": 6.0, "th": 3.0, "squash": 0.18, "side": side,
		"c0": C[3], "c1": C[4], "c2": C[5], "c3": C[6], "alpha": 0.0}, {"at": Vector2(0, 0), "back": back})
	var kk := func(t: float) -> float: return (jt(t) - LEAVE) / 0.5
	var u := "material:shader_parameter/"
	keyf(b, u + "radius", func(t: float) -> float: return 6.0 + 26.0 * out_cubic(clamp01(kk.call(t))), LEAVE - 0.04, LEAVE + 0.54)
	keyf(b, u + "th", func(t: float) -> float: return maxf(1.0, 3.0 * (1.0 - kk.call(t))), LEAVE - 0.04, LEAVE + 0.54)
	keyf(b, u + "alpha", func(t: float) -> float: return (1.15 - kk.call(t)) if (kk.call(t) > 0.0 and kk.call(t) < 1.0) else 0.0, 0.0, LEAVE + 0.54, 60.0, "nearest")
	keyf(b, u + "c3", func(t: float) -> Color: return Color.WHITE if kk.call(t) < 0.12 else C[6], LEAVE - 0.04, LEAVE + 0.54, 60.0, "nearest")
