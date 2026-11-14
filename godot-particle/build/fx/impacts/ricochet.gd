# reimagined-from: src/fx/impacts/ricochet.js@1bc4202629dcd6399dc32e914e423e7c68e4f90a
# Ricochet: A tracer streaks down onto the floor, glances off with a white-hot star and skips away at an angle,
# leaving a glowing skid while sparks skitter along the ground.
# The tracer is a shader of its own (fx/impacts/_tracer.gdshader: the original's dotted streak, white head to dim
# tail) whose head and length are keyed from the original's flight at 60 Hz, coming in and skipping away; the skid
# another (_skid) cooling on the original's curve; the glancing star the impacts' star shader on its two frames; a
# thin half ring of dots swelling off the floor. Sparks skittering along the floor, grit and a scuff of dust are GPU
# particles from the original's own draws on its physics (_sim.gdshader), spawned as the round lands.
extends "res://build/fx/impacts/_impacts.gd"

const HIT := 0.05
const SPEED := 760.0
const IN := 0.32
const OUT := -0.21


func make() -> void:
	var o: Dictionary = meta.options
	var st := stone(Color(o.stone))
	R = JsRng.new(int(o.seed))
	var D: float = meta.duration
	var W := Color.WHITE
	var sp := spikes(9, OUT, {"len": [6.0, 9.0], "w": [1.4, 1.9], "fwd": 2.6, "back": 0.6})
	for i in sp.size():
		if sin(sp[i].x) > 0.2:
			sp[i].y *= 0.3
		if absf(sin(sp[i].x - OUT)) > 0.6:
			sp[i].y *= 0.65
	# as it lands: sparks skitter on along the floor, grit and a scuff of dust
	for i in 18:
		var low := i < 12
		var a := OUT + (R.range(-0.22, 0.12) if low else R.range(-0.7, 0.25))
		var v := R.range(260, 520) * (1.0 if low else 0.7)
		var x0 := R.range(-1, 2)
		var life := R.range(0.15, 0.42) * (1.3 if low else 1.0)
		spawn(SPARK, x0, -1, cos(a) * v, sin(a) * v, life, W, 1, R.range(0, 0.05) if low else 0.0, 0, HIT)
	for i in 7:
		var a := -PI / 2 + R.range(-0.2, 0.9)
		var v := R.range(60, 170)
		var x0 := R.range(0, 4)
		var life := R.range(0.6, 0.95)
		spawn(GRIT, x0, -1, cos(a) * v, sin(a) * v, life, R.pick([st.light, st.body, st.lip]), 2 if i < 2 else 1, 0.0, 0, HIT)
	for i in 4:
		var x0 := R.range(0, 8)
		var vx := R.range(20, 70)
		var vy := -R.range(4, 16)
		var life := R.range(0.25, 0.45)
		var c := mixc(st.dust, W, R.range(0.1, 0.3))
		spawn(DUST, x0, -1, vx, vy, life, c, R.range(1.2, 2), 0.0, 0, HIT)
	var u := "material:shader_parameter/"

	# the skid: a gouge glowing where the round dragged, cooling
	var heat := func(t: float) -> float: return pow(clampf(1.0 - (t - HIT) / 0.85, 0.0, 1.0), 1.2)
	var skid := shape("Skid", sh("skid"), Vector2(20, 4), {"white": W, "c5": C[5], "c4": C[4], "c3": C[3], "c2": C[2], "soot": SOOT,
		"heat": 1.0, "len": 0.0, "fade": 1.0}, {"at": Vector2(5, 1), "back": true})
	keyf(skid, u + "heat", heat, HIT, D)
	keyf(skid, u + "len", func(t: float) -> float: return 12.0 * minf(1.0, (t - HIT) / 0.03), HIT, HIT + 0.04)
	keyf(skid, u + "fade", func(t: float) -> float: return 1.0 - smooth(D - 0.4, D - 0.05, t), 0.0, D)
	show(skid, HIT)
	var skid_light := glow_path("SkidLight", Vector2(-3, 0), Vector2(12, 0), 5, C[3], {"back": true})
	keyf(skid_light, u + "b", func(t: float) -> Vector2: return Vector2(12.0 * minf(1.0, maxf(0.0, t - HIT) / 0.03), 0.0), HIT, HIT + 0.04)
	keyf(skid_light, u + "k", func(t: float) -> float: return 0.45 * heat.call(t) if t >= HIT else 0.0, 0.0, D)

	flush({"sparks": [C[6], C[5], C[4], C[2]]})

	# the tracer: racing down to the floor, then skipping away with its tail stretching out
	var tr := shape("Tracer", sh("tracer"), Vector2(232, 84), {"angle": IN, "len": 22.0, "k": 1.0, "c0": W, "c1": C[5], "c2": C[4], "c3": C[2]},
		{"at": Vector2(116 - 64, 42 - 60)})
	var head := func(t: float) -> Vector2:
		if t < HIT:
			var d := (HIT - t) * SPEED
			return Vector2(-cos(IN) * d, -sin(IN) * d)
		var h := 4.0 + (t - HIT) * SPEED
		return Vector2(cos(OUT) * h, -1.0 + sin(OUT) * h)
	keyf(tr, u + "head", head, 0.0, HIT + 0.2)
	keyf(tr, u + "angle", func(t: float) -> float: return IN if t < HIT else OUT, 0.0, HIT + 0.2, 60.0, "nearest")
	keyf(tr, u + "len", func(t: float) -> float: return 22.0 if t < HIT else minf(4.0 + (t - HIT) * SPEED - 2.0, 18.0 + (t - HIT) * 200.0), 0.0, HIT + 0.2)
	keyf(tr, u + "k", func(t: float) -> float: return 1.0 if t < HIT else 1.0 - (t - HIT) / 0.2, 0.0, HIT + 0.2)
	show(tr, 0.0, HIT + 0.2)
	var tglow := glow("TracerGlow", 10, {"radius": 9, "color": C[4], "alpha": 0.6}, {"at": head.call(0.0).round()})
	keyf(tglow, "position", func(t: float) -> Vector2: return head.call(t).round(), 0.0, HIT + 0.2)
	keyf(tglow, u + "alpha", func(t: float) -> float: return 0.6 if t < HIT else 0.6 * (1.0 - (t - HIT) / 0.2), 0.0, HIT + 0.2)
	show(tglow, 0.0, HIT + 0.2)

	# glancing off: the stretched star on its two frames, a thin half ring hugging the floor
	hit_star("Star", Vector2(0, -1), sp, 2.0, [[HIT, 1.0, 1.0, 1.0, [C[2], C[5], C[4], W]], [HIT + 0.03, 1.25, 0.55, 1.0, [C[1], C[4], C[3], C[5]]], [HIT + 0.06]])
	var g0 := HIT + 0.02
	var ring := dot_ring("HalfRing", Vector2(0, -1), 18, {"radius": 5.0, "dir": -PI / 2, "open": -0.001, "color": C[5]})
	keyf(ring, u + "radius", func(t: float) -> float: return 5.0 + 12.0 * (1.0 - pow(1.0 - seg(t, g0, g0 + 0.2), 3.0)), g0, g0 + 0.2)
	keyf(ring, u + "alpha", func(t: float) -> float: return 1.15 - seg(t, g0, g0 + 0.2), g0, g0 + 0.2)
	var ring_col := func(t: float) -> Color:
		var g := seg(t, g0, g0 + 0.2)
		return C[5] if g < 0.3 else C[4] if g < 0.6 else C[3]
	keyf(ring, u + "color", ring_col, g0, g0 + 0.2, 60.0, "nearest")
	show(ring, g0, g0 + 0.2)

	var pop := func(k: float) -> Callable: return func(t: float) -> float: return k * exp(-(t - HIT) / 0.045) if (t >= HIT and exp(-(t - HIT) / 0.045) > 0.02) else 0.0
	glow_fn("Pop", Vector2(0, -2), 22, C[3], pop.call(0.75), 0.0, HIT + 0.2)
	glow_fn("PopWhite", Vector2(0, -1), 8, W, pop.call(0.5), 0.0, HIT + 0.2)
	light_add("Light", Vector2(0, -2), 44, C[4], 0.65, 0.25, HIT)
	light_add("LightWhite", Vector2(0, -1), 14, W, 0.6, 0.06, HIT)
