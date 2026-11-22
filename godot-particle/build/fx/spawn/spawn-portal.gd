# reimagined-from: src/fx/spawn/spawn-portal.js@c7130998e522af99d0b88316dfd4d742e9c3177a
# Spawn portal: A rift tears open on the floor and swirls, belches violet smoke and sparks, spits a fountain of wisps up out of itself, then twists shut with a pop.
# one-shot, 3.80 s, 208x150 canvas, origin [104.0, 122.0], backdrop ground
# ramp palette: #12081f #2a0f4d #481b8c #7330d0 #a35cff #cf9bff #f1dcff #ffffff
# The original's own update() runs here with its seeded draws. The rift is drawn as the original draws it
# (fx/spawn/_rift.gdshader: a void with its lit far wall, three arms of light spiralling in, a ragged white-hot lip,
# far half behind and near half in front, all on the original's noise), with its light. The motes swirling round it
# on the floor are tracked particles (_dot), as are the wisps it spits (_wisp: comets with fading tails), the rocks
# (_shards: the original's Bits) and its smoke, sparks, streaks, motes, dust and stars (_parts: the original's
# Particles). The slit it tears from (_hline), the burst's column of light (_column), the flare and the pop's glint,
# the shock rings (the impacts' band shader) and the glows are keyed on its formulas; its lights tracked (_lamps).
extends "res://build/fx/spawn/_spawn.gd"

const OPEN := 0.3
const BELCH := [0.52, 0.76]
const BURST := 1.0
const SHUT := 1.9
const POP := 2.22
const SY := 0.34
const VOID := Color8(0x06, 0x03, 0x0b)
const FUME := Color8(0x3a, 0x30, 0x46)
const STONE := ["#1a1424", "#2b2639", "#4a4263", "#6c6488", "#9a91b4"]
const DUSTC := Color8(0x5a, 0x50, 0x70)

var RX := 28.0


func radius(t: float) -> float:
	if t < OPEN:
		return RX * out_back(clamp01(t / OPEN), 2.2)
	if t < SHUT:
		return RX * (1 + 0.035 * sin(t * 9) + 0.1 * exp(-pow(t - BURST - 0.05, 2) / 0.006))
	var k := clamp01((t - SHUT) / (POP - SHUT))
	return RX * (1 + 0.1 * sin((k / 0.35) * PI * 0.5) if k < 0.35 else 1.1 * (1 - pow((k - 0.35) / 0.65, 1.6)))


static func spin_at(t: float) -> float:
	return t * 2.4 + 1.5 * smooth(BURST - 0.1, BURST + 0.3, t) + 10 * pow(clamp01((t - SHUT) / (POP - SHUT)), 2.2)


static func heat_at(t: float) -> float:
	return 0.85 + 0.15 * sin(t * 7) + 0.6 * exp(-pow(t - BURST, 2) / 0.01)


func make() -> void:
	var W := Color.WHITE
	RX = float(meta.options.width)
	R = JsRng.new(int(meta.options.seed))
	var SM := [mixc(C[4], FUME, 0.4), mixc(C[3], FUME, 0.3), mixc(C[5], FUME, 0.55)]
	var ps := new_parts()
	ps.ground = 0.0
	var rocks := new_bits()
	rocks.ground = 0.0
	var lm := new_lamps()
	var swirl := []
	var wisps := []
	var rings := []
	var done := {}
	var st := {"t": 0.0}
	var once := func(k: String, at: float) -> bool:
		if not done.get(k, false) and st.t >= at:
			done[k] = true
			return true
		return false
	var add_swirl := func(r0: float) -> void:
		var a := R.range(0, TAU)
		var w := R.range(2.2, 4)
		var inw := R.range(0.3, 0.7)
		var c: Color = R.pick([W, C[6], C[6], C[5]])
		swirl.append({"i": swirl.size(), "a": a, "r": r0, "w": w, "in": inw, "c": c, "on": true})
	var pull := func() -> void:
		var a := R.range(PI * 1.03, PI * 1.97)
		var D := R.range(40, 86)
		var T := R.range(0.24, 0.42)
		var x := cos(a) * D * 1.08
		var y := sin(a) * D * 0.85
		var l := Vector2(x, y).length()
		var v := (0.6 * l) / (1 - exp(-0.6 * T))
		var c: Color = R.pick([W, C[6], C[5], C[5], C[4]])
		var sz := R.range(1, 1.7)
		ps.spawn(MOTE, x, y, (-x / l) * v, (-y / l) * v, T, c, sz)
	var puff := func(n: int, big: bool, sp: float) -> void:
		for i in n:
			var a := R.range(0, TAU)
			var d := R.range(0, 0.55) * RX
			var vx := R.range(-1, 1) * sp * 0.6
			var vy := -R.range(0.4, 1) * sp
			var life := R.range(1.2, 2.2) * (1.15 if big else 0.8)
			var c: Color = R.pick(SM)
			var sz := R.range(2.8, 4.6) * (1.15 if big else 0.9)
			var dl := R.range(0, 0.3) if big else R.range(0, 0.1)
			ps.spawn(SMOKE, cos(a) * d, sin(a) * d * SY - 2, vx, vy, life, c, sz, dl, BIG if big else 0)
	var sparks := func(n: int, up: float, spread: float) -> void:
		for i in n:
			var a := -PI / 2 + R.range(-spread, spread)
			var sp := R.range(0.5, 1) * up
			var x := R.range(-0.5, 0.5) * RX
			var life := R.range(0.35, 0.8)
			ps.spawn(SPARK, x, -1, cos(a) * sp, sin(a) * sp, life)

	var step := func(dt: float) -> void:
		st.t += dt
		var t: float = st.t
		var shutting := t > SHUT and t < POP
		if (t < OPEN + 0.15 or shutting) and R.chance(0.55):
			var s := R.sign()
			var D := R.range(RX * 1.3, RX * 2.4)
			var T := R.range(0.18, 0.3)
			var v := (D * 3) / (exp(3 * T) - 1)
			var y := -R.range(0, 3)
			var vy := R.range(-2, 2)
			var c: Color = C[6] if R.chance(0.5) else C[5]
			ps.spawn(STREAK, s * D, y, -s * v, vy, T, c)
		if t > 0.1 and t < POP - 0.1 and R.chance(0.85 if shutting else (0.55 if t < BURST else 0.1)):
			pull.call()
		if t < POP and t > 0.12 and R.chance(0.5 if shutting else 0.25):
			add_swirl.call(R.range(1.1, 1.5))
		if once.call("open", OPEN * 0.7):
			lm.add(0, -8, 50, C[4], 0.75, 0.45)
			rings.append({"t0": t, "life": 0.42, "r0": RX * 0.8, "r1": RX * 1.9, "th": 2.5, "hot": true})
			for i in 8:
				var x := R.sign() * R.range(0.7, 1.1) * RX
				var vx := R.sign() * R.range(10, 45)
				var vy := -R.range(4, 14)
				var life := R.range(0.4, 0.7)
				var sz := R.range(1.5, 3)
				ps.spawn(DUST, x, -1, vx, vy, life, DUSTC, sz)
		if once.call("b0", BELCH[0]):
			puff.call(6, false, 34)
			sparks.call(8, 210, 0.55)
			lm.add(0, -6, 44, C[4], 0.6, 0.3)
		if once.call("b1", BELCH[1]):
			puff.call(8, false, 40)
			sparks.call(12, 240, 0.6)
			lm.add(0, -6, 48, C[4], 0.65, 0.3)
		if once.call("burst", BURST):
			lm.add(0, -26, 74, C[4], 1, 0.75)
			lm.add(0, -10, 40, W, 0.85, 0.14)
			rings.append({"t0": t, "life": 0.55, "r0": RX * 1.0, "r1": RX * 2.5, "th": 3.5, "hot": true})
			rings.append({"t0": t + 0.06, "life": 0.45, "r0": RX * 0.8, "r1": RX * 1.8, "th": 2.0, "hot": false})
			puff.call(18, true, 70)
			sparks.call(34, 400, 0.8)
			for i in 5:
				var a := -PI / 2 + (i - 2) * 0.27 + R.range(-0.08, 0.08)
				var sp := R.range(185, 235)
				var x := R.range(-4, 4)
				var life := R.range(0.75, 1.0)
				var ph := R.range(0, TAU)
				wisps.append({"i": wisps.size(), "x": x, "y": -2.0, "vx": cos(a) * sp, "vy": sin(a) * sp, "life": life, "max": 1.0, "tr": [], "acc": 0.0, "ph": ph, "on": true})
			for i in 12:
				var x := R.sign() * R.range(0.75, 1.05) * RX
				var vx := R.range(-100, 100)
				var vy := -R.range(150, 280)
				var life := R.range(1.3, 1.9)
				var an := R.range(0, TAU)
				var va := R.range(-14, 14)
				var s := R.range(1, 2.4)
				rocks.add({"kind": 1, "x": x, "y": -1.0, "vx": vx, "vy": vy, "g": 1.0, "drag": 0.4, "bounce": 0.3, "life": life, "a": an, "va": va, "s": s})
			for i in 14:
				var x := R.range(-0.8, 0.8) * RX
				var y := -R.range(4, 34)
				var vx := R.range(-30, 30)
				var vy := -R.range(10, 60)
				var life := R.range(0.5, 1.1)
				var c: Color = R.pick([W, C[6], C[5]])
				var sz := R.range(0.8, 2)
				ps.spawn(STAR, x, y, vx, vy, life, c, sz)
		# while it's open it keeps venting thin smoke and the odd spark
		if t > OPEN and t < SHUT and R.chance(0.16):
			puff.call(1, false, 22)
		if t > OPEN and t < SHUT + 0.1 and R.chance(0.06):
			sparks.call(1, 160, 0.4)
		if once.call("pop", POP):
			lm.add(0, -4, 50, C[4], 0.95, 0.5)
			lm.add(0, -2, 28, W, 0.9, 0.12)
			rings.append({"t0": t, "life": 0.35, "r0": 2.0, "r1": RX * 1.9, "th": 2.5, "hot": true})
			for i in 18:
				var a := R.range(-PI, 0)
				var sp := R.range(90, 270)
				var life := R.range(0.25, 0.6)
				ps.spawn(SPARK, 0, -1, cos(a) * sp, sin(a) * sp * 0.8, life)
			for i in 9:
				var a := R.range(0, TAU)
				var sp := R.range(30, 95)
				var life := R.range(0.4, 0.9)
				var c: Color = R.pick([W, C[6]])
				var sz := R.range(0.8, 1.8)
				ps.spawn(STAR, 0, -2, cos(a) * sp, sin(a) * sp * 0.5 - 20, life, c, sz)
			for i in 6:
				var x := R.range(-6, 6)
				var y := -R.range(1, 4)
				var vx := R.range(-34, 34)
				var vy := -R.range(10, 30)
				var life := R.range(0.8, 1.3)
				var sz := R.range(2.5, 4.5)
				ps.spawn(SMOKE, x, y, vx, vy, life, SM[2], sz)
			for i in 14:
				var x := R.range(-1, 1) * RX * 0.9
				var y := -R.range(0.5, 2)
				var vx := R.range(-4, 4)
				var vy := -R.range(0, 4)
				var life := R.range(0.6, 1.4)
				var c: Color = R.pick([C[6], C[5], C[5]])
				var sz := R.range(0.4, 0.9)
				var dl := R.range(0, 0.25)
				ps.spawn(STAR, x, y, vx, vy, life, c, sz, dl)
		for i in range(swirl.size() - 1, -1, -1):
			var s: Dictionary = swirl[i]
			if not s.on:
				continue
			var k := 2.4 if shutting else 1.0
			s.a += s.w * k * dt * (1.4 / maxf(0.3, s.r))
			s.r -= s.in * k * dt
			if s.r < 0.25 or t > POP:
				s.on = false
		# the wisps: comets with smoky tails that arc up and out, then burst
		for i in range(wisps.size() - 1, -1, -1):
			var w: Dictionary = wisps[i]
			if not w.on:
				continue
			w.tr.push_front(Vector2(w.x, w.y))
			if w.tr.size() > 12:
				w.tr.pop_back()
			w.life -= dt
			if w.life <= 0 or (w.vy > 0 and w.y > -2):
				for j in 8:
					var a := R.range(0, TAU)
					var sp := R.range(30, 120)
					var life := R.range(0.2, 0.5)
					ps.spawn(SPARK, w.x, w.y, cos(a) * sp + w.vx * 0.2, sin(a) * sp + w.vy * 0.2, life)
				ps.spawn(STAR, w.x, w.y, 0, -6, 0.45, W, 2.4)
				lm.add(w.x, w.y, 24, C[5], 0.65, 0.25)
				w.on = false
				continue
			w.vy += 360 * dt
			w.vx += sin((w.max - w.life) * 16 + w.ph) * 160 * dt
			w.vx -= w.vx * 1.1 * dt
			w.vy -= w.vy * 1.1 * dt
			w.x += w.vx * dt
			w.y += w.vy * dt
			w.acc += dt
			while w.acc > 0.03:
				var life := R.range(0.6, 1)
				var sz := R.range(1.5, 2.4)
				ps.spawn(SMOKE, w.x, w.y, w.vx * 0.05, w.vy * 0.05 - 4, life, SM[0], sz)
				w.acc -= 0.03
			if R.chance(0.3):
				var vx: float = -w.vx * 0.2 + R.range(-15, 15)
				var vy: float = -w.vy * 0.2 + R.range(-15, 15)
				var life := R.range(0.2, 0.4)
				ps.spawn(MOTE, w.x, w.y, vx, vy, life, C[6], 0.6)
		rocks.step(dt)
		for b in rocks.list:
			if b.rest and not b.get("dusted", false):
				b.dusted = true
				for i in 2:
					var x: float = b.x + R.range(-1.5, 1.5)
					var vx := R.sign() * R.range(6, 30)
					var vy := -R.range(2, 12)
					var life := R.range(0.3, 0.6)
					var sz := R.range(1.2, 2.4)
					ps.spawn(DUST, x, -0.5, vx, vy, life, DUSTC, sz)
		ps.update(dt)
		lm.step(dt)

	var far := new_track(2, 30.0)
	var near := new_track(2, 30.0)
	var wt := new_track(8)
	var rec := func(s: int) -> void:
		var t: float = st.t
		var rx := radius(t)
		for sw in swirl:
			if not sw.on:
				continue
			for j in 3:
				var a: float = sw.a - j * 0.08 * (1.4 / maxf(0.3, sw.r))
				var x: float = cos(a) * sw.r * rx
				var y: float = sin(a) * sw.r * rx * SY
				var tr: Track = near if sin(a) >= 0 else far
				var ci := (0 if sw.c == W else 1 if sw.c == C[6] else 2) if j == 0 else 2
				tr.put(sw.i * 3 + j, s, 0, Color(x, y - 0.5, 1.0, 1.0 if j == 0 else 0.9 - j * 0.3))
				tr.put(sw.i * 3 + j, s, 1, Color(ci, 0.35 if j == 0 else 0.0, 0.5, 0))
		for w in wisps:
			if not w.on:
				continue
			wt.put(w.i, s, 0, Color(w.x, w.y, 1.0, w.life / w.max))
			var pts: Array = w.tr
			for r in 6:
				var a: Vector2 = pts[2 * r] - Vector2(w.x, w.y) if 2 * r < pts.size() else Vector2.ZERO
				var b: Vector2 = pts[2 * r + 1] - Vector2(w.x, w.y) if 2 * r + 1 < pts.size() else Vector2.ZERO
				wt.put(w.i, s, 1 + r, Color(a.x, a.y, b.x, b.y))
			wt.put(w.i, s, 7, Color(pts.size(), 0, 0, 0))
		rocks.record(s)
		ps.record(s)
		lm.record(s)
	run(step, rec)
	var u := "material:shader_parameter/"
	var pal := []
	for i in 8:
		pal.append(C[i])
	var rxk := func(t: float) -> float: return clamp01(radius(jt(t)) / RX)

	# behind: the floor's violet glow round the hole and the light welling up out of it, the slit it tears from
	var fg := glow_path("FloorLight", Vector2(0, -4), Vector2(0, -4), RX * 1.8 * 1.2 + 10, C[4])
	keyf(fg, u + "radius", func(t: float) -> float: return radius(jt(t)) * 1.8 + 10, 0.0, -1.0, 60.0, "nearest")
	keyf(fg, u + "k", func(t: float) -> float: return 0.32 * rxk.call(t) if jt(t) < POP else 0.0, 0.0, -1.0, 60.0, "nearest")
	var wl := glow_path("WellLight", Vector2(0, -44), Vector2(0, -2), RX * 0.7 * 1.2 + 6, C[4])
	keyf(wl, u + "radius", func(t: float) -> float: return radius(jt(t)) * 0.7 + 6, 0.0, -1.0, 60.0, "nearest")
	keyf(wl, u + "k", func(t: float) -> float: return 0.16 * rxk.call(t) if jt(t) < POP else 0.0, 0.0, -1.0, 60.0, "nearest")
	var slit_len := func(t: float) -> float: return RX * 1.1 * out_cubic(jt(t) / (OPEN * 0.6)) if jt(t) < OPEN * 0.6 else -1.0
	var sl := shape("Slit", ssh("hline"), Vector2(2 * ceilf(RX * 1.1 + 2), 3), {"len": 0.0, "split": 0.3, "mid": W, "ends": C[6]}, {"at": Vector2(0, 0.5), "back": true})
	keyf(sl, u + "len", slit_len, 0.0, OPEN * 0.6 + 0.04, 60.0, "nearest")
	var sll := glow_path("SlitLight", Vector2(-RX * 1.1, 0), Vector2(RX * 1.1, 0), 7, C[5])
	keyf(sll, u + "a", func(t: float) -> Vector2: return Vector2(-maxf(0.0, slit_len.call(t)), 0), 0.0, OPEN * 0.6 + 0.04, 60.0, "nearest")
	keyf(sll, u + "b", func(t: float) -> Vector2: return Vector2(maxf(0.0, slit_len.call(t)), 0), 0.0, OPEN * 0.6 + 0.04, 60.0, "nearest")
	keyf(sll, u + "k", func(t: float) -> float: return 0.6 if slit_len.call(t) >= 0 else 0.0, 0.0, OPEN * 0.6 + 0.04, 60.0, "nearest")
	# the rift: the hole and the lip's far half behind, the near half in front, and its light
	var rift_on := func(t: float) -> bool: return jt(t) > OPEN * 0.35 and jt(t) < POP
	var rifts := []
	var rsize := Vector2(2 * ceilf(RX * 1.15 + 4), 2 * ceilf(RX * 1.15 * SY + 4))
	rifts.append(shape("RiftBack", ssh("rift"), rsize, {"mode": 0, "sy": SY, "pal": pal, "void_c": VOID, "white": W}, {"back": true}))
	for r in rifts + [shape("RiftLight", ssh("rift_light"), rsize, {"mode": 0, "sy": SY, "pal": pal, "white": W})]:
		keyf(r, "visible", rift_on, 0.0, -1.0, 60.0, "nearest")
		keyf(r, u + "rx", func(t: float) -> float: return radius(jt(t)), 0.0, -1.0, 60.0, "nearest")
		keyf(r, u + "spin", func(t: float) -> float: return spin_at(jt(t)), 0.0, -1.0, 60.0, "nearest")
		keyf(r, u + "heat", func(t: float) -> float: return heat_at(jt(t)), 0.0, -1.0, 60.0, "nearest")
		keyf(r, u + "heat_hole", func(t: float) -> float: return heat_at(jt(t)) + 0.4 * smooth(SHUT, POP, jt(t)), 0.0, -1.0, 60.0, "nearest")
		keyf(r, u + "wind", func(t: float) -> float: return 2.3 + 2.6 * smooth(SHUT, POP - 0.05, jt(t)), 0.0, -1.0, 60.0, "nearest")
	for i in rings.size():
		ring_half("RingBack%d" % i, rings[i], 1.0, true)
	track("SwirlBack", far, ssh("dot"), 1, {"cols": [W, C[6], C[5], C[5], C[5], C[5], C[5], C[5]]}, {"back": true})
	track("SwirlBackLight", far, ssh("dot_light"), 9, {"color": C[5], "radius": 3.0}, {"layer": "light"})
	# in front: the lip's near half, the rings' near halves, the swirl in front of the hole
	var rf := shape("RiftFront", ssh("rift"), rsize, {"mode": 1, "sy": SY, "pal": pal, "void_c": VOID, "white": W})
	keyf(rf, "visible", rift_on, 0.0, -1.0, 60.0, "nearest")
	keyf(rf, u + "rx", func(t: float) -> float: return radius(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(rf, u + "spin", func(t: float) -> float: return spin_at(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(rf, u + "heat", func(t: float) -> float: return heat_at(jt(t)), 0.0, -1.0, 60.0, "nearest")
	for i in rings.size():
		ring_half("RingFront%d" % i, rings[i], -1.0, false)
	track("Swirl", near, ssh("dot"), 1, {"cols": [W, C[6], C[5], C[5], C[5], C[5], C[5], C[5]]})
	track("SwirlLight", near, ssh("dot_light"), 9, {"color": C[5], "radius": 3.0}, {"layer": "light"})
	# the burst: a column of light shooting up out of the hole, its light, a flare
	var bb := func(t: float) -> float: return jt(t) - BURST
	var col := shape("Column", ssh("column"), Vector2(2 * ceilf(RX * 0.55 + 3), 92), {"c5": C[5], "c6": C[6], "white": W}, {"at": Vector2(0, -44)})
	keyf(col, u + "w0", func(t: float) -> float: return RX * 0.55 * (1 - bb.call(t) / 0.45 * 0.8) if (bb.call(t) > 0 and bb.call(t) < 0.45) else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(col, u + "top", func(t: float) -> float: return -84 * out_expo(clamp01(bb.call(t) / 0.14)), 0.0, -1.0, 60.0, "nearest")
	keyf(col, u + "bot", func(t: float) -> float: return -1 - 60 * in_quad(clamp01(bb.call(t) / 0.45)), 0.0, -1.0, 60.0, "nearest")
	keyf(col, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	var cl := glow_path("ColumnLight", Vector2(0, -84), Vector2(0, -1), RX * 0.55 + 12, C[5])
	keyf(cl, u + "radius", func(t: float) -> float: return RX * 0.55 * (1 - clamp01(bb.call(t) / 0.45) * 0.8) + 12, 0.0, -1.0, 60.0, "nearest")
	keyf(cl, u + "a", func(t: float) -> Vector2: return Vector2(0, -1 - 60 * in_quad(clamp01(bb.call(t) / 0.45))), 0.0, -1.0, 60.0, "nearest")
	keyf(cl, u + "b", func(t: float) -> Vector2: return Vector2(0, -84 * out_expo(clamp01(bb.call(t) / 0.14))), 0.0, -1.0, 60.0, "nearest")
	keyf(cl, u + "k", func(t: float) -> float: return 0.55 * (1 - bb.call(t) / 0.45) if (bb.call(t) > 0 and bb.call(t) < 0.45) else 0.0, 0.0, -1.0, 60.0, "nearest")
	var fl := shape("Flare", load("res://addons/pixelfx_particles/fx/arcane/_flare.gdshader"), Vector2(77, 77),
		{"len": 0.0, "k": 1.0, "white": W, "c_hi": C[6], "c_lo": C[5]}, {"at": Vector2(0.5, -4 + 0.5)})
	keyf(fl, u + "len", func(t: float) -> float: return 36 * (1 - bb.call(t) / 0.14) if (bb.call(t) > 0 and bb.call(t) < 0.14) else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(fl, u + "k", func(t: float) -> float: return 1 - bb.call(t) / 0.14, BURST - 0.04, BURST + 0.2, 60.0, "nearest")
	# the collapse: a white point that pops
	var qq := func(t: float) -> float: return jt(t) - POP
	var arm := func(t: float) -> float:
		var q: float = qq.call(t)
		return float(floori((4.0 if q < 0 else 12.0) * (1 - clamp01(q / 0.25)) + 0.5)) if (q > -0.08 and q < 0.25) else 0.0
	var spk := shape("PopGlint", load("res://addons/pixelfx_particles/fx/arcane/_sparkle.gdshader"), Vector2(27, 27),
		{"arm": 0, "c": W, "tip": C[5], "heart": W}, {"at": Vector2(0.5, -1 + 0.5)})
	keyf(spk, u + "arm", arm, 0.0, -1.0, 60.0, "nearest")
	var sgl := glow_path("PopGlintLight", Vector2(0, -1), Vector2(0, -1), 29, W)
	keyf(sgl, u + "radius", func(t: float) -> float: return 4.0 + 2.0 * arm.call(t), 0.0, -1.0, 60.0, "nearest")
	keyf(sgl, u + "k", func(t: float) -> float: return 0.7 * (1 - clamp01(qq.call(t) / 0.25)) if arm.call(t) >= 1 else 0.0, 0.0, -1.0, 60.0, "nearest")
	# rocks, wisps, particles, lights
	bits("Rocks", rocks, STONE.map(func(h: String) -> Color: return Color(h)))
	track("Wisps", wt, ssh("wisp"), 61, {"c4": C[4], "c5": C[5], "c6": C[6], "white": W})
	var wlt := new_track(2)
	for k in wt.cells:
		if k.z == 0:
			var c: Color = wt.cells[k]
			wlt.put(k.x, k.y, 0, Color(c.r, c.g, 1.0, 0.5 * c.a + 0.2))
			wlt.put(k.x, k.y, 1, Color(12.0, 0, 0, 0))
	track("WispsLight", wlt, ssh("lamps"), 27, {"pal": [C[5], C[5], C[5], C[5], C[5], C[5], C[5], C[5]]}, {"layer": "light"})
	parts("Parts", ps, {"sparks": [C[7], C[6], C[5], C[3]]})
	lamps("Lights", lm)


## A shock ring on the floor plane (band()): side 1 its far half (behind), -1 its near half.
func ring_half(name: String, r: Dictionary, side: float, back: bool) -> void:
	var reach: float = r.r1 + 4
	var b := shape(name, sh("band"), Vector2(2 * ceilf(reach), 2 * ceilf(reach * SY * 0.62 + 3)), {"mid": Vector2(0, 0), "radius": 6.0, "th": 3.0,
		"squash": SY * 0.62, "side": side, "c0": C[4], "c1": C[5], "c2": C[6], "c3": C[7], "alpha": 0.0}, {"at": Vector2(0, 0), "back": back})
	var kk := func(t: float) -> float: return (jt(t) - r.t0) / r.life
	var u := "material:shader_parameter/"
	var t0: float = r.t0 - 0.04
	var t1: float = r.t0 + r.life + 0.04
	keyf(b, u + "radius", func(t: float) -> float: return r.r0 + (r.r1 - r.r0) * out_cubic(clamp01(kk.call(t))), t0, t1)
	keyf(b, u + "th", func(t: float) -> float: return maxf(1.0, r.th * (1.0 - kk.call(t))), t0, t1)
	keyf(b, u + "alpha", func(t: float) -> float: return (1.15 - kk.call(t)) if (kk.call(t) >= 0.0 and kk.call(t) < 1.0) else 0.0, 0.0, t1, 60.0, "nearest")
	keyf(b, u + "c3", func(t: float) -> Color: return Color.WHITE if (r.hot and kk.call(t) < 0.15) else C[7], t0, t1, 60.0, "nearest")
