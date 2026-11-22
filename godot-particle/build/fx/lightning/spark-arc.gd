# reimagined-from: src/fx/lightning/spark-arc.js@d63414f17b7ff830758cec32cd3334a14989dd1b
# Spark arc: A climbing arc between two rods: it strikes white at their narrow foot, climbs on rising heat as it stretches and bows, sputters and snaps at the top, then strikes again.
# loop, 2.00 s, 124x120 canvas, origin [62.0, 108.0], backdrop ground
# The plate, insulators and steel rods are the original's still pixels (port/props.py); the heat the arc leaves on
# the rods is a shader over the rod pixels (fx/lightning/_rods.gdshader) on the original's climb curve; the arc is a
# bowed layered bolt (fx/lightning/_volt.gd) keyed up the rods every frame, flickering and sputtering, with hot
# nodes where it roots; at the top it snaps into two clinging stubs; little sparks jump the gap before it strikes
# again; sparks fly at the strike and the snap and molten drips fall off the rods; ozone puffs rise off it.
extends "res://build/fx/lightning/_base.gd"

const P := 2.0
const N := 60
const SNAP := 1.42
const H := 58.0


static func rod_at(s: float, h: float) -> Vector2:
	return Vector2(s * (4.5 + (h / 60.0) * 19.5), -9.0 - h)


static func height(t: float) -> float:
	return 1.5 + H * pow(clampf(t / SNAP, 0.0, 1.0), 1.35)


func make() -> void:
	ground()
	var C := pal()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	prop()
	var pool := glow("Pool", 52, {"radius": 50, "color": C[3]}, {"at": Vector2(0, -14), "back": true})
	_rods()

	# the arc, its light, the nodes where it roots
	var arc := volt("Arc", rod_at(-1, 1.5), rod_at(1, 1.5), {"bow": -1.5, "jag": 0.18, "forks": 0.12, "rate": 30.0, "thick": 0.8, "light": 0.7})
	var band := glow("ArcLight", 40, {"radius": 20, "squash": 0.5, "color": C[4]}, {"at": Vector2(0, -12)})
	var nodes := []
	var node_light := []
	for s in [-1, 1]:
		nodes.append(ring("Root%s" % ("L" if s < 0 else "R"), 4, {"radius": 2.4, "color": C[5]}))
		node_light.append(glow("RootLight%s" % ("L" if s < 0 else "R"), 14, {"radius": 12, "color": C[5]}))
	var node_px := []
	for s in [-1, 1]:
		node_px.append(rect("RootPx%s" % ("L" if s < 0 else "R"), Rect2(0, 0, 1, 1), Color.WHITE))
	var strike := glow("StrikeLight", 28, {"radius": 26, "color": C[6]}, {"at": Vector2(0, -11)})
	key(strike, "material:shader_parameter/alpha", [[0.0, 0.45], [0.1, 0.0]])
	var top := glow("TopLight", 28, {"radius": 26, "color": C[4]})
	# the snap: two stubs clinging to the rods; and the little sparks across the gap before it strikes again
	var stubs := []
	for s in [-1, 1]:
		stubs.append(volt("Stub%s" % ("L" if s < 0 else "R"), Vector2.ZERO, Vector2(1, 0), {"style": 1, "k": 0.7, "jag": 0.4, "forks": 0.3, "rate": 30.0, "light": 0.4, "visible": false}))
	var snap_light := glow("SnapLight", 32, {"radius": 30, "color": C[4], "alpha": 0.5}, {"at": Vector2(0, rod_at(-1, H + 1.5).y - 8)})
	show(snap_light, SNAP - 0.5 / FPS, SNAP + 1.5 / FPS)
	var gap := volt("Gap", Vector2(-4.5, -10.5), Vector2(4.5, -10.5), {"style": 1, "jag": 0.5, "forks": 0.0, "rate": 30.0, "light": 0.35, "visible": false})

	var K := {"from": [], "to": [], "bow": [], "k": [], "hero": [], "thick": [], "jag": [], "forks": [], "vis": [], "band": [], "band_r": [],
		"band_sq": [], "band_a": [], "pool": [], "top": [], "top_a": [], "gv": [], "gf": [], "gt": [], "gk": []}
	var R := [{"p": [], "r": [], "a": []}, {"p": [], "r": [], "a": []}]
	var stub_keys := [{"v": [], "a": [], "b": []}, {"v": [], "a": [], "b": []}]
	for f in N + 1:
		var ff := f % N
		var t := ff / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var climbing := t < SNAP
		var h := height(t)
		var u := clampf(t / SNAP, 0.0, 1.0)
		var a := t - SNAP
		var r1 := rng.randf()
		var r2 := rng.randf()
		var r3 := rng.randf()
		K.pool.append([st, (0.2 + 0.15 * (1.0 - u)) if climbing else 0.06])
		K.top.append([st, Vector2(0, -9.0 - h - 3.0)])
		K.top_a.append([st, 0.25 if climbing else (0.4 * (1.0 - a / 0.25) if a < 0.25 else 0.0)])
		if climbing:
			var xl := rod_at(-1, h)
			var xr := rod_at(1, h)
			var k0 := 1.0 if ff == 0 else 1.0 - 0.22 * u
			var sput := 0.4 if (u > 0.88 and r1 < 0.25) else 1.0
			var k := k0 * sput * (0.82 + 0.18 * r2)
			var bow := -(1.5 + 13.0 * u * u) * (0.8 + 0.4 * r3)
			K.vis.append([st, true])
			K.from.append([st, xl])
			K.to.append([st, xr])
			K.bow.append([st, bow])
			K.k.append([st, k])
			K.hero.append([st, ff == 0])
			K.thick.append([st, 0.95 if ff == 0 else 0.8])
			K.jag.append([st, 0.18 + 0.12 * u])
			K.forks.append([st, 0.12 + 0.25 * u])
			var half := (xr.x - xl.x) * 0.5
			K.band.append([st, Vector2(0, xl.y + bow * 0.5)])
			K.band_r.append([st, half + 12.0])
			K.band_sq.append([st, 12.0 / (half + 12.0)])
			K.band_a.append([st, 0.22 * k * 1.6])
			for i in 2:
				var p: Vector2 = [xl, xr][i]
				R[i].p.append([st, p])
				R[i].r.append([st, 1.8 + 0.6 * k])
				R[i].a.append([st, 0.55 * k])
		else:
			K.vis.append([st, false])
			K.band_a.append([st, 0.0])
			for i in 2:
				R[i].r.append([st, 0.0])
				R[i].a.append([st, 0.0])
		# the snap's stubs
		var snapping := not climbing and a < 2.0 / FPS
		for i in 2:
			var s: float = [1.0, -1.0][i]
			var p0 := rod_at(-1.0 if i == 0 else 1.0, H + 1.5)
			stub_keys[i].v.append([st, snapping])
			stub_keys[i].a.append([st, p0])
			stub_keys[i].b.append([st, p0 + Vector2(s * rng.randf_range(5, 9), -rng.randf_range(2, 6))])
		# the gap sputters before the next strike
		var r4 := rng.randf()
		var on := t > P - 0.16 and r4 < 0.7
		K.gv.append([st, on])
		K.gf.append([st, Vector2(-4.5, -10.5 - rng.randf_range(0, 2))])
		K.gt.append([st, Vector2(4.5, -10.5 - rng.randf_range(0, 2))])
		K.gk.append([st, 0.4 + 0.3 * rng.randf()])
	key(arc, "visible", K.vis, "nearest")
	key(arc, "from", K.from, "nearest")
	key(arc, "to", K.to, "nearest")
	key(arc, "bow", K.bow, "nearest")
	key(arc, "k", K.k, "nearest")
	key(arc, "hero", K.hero, "nearest")
	key(arc, "thick", K.thick, "nearest")
	key(arc, "jag", K.jag, "nearest")
	key(arc, "forks", K.forks, "nearest")
	key(band, "position", K.band, "nearest")
	key(band, "material:shader_parameter/radius", K.band_r, "nearest")
	key(band, "material:shader_parameter/squash", K.band_sq, "nearest")
	key(band, "material:shader_parameter/alpha", K.band_a, "nearest")
	key(pool, "material:shader_parameter/alpha", K.pool, "nearest")
	key(top, "position", K.top, "nearest")
	key(top, "material:shader_parameter/alpha", K.top_a, "nearest")
	for i in 2:
		key(nodes[i], "position", R[i].p, "nearest")
		key(nodes[i], "material:shader_parameter/radius", R[i].r, "nearest")
		key(node_light[i], "position", R[i].p, "nearest")
		key(node_light[i], "material:shader_parameter/alpha", R[i].a, "nearest")
		key(node_px[i], "position", R[i].p.map(func(k): return [k[0], (k[1] as Vector2).floor()]), "nearest")
		show(node_px[i], 0.0, SNAP)
		key(stubs[i], "visible", stub_keys[i].v, "nearest")
		key(stubs[i], "from", stub_keys[i].a, "nearest")
		key(stubs[i], "to", stub_keys[i].b, "nearest")
	key(gap, "visible", K.gv, "nearest")
	key(gap, "from", K.gf, "nearest")
	key(gap, "to", K.gt, "nearest")
	key(gap, "k", K.gk, "nearest")

	# sparks: thrown from the roots as it strikes, sprayed up where it snaps, molten drips off the rods
	for s in [-1, 1]:
		var sp := sparks("Strike%s" % ("L" if s < 0 else "R"), {"at": rod_at(s, 1.5), "amount": 6, "lifetime": 0.6, "randomness": 0.5,
			"dir": -90 + s * 34, "spread": 57, "speed": [60, 170]})
		emit(sp, 0.0)
	var spray := sparks("Spray", {"at": Vector2(0, -9 - H - 6), "amount": 14, "lifetime": 0.6, "randomness": 0.5, "emit": {"box": Vector2(15, 1)},
		"dir": -90, "spread": 75, "speed": [50, 160]})
	emit(spray, SNAP)
	var i := 0
	for tt in [0.45, 0.8, 1.15]:
		for s in [-1, 1]:
			var drip := sparks("Drip%d" % i, {"at": rod_at(s, height(tt)), "amount": 1, "lifetime": 0.5, "dir": 90, "spread": 29, "speed": [5, 30]})
			emit(drip, tt)
			i += 1
	# ozone and smoke rising off the arc while it climbs
	var ash := Color("#6a6478").lerp(C[5], 0.3)
	for j in 3:
		var born := (j + 1) / 3.2 * SNAP
		var puff := particles("Ozone%d" % j, {"layer": "soft", "at": Vector2(-3 if j % 2 == 0 else 3, -9.0 - height(born) - 6.0), "amount": 1,
			"lifetime": 1.0, "one_shot": true, "emitting": false, "texture": "disc5", "dir": -90, "speed": [20, 20],
			"scale_curve": [[0, 0.75 + j * 0.12], [0.4, 1.0 + j * 0.15], [1, 1.25 + j * 0.15]],
			"ramp": gradient([Color(ash, 0.0), Color(ash, 0.35), Color(Color("#5d5660"), 0.25), Color(Color("#433d48"), 0.0)], [0.0, 0.08, 0.5, 0.95])})
		emit(puff, born)


## Heat on the rods: the rod pixels and their heights, baked into a data texture for fx/lightning/_rods.gdshader.
func _rods() -> void:
	var px := {}
	for s in [-1.0, 1.0]:
		var hh := 0.0
		while hh <= 60.0:
			var p := rod_at(s, hh)
			var q := Vector2i(floori(p.x), floori(p.y))
			if not px.has(q) or px[q].y > 0.5:
				px[q] = Vector2(hh, 0.0)
			var q2 := Vector2i(floori(p.x + s), floori(p.y))
			if not px.has(q2):
				px[q2] = Vector2(hh, 1.0)
			hh += 0.5
	var lo := Vector2i(-40, -80)
	var sz := Vector2i(80, 80)
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	for q in px:
		var v: Vector2 = px[q]
		img.set_pixel(q.x - lo.x, q.y - lo.y, Color(v.x / 64.0, v.y, 0.0, 1.0))
	var fire := fire_ramp()
	var heat := shape("RodHeat", load("res://addons/pixelfx_particles/fx/lightning/_rods.gdshader"), Vector2(sz),
		{"data": ImageTexture.create_from_image(img), "fire": fire, "steel": Color("#3d4558"), "period": P, "snap": SNAP, "climb": H},
		{"at": Vector2(lo) + Vector2(sz) / 2.0, "back": true})
	key(heat, "material:shader_parameter/t", [[0.0, 0.0], [P, P]])
