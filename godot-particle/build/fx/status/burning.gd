# reimagined-from: src/fx/status/burning.js@d28f251c8bfae13cd11d1179c849cdbf6f0d7d69
# Burning: burning over time: small flames lick from four hot spots, trailing sparks and thin smoke; every 0.6 s they
# flare, the body flashes white then orange, scorch marks spread.
# loop, 1.20 s, 72x80 canvas, origin [36, 70], backdrop ground, stand-in 2
# The stand-in is the effect's own Actor (shaders/actor.gdshader), flashed white for a frame on each tick, then washed
# orange. The four hot spots are the original's, found on its outline the way it finds them (and its own generator
# for the tongues and the scorches). On each spot the original's flame tongues (fx/status/_burning_tongues.gdshader:
# nested layers rippling with its looping noise, flaring on the tick); scorch marks spread over the clothes from each
# tick and cool (_burning_scorch.gdshader); emitters for the embers streaming off (with light twins), the burst of
# sparks thrown on every tick and the thin smoke drifting off behind; glows on the spots and the floor.
extends "res://build/fx/status/_status.gd"

const TICK := 0.6
const WIND := -14.0
var D := 1.2


func since(t: float) -> float:
	return fposmod(t, TICK)


func flare(t: float) -> float:
	return exp(-since(t) / 0.12)


func make() -> void:
	D = root.duration
	var P: PackedColorArray = root.ramps.palette
	var F := PackedColorArray()   # bright to dark, as the original's fit(palette, 9).reverse()
	for i in 9:
		F.append(P[8 - i])
	var CH := fit("char", 3)
	var seed_: int = int(meta.options.seed)
	var S := shape_of()
	var H := AH
	var W := AW
	var times := frame_times()

	# ---- the hot spots (burning.js spots()): the hair tips, a shoulder, the back, a sleeve
	var R := Rng.new(seed_ * 13 + 5)
	var at_row := func(q: float, sd: int) -> Vector2i:
		var my := int(jround(H * q))
		return Vector2i(S.rows[my][0] if sd < 0 else S.rows[my][1], my)
	var hair: Vector2i = Vector2i(-1, 1 << 20)
	for q in S.up:
		if q.x < W * 0.42 and (q.y < hair.y or (q.y == hair.y and q.x < hair.x)):
			hair = q
	var shoulder = null
	for q in S.up:
		if q.x > W / 2.0 and q.y > H * 0.4 and q.y < H * 0.62 and (shoulder == null or q.y < shoulder.y):
			shoulder = q
	if shoulder == null:
		shoulder = at_row.call(0.5, 1)
	var defs := [[hair, -1, 3, 4.5], [shoulder, 1, 2, 4.0], [at_row.call(0.62, -1), -1, 2, 3.5], [at_row.call(0.6, 1), 1, 2, 3.5]]
	var spots := []
	for i in defs.size():
		var d: Array = defs[i]
		var p := Vector2(AX + d[0].x + 0.5, AY + d[0].y + 1.5)
		var tongues := []
		for j in int(d[2]):
			var dx: float = (j - (d[2] - 1) / 2.0) * 1.6 + R.range(-0.4, 0.4)
			var hh: float = d[3] * R.range(0.8, 1.2)
			tongues.append(Vector3(dx, hh, i * 17 + j * 5 + seed_))
		spots.append({"p": p, "tongues": tongues})
	var scorch := []
	for tick in 2:
		for k in 2:
			var sp: Dictionary = spots[(tick * 2 + k + 1) % spots.size()]
			var cand := []
			for q in S.body:
				var l := luma(col_at(q.x, q.y))
				if Vector2(AX + q.x + 0.5, AY + q.y + 0.5).distance_to(sp.p) < 9.0 and q.y > H * 0.42 and l > 0.3 and l < 0.6:
					cand.append(q)
			if cand.is_empty():
				for q in S.body:
					if q.y > H * 0.45:
						cand.append(q)
			var c: Vector2i = cand[int(floorf(R.next() * cand.size()))]
			scorch.append({"p": Vector2(AX + c.x + 0.5, AY + c.y + 0.5), "r": R.range(3.2, 4.4), "tick": tick})

	# ---- behind: warm flicker on the floor, thin smoke drifting up and away
	var floor_glow := glow("FloorLight", 28, {"radius": 26.0, "squash": 4.5 / 26.0, "color": F[3].lerp(F[4], 0.5), "alpha": 0.2},
		{"at": Vector2(0, 0.5)})
	var smoke_c := Color(meta.options.smoke).lerp(F[6], 0.2)
	var pts := PackedVector2Array()
	for sp in spots:
		pts.append(sp.p + Vector2(0, -3))
	var smoke := particles("Smoke", {"layer": "soft", "back": true, "amount": 14, "lifetime": 1.2, "life_random": 0.33, "texture": "disc5",
		"emit": {"points": pts}, "dir": -115, "spread": 8, "speed": [18, 22], "drag": 0.9, "gravity": Vector2(WIND * 0.5, -6),
		"ramp": gradient([smoke_c, smoke_c.lerp(Color("#5d5660"), 0.5), Color("#433d48")], [0.0, 0.4, 0.75]),
		"scale_curve": [[0, 0.45], [0.4, 0.75], [1, 0.95]], "alpha_curve": [[0, 0.0], [0.08, 0.5], [0.6, 0.4], [1, 0.0]],
		"turbulence": {"strength": 1.0, "scale": 3.0, "influence": [0.01, 0.02]}})

	# ---- the body: white for the tick's first frame, then washed orange, fading
	var body := actor_node()
	var K := {"fl": [], "fc": [], "fg": []}
	for t in times:
		var ph := since(t)
		if ph < 0.034:
			K.fl.append([t, 1.0])
			K.fc.append([t, WHITE])
		elif ph < 0.22:
			K.fl.append([t, 0.55 * (1.0 - (ph - 0.034) / 0.186)])
			K.fc.append([t, F[4]])
		else:
			K.fl.append([t, 0.0])
			K.fc.append([t, F[4]])
		var flick := 0.8 + 0.2 * _tnoise(t, 7.5, 3)
		K.fg.append([t, (0.16 + 0.22 * flare(t)) * flick])
	key(body, "material:shader_parameter/flash", K.fl, "nearest")
	key(body, "material:shader_parameter/flash_color", K.fc, "nearest")
	key(floor_glow, "material:shader_parameter/alpha", K.fg, "nearest")
	keep_colour(WHITE)

	# ---- scorch marks spreading over the clothes from each tick
	var i := 0
	for sc in scorch:
		var node := shape("Scorch%d" % i, load(STATUS + "_burning_scorch.gdshader"), Vector2(W, H),
			{"top_left": Vector2(AX, AY), "mask": _tex_of_actor(), "spot": sc.p, "c3": F[3], "c4": F[4], "ch0": CH[0], "ch1": CH[1]},
			{"at": Vector2(AX + W / 2.0, AY + H / 2.0)})
		var sg := glow("ScorchLight%d" % i, 8, {"radius": 6.0, "color": F[4], "alpha": 0.0}, {"at": sc.p})
		var kr := []
		var kf := []
		var kq := []
		var kg := []
		for t in times:
			var on_tick: bool = int(floorf(t / TICK + 1e-6)) % 2 == sc.tick
			var ph := since(t)
			var grow := clamp01(ph / 0.14)
			var fade := (1.0 - clamp01((ph - 0.25) / 0.33)) if on_tick else 0.0
			kr.append([t, sc.r * (0.4 + 0.6 * grow)])
			kf.append([t, fade])
			kq.append([t, floorf(t * 20.0 + 1e-6)])
			kg.append([t, 0.3 * fade])
		key(node, "material:shader_parameter/radius", kr, "nearest")
		key(node, "material:shader_parameter/fade", kf, "nearest")
		key(node, "material:shader_parameter/f20", kq, "nearest")
		key(sg, "material:shader_parameter/alpha", kg, "nearest")
		i += 1

	# ---- the tongues on each spot, and their light
	i = 0
	for sp in spots:
		var tg: Array = sp.tongues
		var arr := PackedVector3Array(tg)
		while arr.size() < 3:
			arr.append(Vector3.ZERO)
		var tl := Vector2(floorf(sp.p.x) - 12, floorf(sp.p.y) - 26)
		var fl_node := shape("Flames%d" % i, load(STATUS + "_burning_tongues.gdshader"), Vector2(24, 28),
			{"top_left": tl, "spot": sp.p, "tg": arr, "count": tg.size(), "c0": F[0], "c2": F[2], "c4": F[4], "c6": F[6]},
			{"at": tl + Vector2(12, 14)})
		fl_node.material.set_shader_parameter("tg", arr)
		loop_t(fl_node)
		var g := glow("SpotLight%d" % i, 16, {"radius": 9.0, "color": F[4], "alpha": 0.22}, {"at": sp.p + Vector2(0, -2)})
		sample(g, "material:shader_parameter/radius", func(t: float) -> float: return 9.0 + 6.0 * flare(t))
		sample(g, "material:shader_parameter/alpha", func(t: float) -> float: return 0.22 + 0.35 * flare(t))
		i += 1

	# ---- embers streaming up and away
	var spark_pts := PackedVector2Array()
	for sp in spots:
		spark_pts.append(sp.p + Vector2(0, -2))
	var embers := particles("Embers", {"amount": 14, "lifetime": 0.9, "life_random": 0.45, "texture": "dot1",
		"emit": {"points": spark_pts}, "dir": -112, "spread": 14, "speed": [30, 58], "drag": 1.3,
		"gravity": Vector2(WIND * 0.6, -18), "ramp": gradient([F[1], F[3], F[1], F[3], F[5]], [0.0, 0.15, 0.3, 0.45, 0.78]),
		"alpha_curve": [[0, 1], [0.78, 1], [0.8, 0], [0.86, 1], [0.9, 0], [0.95, 1], [1, 0]]})
	twin(embers, {"modulate": Color(F[3], 0.3), "texture": "glow8"})

	# ---- every tick throws a burst of sparks off every spot
	for tick in 2:
		var burst := particles("Burst%d" % tick, {"amount": 16, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0, "texture": "dot1",
			"emit": {"points": spark_pts}, "dir": -90, "spread": 63, "speed": [50, 100], "drag": 3.0, "gravity": Vector2(0, 120),
			"ramp": gradient([F[1], F[3]], [0.0, 0.4]), "preprocess": 0.0})
		twin(burst, {"modulate": Color(F[3], 0.4), "texture": "glow8"})
		emit(burst, tick * TICK + 0.001)


func _tnoise(t: float, f: float, s: int) -> float:
	var P := maxi(2, int(jround(f * D)))
	var x := t / D * P
	var i := int(floorf(x))
	var fr := x - i
	var u := fr * fr * (3.0 - 2.0 * fr)
	var a := jrand([posmod(i, P), s])
	var b := jrand([posmod(i + 1, P), s])
	return (a + (b - a) * u) * 2.0 - 1.0


var _actor_tex: Texture2D


func _tex_of_actor() -> Texture2D:
	if _actor_tex == null:
		_actor_tex = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	return _actor_tex
