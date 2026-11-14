# reimagined-from: src/fx/shadow/life-steal.js@939c1776e763ff4e387fc325d9529a042e027650
# Life steal: A target on the right is struck and bleeds red orbs; they hang a moment, then whip home as comet streaks and flood the caster crimson.
# one-shot, 2.20 s, 184x100 canvas, origin [36.0, 92.0], backdrop ground, stand-in 2
# ramp palette: #14040a #3a0a14 #6a101c #a01824 #d42a30 #ff5a50 #ff9a8a #ffe6de
# The orbs' flight is replayed in the build script with the original's physics (burst out, hover, whip home) and keyed
# on a group per orb: a ringed head, a light, and a comet tail from an emitter riding it whose particles stay where
# they were shed and cool down the ramp. The caster's flush is a shader over the stand-in's own pixels
# (_life-steal_flush.gdshader: its colours pushed toward blood-red, a hot outline) keyed from the replayed flush.
# The hit: a glint, a ring, sparks, blood drops that fall to the floor, a wound bloom; sparks and embers at the heart
# as the orbs land; lights on the hit and on each landing.
extends "res://build/fx/shadow/_shadow.gd"

const TX := 104.0
const TY := -24.0
const HX := 1.0
const HY := -20.0
const N := 7
const HZ := 60.0


func make() -> void:
	ground()
	var white := Color.WHITE
	keep_colour(white)
	var T := Vector2(TX, TY)
	var H := Vector2(HX, HY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	# ---- replay the orbs (120 Hz, as the original steps)
	var orbs := []
	for i in N:
		var a := -PI / 2 + (i - (N - 1) / 2.0) * 0.4 + rng.randf_range(-0.12, 0.12)
		var sp := rng.randf_range(100, 170)
		orbs.append({"p": T, "v": Vector2(cos(a) * sp + 10, sin(a) * sp), "home": 0.36 + i * 0.05 + rng.randf_range(0, 0.04),
			"size": rng.randf_range(1.6, 2.4), "done": -1.0, "keys": [[0.0, T]], "trail": [], "lines": []})
	var flush := 0.0
	var flush_keys := []
	var dt := 1.0 / 120.0
	var steps := int(root.duration * 120)
	for k in range(1, steps + 1):
		var t := k * dt
		for b in orbs:
			if b.done >= 0.0:
				continue
			var v: Vector2 = b.v
			var pos: Vector2 = b.p
			if t < b.home:
				v -= v * 5 * dt
			else:
				var d := H - pos
				var pull := 2600 * minf(1.0, (t - b.home) * 3)
				v += d.normalized() * pull * dt
				v -= v * 2.2 * dt
				if d.length() < 6:
					b.done = t
					flush = minf(1.5, flush + 0.45)
			pos += v * dt
			b.v = v
			b.p = pos
			b.trail.push_front(pos)
			if b.trail.size() > 26:
				b.trail.pop_back()
			if k % 2 == 0 or b.done >= 0.0:
				b.keys.append([t, pos])
		if k % 4 == 0:
			# the frame's comet tails (30 fps): swallowed after the head, they shorten
			for b in orbs:
				var n: int = b.trail.size()
				if b.done >= 0.0:
					n = int(floor(n * (1 - (t - b.done) / 0.2)))
				var pts := PackedVector2Array()
				for q in maxi(0, n):
					pts.append(b.trail[q])
				if pts.size() < 2:
					pts = PackedVector2Array([Vector2(0, 9999), Vector2(1, 9999)])
				b.lines.append([t, pts])
		flush -= flush * 2.6 * dt
		if k % 2 == 0:
			flush_keys.append([t, minf(1.0, flush) * (1 - smooth(1.5, 2.05, t))])

	# ---- behind: the wound's bloom on the target
	var wound := ring("Wound", 26, {"radius": 6, "color": C[2], "alpha": 0.5, "translucent": true}, {"at": T, "back": true})
	keyf(wound, "material:shader_parameter/radius", func(t: float): return 6 + t * 10, 0.0, 0.9, HZ)
	keyf(wound, "material:shader_parameter/alpha", func(t: float): return 0.5 * (1 - smooth(0.1, 0.9, t)), 0.0, 0.92, HZ)
	var wglow := glow("WoundGlow", 31, {"radius": 30, "color": C[4], "alpha": 0.35}, {"at": T})
	keyf(wglow, "material:shader_parameter/alpha", func(t: float): return 0.35 * (1 - smooth(0.1, 0.9, t)), 0.0, 0.92, HZ)

	# ---- the caster's flush
	var tex: Texture2D = load(EFFECT.STAND_INS[2])
	var sz := Vector2(tex.get_width() + 4, tex.get_height() + 4)
	var at := Vector2(0, -tex.get_height() / 2.0)
	var wash := shape("Flush", shadow_shader("life-steal_flush"), sz, {"tex": tex, "mode": 0.0, "fk": 0.0, "translucent": true,
		"c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6]}, {"at": at})
	key(wash, "material:shader_parameter/fk", flush_keys)
	var outline := shape("FlushOutline", shadow_shader("life-steal_flush"), sz, {"tex": tex, "mode": 1.0, "edge": C[3]}, {"at": at})
	var vis := []
	var edge := []
	for fkk in flush_keys:
		vis.append([fkk[0], fkk[1] > 0.12])
		edge.append([fkk[0], C[6] if fkk[1] > 0.6 else C[5] if fkk[1] > 0.3 else C[3]])
	outline.visible = false
	key(outline, "visible", vis, "nearest")
	key(outline, "material:shader_parameter/edge", edge, "nearest")
	var fglow := glow("FlushGlow", 29, {"radius": 28, "color": C[5], "alpha": 0.0}, {"at": H})
	key(fglow, "material:shader_parameter/alpha", flush_keys.map(func(q: Array): return [q[0], 0.45 * q[1]]))

	# ---- the hit on the target
	var glint := shape("Glint", shadow_shader("hex-sigil_sparkle"), Vector2(23, 23), {"arm": 10.0, "c": C[7], "tip": C[5], "heart": white}, {"at": T + Vector2(0.5, 0.5)})
	keyf(glint, "material:shader_parameter/arm", func(t: float): return 10 * (1 - t / 0.12), 0.0, 0.12, HZ)
	show(glint, 0.0, 0.12)
	var hr := ring("HitRing", 21, {"radius": 4, "thickness": 2, "color": C[7]}, {"at": T})
	keyf(hr, "material:shader_parameter/radius", func(t: float): return 4 + 16 * out_cubic(t / 0.28), 0.0, 0.28, HZ)
	keyf(hr, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 2 * (1 - t / 0.28)), 0.0, 0.28, HZ)
	key(hr, "material:shader_parameter/color", [[0.0, C[7]], [0.28 * 0.4, C[5]]], "nearest")
	show(hr, 0.0, 0.28)
	var drops := particles("Drops", {"at": T, "amount": 14, "lifetime": 0.9, "one_shot": true, "explosiveness": 1.0, "texture": "dot1",
		"emit": {"box": Vector2(3, 3)}, "dir": -72, "spread": 40, "speed": [40, 150], "gravity": Vector2(0, 760), "drag": 0.4,
		"scale": [1, 2], "initial": gradient([C[3], C[3], C[6]]), "collide": {"hide": true}})
	var spark_ramp := gradient([white, white, C[7], C[6]], [0.0, 0.2, 0.4, 0.7])
	var hit_sparks := particles("HitSparks", {"at": T, "amount": 12, "lifetime": 0.35, "life_random": 0.55, "one_shot": true, "explosiveness": 1.0,
		"texture": "streak4", "align": true, "spread": 180, "speed": [80, 170], "gravity": Vector2(0, 427), "drag": 2.2, "ramp": spark_ramp,
		"collide": {"bounce": 0.45, "friction": 0.3}})
	twin(hit_sparks, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})

	# ---- the orbs: comet tails, ringed heads
	var tail := gradient([C[7], C[6], C[5], C[4], C[2]], [0.0, 0.15, 0.35, 0.6, 0.8])
	var first := 99.0
	var last := 0.0
	var i := 0
	for b in orbs:
		var done: float = b.done if b.done >= 0.0 else root.duration
		first = minf(first, done)
		last = maxf(last, done)
		var g := group("Orb%d" % i, {"at": T})
		key(g, "position", b.keys)
		var ln := line("Trail%d" % i, PackedVector2Array([Vector2(0, 9999), Vector2(1, 9999)]), {"width": 1.0})
		ln.gradient = tail.gradient
		key(ln, "points", b.lines, "nearest")
		var tl := particles("Tail", {"parent": g, "amount": 40, "lifetime": 0.055, "texture": "disc3",
			"color": C[5], "scale_curve": [[0, 0.4 + b.size * 0.5], [1, 0.3]]})
		emit(tl, 0.0, done)
		var tg := particles("TailGlow", {"parent": g, "layer": "light", "amount": 5, "lifetime": 0.21, "texture": "glow16",
			"color": Color(C[5], 0.2), "alpha_curve": [[0, 1], [1, 0]]})
		emit(tg, 0.0, done)
		var rimr := ring("Rim", 4, {"radius": b.size + 0.9, "color": C[4]}, {"parent": g})
		var body := ring("Body", 4, {"radius": b.size, "color": C[6]}, {"parent": g})
		var sz2: float = b.size
		var home: float = b.home
		keyf(body, "material:shader_parameter/radius", func(t: float): return sz2 * (0.8 + 0.2 * sin(t * 30 + sz2 * 9)) if t < home else sz2, 0.0, home + 0.02, HZ)
		var heart := rect("Heart", Rect2(-1, -1, 1, 1), white, {"parent": g})
		var og := glow("Light", 10, {"radius": 9, "color": C[5], "alpha": 0.5}, {"parent": g})
		for n in [rimr, body, heart, og]:
			show(n, 0.0, done)
		# the landing: a light at the heart
		if b.done >= 0.0:
			var ll := glow("Land%d" % i, 31, {"radius": 30, "color": C[5], "alpha": 0.0}, {"at": H})
			keyf(ll, "material:shader_parameter/radius", func(t: float): return 30 * (0.6 + 0.4 * (1 - seg(t, done, done + 0.25))), done, done + 0.25, HZ)
			keyf(ll, "material:shader_parameter/alpha", func(t: float): return 0.8 * pow(1 - seg(t, done, done + 0.25), 2) if t >= done else 0.0, done - 1 / HZ, done + 0.27, HZ)
		i += 1

	# ---- sparks and embers at the heart as they land
	var land_sparks := particles("LandSparks", {"at": H, "amount": 16, "lifetime": 0.3, "life_random": 0.5, "texture": "streak3", "align": true,
		"spread": 180, "speed": [40, 100], "gravity": Vector2(0, 427), "drag": 2.2, "ramp": spark_ramp, "emitting": false})
	emit(land_sparks, first, last + 0.03)
	twin(land_sparks, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	var embers := particles("LandEmbers", {"at": H + Vector2(0, 4), "amount": 12, "lifetime": 0.95, "life_random": 0.4, "texture": "dot1",
		"emit": {"box": Vector2(8, 10)}, "dir": -90, "spread": 20, "speed": [15, 35], "gravity": Vector2(0, -30), "drag": 1.6,
		"ramp": gradient([C[6], C[6], Color(C[6], 0.0)], [0.0, 0.8, 1.0]), "emitting": false})
	emit(embers, first, last + 0.05)
	twin(embers, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})

	# ---- light on the hit
	for l in [["HitLight", 54.0, C[5], 0.35], ["HitFlare", 18.0, white, 0.08]]:
		var lg := glow(l[0], l[1] + 1, {"radius": l[1], "color": l[2], "alpha": 1.0}, {"at": T})
		var life: float = l[3]
		var r0: float = l[1]
		keyf(lg, "material:shader_parameter/radius", func(t: float): return r0 * (0.6 + 0.4 * (1 - t / life)), 0.0, life, HZ)
		keyf(lg, "material:shader_parameter/alpha", func(t: float): return pow(1 - seg(t, 0, life), 2), 0.0, life + 0.02, HZ)
