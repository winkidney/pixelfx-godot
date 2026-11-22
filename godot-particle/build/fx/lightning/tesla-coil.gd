# reimagined-from: src/fx/lightning/tesla-coil.js@0096de912155bb4faa52eb338a9abfa42b75fedd
# Tesla coil: A copper coil under a steel torus throws branching arcs that lash out in volleys and now and then strike the floor in a spray of sparks, lighting the metal and the ground.
# loop, 2.40 s, 224x136 canvas, origin [112.0, 120.0], backdrop ground
# The coil and torus are the original's still pixels (port/props.py); the arcs' light on them is glow. The loop's
# plan (volleys of arcs off the torus, two zaps to the floor) is drawn here with a fixed seed as the original draws
# its own: every arc is a layered bolt (fx/lightning/_volt.gd) lashing out from its root on the rim, re-struck every
# frame and flickering on the original's beat, behind the coil or in front of it; corona motes crawl over the torus
# and short streamers hiss off it; the zaps strike the floor with a flash, a scorch (fx/lightning/_scorch.gdshader),
# smoke and a spray of bouncing sparks; sparks spit off each arc's tip as it strikes.
extends "res://build/fx/lightning/_base.gd"

const N := 72
const P := 2.4
const TY := -57.0
const RR := 12.0
const TR := 3.6
const SY := 0.45
const FL := [1.0, 0.7, 0.95, 0.55, 0.85, 0.45, 0.7, 0.35]
const SK := [1.0, 0.75, 1.0, 0.6, 0.85, 0.4]

var arcs := []
var strikes := []


static func root_at(phi: float, up := 0.0) -> Vector2:
	return Vector2(cos(phi) * (RR + TR * 0.6), TY + sin(phi) * RR * SY - up)


static func age_of(f: int, f0: int) -> int:
	return ((f - f0) % N + N) % N


static func out_quad(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


func plan() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for v in [[2, 3], [20, 3], [30, 1], [38, 3], [56, 3], [66, 1]]:
		for j in v[1] + r.randi_range(0, 1):
			var side := 1.0 if r.randf() < 0.5 else -1.0
			var front := r.randf() < 0.55
			var a := r.randf_range(0.15, 1.1)
			var phi: float = (a if front else -a) if side > 0 else (PI - a if front else PI + a)
			var th0 := r.randf_range(-1.15, 0.35)
			arcs.append({"f0": (v[0] + j * r.randi_range(2, 4)) % N, "len": r.randi_range(3, 7), "side": side, "phi": phi,
				"front": front, "th0": th0, "th1": th0 + r.randf_range(-0.6, 0.6), "L": r.randf_range(24, 52)})
	for s in [[14, 1.0], [47, -1.0]]:
		strikes.append({"f0": s[0], "side": s[1], "x": roundf(s[1] * r.randf_range(38, 56)), "phi": 0.4 if s[1] > 0 else PI - 0.4})


func make() -> void:
	ground()
	var C := pal()
	plan()
	var pool := glow("Pool", 60, {"radius": 58, "color": C[3]}, {"at": Vector2(0, -10), "back": true})
	# scorch and smoke where the zaps land
	var scorches := []
	for s in strikes:
		scorches.append(scorch("Scorch%d" % scorches.size(), s.x, 7))
	# arcs off the back of the torus go behind the coil
	var nodes := []
	for a in arcs:
		if not a.front:
			nodes.append(_arc(a, nodes.size(), true))
		else:
			nodes.append(null)
	prop()
	var lit_l := glow("LitL", 16, {"radius": 14, "squash": 0.7, "color": C[5]}, {"at": Vector2(-RR - 1, TY + 1)})
	var lit_r := glow("LitR", 16, {"radius": 14, "squash": 0.7, "color": C[5]}, {"at": Vector2(RR + 1, TY + 1)})
	# the arcs' light catching the copper wire down the coil's lit side
	var img := Image.create(1, 37, false, Image.FORMAT_RGBA8)
	for y in range(0, 37, 2):
		img.set_pixel(0, y, Color.WHITE)
	var wire := ImageTexture.create_from_image(img)
	var edge_l := sprite("WireLitL", wire, {"at": Vector2(-5, -50), "centered": false})
	var edge_r := sprite("WireLitR", wire, {"at": Vector2(4, -50), "centered": false})
	var coil_glow := glow("TorusLight", 36, {"radius": 34, "color": C[3]}, {"at": Vector2(0, TY)})
	# corona: a faint violet fuzz crawling over the torus
	var halo := PackedVector2Array()
	for i in 48:
		var phi := i / 48.0 * TAU
		for d in [1.0, 2.0, 3.0]:
			halo.append(Vector2(cos(phi) * (RR + TR + d), TY + sin(phi) * (RR * SY + TR + d * 0.7)))
	particles("Corona", {"amount": 6, "lifetime": 0.034, "texture": "dot1", "emit": {"points": halo}, "speed": [0, 0],
		"initial": gradient([C[5], C[3], C[3], C[2]], [0.0, 0.3, 0.6, 0.85])})
	# brush discharge: short streamers hiss off the rim every frame
	var brush := []
	for i in 2:
		brush.append(volt("Brush%d" % i, Vector2.ZERO, Vector2(1, 0), {"style": 1, "jag": 0.4, "forks": 0.4, "rate": 30.0, "light": 0.3}))
	for i in arcs.size():
		if arcs[i].front:
			nodes[i] = _arc(arcs[i], i, false)
	# the zaps
	var zaps := []
	for s in strikes:
		var z := volt("Zap%d" % zaps.size(), root_at(s.phi, -2), Vector2(s.x, 0), {"jag": 0.22, "forks": 0.55, "rate": 30.0, "visible": false})
		var spot := orb("Spot%d" % zaps.size(), Vector2(s.x, -1), [[4.5, C[2]], [3.5, C[5]], [2.0, Color.WHITE]])
		var gl := glow("ZapLight%d" % zaps.size(), 42, {"radius": 40, "color": C[4], "alpha": 0.0}, {"at": Vector2(s.x, -10)})
		var gw := glow("ZapWhite%d" % zaps.size(), 14, {"radius": 12, "color": C[6], "alpha": 0.0}, {"at": Vector2(s.x, -3)})
		var sky := glow("ZapSky%d" % zaps.size(), 122, {"radius": 120, "color": C[3], "alpha": 0.0}, {"at": Vector2(0, -50)})
		zaps.append({"bolt": z, "spot": spot, "light": gl, "white": gw, "sky": sky})
		var sp := sparks("ZapSparks%d" % (zaps.size() - 1), {"at": Vector2(s.x, -1), "amount": 18, "lifetime": 0.65, "randomness": 0.5,
			"dir": -90, "spread": 75, "speed": [50, 190]})
		emit(sp, s.f0 / FPS)
		var ash := Color("#5b5566").lerp(C[2], 0.3)
		var smoke := particles("ZapSmoke%d" % (zaps.size() - 1), {"layer": "soft", "at": Vector2(s.x, -3), "amount": 2, "lifetime": 1.2,
			"one_shot": true, "explosiveness": 0.85, "emitting": false, "texture": "disc7", "emit": {"box": Vector2(3, 1)}, "dir": -90 + s.side * 15,
			"spread": 10, "speed": [12, 16], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.3]],
			"ramp": gradient([Color(ash, 0.0), Color(ash, 0.4), Color(Color("#433d48"), 0.25), Color(Color("#433d48"), 0.0)], [0.0, 0.08, 0.6, 0.95])})
		emit(smoke, s.f0 / FPS + 0.12)
	# sparks spat off each arc's tip as it strikes
	for i in arcs.size():
		var a: Dictionary = arcs[i]
		var ang: float = a.th0 if a.side > 0 else PI - a.th0
		var tip: Vector2 = root_at(a.phi) + Vector2(cos(ang), sin(ang)) * a.L * 0.75
		var sp := sparks("TipSparks%d" % i, {"at": tip, "amount": 3, "lifetime": 0.35, "randomness": 0.5, "dir": rad_to_deg(ang),
			"spread": 52, "speed": [50, 150]})
		emit(sp, a.f0 / FPS)

	# every frame: which arcs live, how bright; the light on the metal and the floor
	var K := {"pool": [], "ll": [], "lr": [], "tl": [], "el": [], "er": []}
	var A := []
	for a in arcs:
		A.append({"v": [], "k": [], "to": [], "from": []})
	var Z := []
	for s in strikes:
		Z.append({"v": [], "k": [], "hero": [], "thick": [], "r0": [], "r1": [], "r2": [], "l": [], "w": [], "sky": [], "heat": [], "fade": []})
	var B := [{"v": [], "a": [], "b": [], "k": []}, {"v": [], "a": [], "b": [], "k": []}]
	var rc := RandomNumberGenerator.new()
	rc.seed = 9
	for f in N + 1:
		var ff := f % N
		var st := maxf(0.0, (f - 0.5) / FPS)
		var lit := [0.0, 0.0]
		for i in arcs.size():
			var a: Dictionary = arcs[i]
			var age := age_of(ff, a.f0)
			var live: bool = age < a.len
			A[i].v.append([st, live])
			if live:
				lit[1 if a.side > 0 else 0] += FL[age] * 0.6
				var u: float = age / maxf(1.0, a.len - 1)
				var th: float = a.th0 + (a.th1 - a.th0) * out_quad(u)
				var ang: float = th if a.side > 0 else PI - th
				var x0 := root_at(a.phi)
				A[i].k.append([st, FL[age]])
				A[i].from.append([st, x0])
				A[i].to.append([st, x0 + Vector2(cos(ang), sin(ang)) * a.L * (0.75 if age == 0 else 1.0)])
		for j in strikes.size():
			var s: Dictionary = strikes[j]
			var age := age_of(ff, s.f0)
			var live := age < 6
			if live:
				lit[1 if s.side > 0 else 0] += 1.0
			var k: float = SK[age] if live else 0.0
			Z[j].v.append([st, live])
			Z[j].k.append([st, k])
			Z[j].hero.append([st, age == 0])
			Z[j].thick.append([st, 0.95 if age == 0 else 0.8])
			Z[j].r0.append([st, 3.0 * k + 1.5 if live else 0.0])
			Z[j].r1.append([st, 3.0 * k + 0.5 if live else 0.0])
			Z[j].r2.append([st, 2.0 * k if live else 0.0])
			Z[j].l.append([st, 0.55 * k])
			Z[j].w.append([st, 0.5 * k])
			Z[j].sky.append([st, 0.25 * k if age < 2 else 0.0])
			var sa: float = fposmod(ff / FPS - s.f0 / FPS, P)
			Z[j].heat.append([st, pow(clampf(1.0 - sa / 1.1, 0.0, 1.0), 1.3)])
			Z[j].fade.append([st, 1.0 - clampf((sa - 1.4) / 0.6, 0.0, 1.0)])
		var act := minf(1.0, (lit[0] + lit[1]) * 0.5)
		K.pool.append([st, 0.14 + 0.25 * act])
		K.tl.append([st, 0.18 + 0.3 * act])
		K.ll.append([st, 0.35 * minf(1.0, lit[0])])
		K.lr.append([st, 0.35 * minf(1.0, lit[1])])
		K.el.append([st, C[6] if lit[0] > 0.6 else (C[4] if lit[0] > 0.25 else Color(C[4], 0.0))])
		K.er.append([st, C[6] if lit[1] > 0.6 else (C[4] if lit[1] > 0.25 else Color(C[4], 0.0))])
		for i in 2:
			var phi := rc.randf_range(0, TAU)
			var x0 := Vector2(cos(phi) * (RR + TR * 0.8), TY + sin(phi) * (RR * SY + TR * 0.6))
			var an := atan2(sin(phi) * 0.6 - 0.5, cos(phi)) + rc.randf_range(-0.5, 0.5)
			var l := rc.randf_range(4, 10)
			B[i].a.append([st, x0])
			B[i].b.append([st, x0 + Vector2(cos(an), sin(an)) * l])
			B[i].k.append([st, rc.randf_range(0.35, 0.65)])
	key(pool, "material:shader_parameter/alpha", K.pool, "nearest")
	key(coil_glow, "material:shader_parameter/alpha", K.tl, "nearest")
	key(lit_l, "material:shader_parameter/alpha", K.ll, "nearest")
	key(lit_r, "material:shader_parameter/alpha", K.lr, "nearest")
	key(edge_l, "modulate", K.el, "nearest")
	key(edge_r, "modulate", K.er, "nearest")
	for i in arcs.size():
		key(nodes[i], "visible", A[i].v, "nearest")
		key(nodes[i], "k", A[i].k, "nearest")
		key(nodes[i], "from", A[i].from, "nearest")
		key(nodes[i], "to", A[i].to, "nearest")
		key(nodes[i].get_node("Root"), "material:shader_parameter/alpha", A[i].k.map(func(k): return [k[0], 0.5 * k[1]]), "nearest")
	for j in strikes.size():
		var z: Dictionary = zaps[j]
		key(z.bolt, "visible", Z[j].v, "nearest")
		key(z.bolt, "k", Z[j].k, "nearest")
		key(z.bolt, "hero", Z[j].hero, "nearest")
		key(z.bolt, "thick", Z[j].thick, "nearest")
		for q in 3:
			key(z.spot[q], "material:shader_parameter/radius", Z[j]["r%d" % q], "nearest")
		key(z.light, "material:shader_parameter/alpha", Z[j].l, "nearest")
		key(z.white, "material:shader_parameter/alpha", Z[j].w, "nearest")
		key(z.sky, "material:shader_parameter/alpha", Z[j].sky, "nearest")
		key(scorches[j], "material:shader_parameter/heat", Z[j].heat, "nearest")
		key(scorches[j], "material:shader_parameter/fade", Z[j].fade, "nearest")
	for i in 2:
		key(brush[i], "from", B[i].a, "nearest")
		key(brush[i], "to", B[i].b, "nearest")
		key(brush[i], "k", B[i].k, "nearest")


func _arc(a: Dictionary, i: int, back: bool) -> Node2D:
	var x0 := root_at(a.phi)
	var n := volt("Arc%d" % i, x0, x0 + Vector2(20, 0), {"back": back, "thick": 0.6, "light": 0.4, "jag": 0.32, "forks": 0.75, "rate": 30.0, "visible": false})
	glow("Root", 12, {"radius": 10, "color": pal()[5], "alpha": 0.0}, {"at": x0, "parent": n})
	return n
