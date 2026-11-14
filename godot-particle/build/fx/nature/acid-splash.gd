# reimagined-from: src/fx/nature/acid-splash.js@7ba1254a8ccb99ff43b8d82266f7c906bf635eca
# Acid splash: A gob of acid bursts into a crown and spatters; it eats a glowing, smoking pit into the floor and boils
# down into it, spitting bright beads, pale steam curling off.
# The falling gob (a teardrop stretched by its fall) and the crown (a cup wall with spikes, beads on their tips) are
# shapes drawn frame by frame at build time the way the original draws them, stepped by keys; the pit and the acid
# boiling down into it are a shader (fx/nature/_acid_pit.gdshader) whose width, depth, level and heat follow the
# original's curves, keyed every frame. Droplets (bead and tail, aligned with their flight) arc out and vanish into
# a collision floor, with a light-layer twin glowing on each; spots etch where they land; sparks, beads spat off the
# surface, sizzle flashes and steam wisps curling off the pit and the spots are emitters.
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const HIT := 0.3
const Y0 := -62.0
const V0 := 60.0
const SPREAD := 0.4
const DRY := 0.7
const GONE := 2.2
const W := 30.0
const PIT := 5.0

var C: PackedColorArray
var spikes := []


func pw(t: float) -> float:
	return W * N.out_cubic(clampf((t - HIT) / SPREAD, 0.0, 1.0)) * 1.02


func pit_d(t: float) -> float:
	return PIT * N.out_cubic(clampf((t - HIT) / 1.1, 0.0, 1.0))


func level(t: float) -> float:
	if t < HIT:
		return 0.0
	var s := N.smooth(DRY, GONE, t)
	return -1.6 + (PIT + 1.6) * s * s


func width(t: float) -> float:
	var L := level(t)
	var w := pw(t)
	return w if L <= 0.0 else w * sqrt(maxf(0.0, 1.0 - pow(L / maxf(0.1, pit_d(t)), 2.0)))


func heat(t: float) -> float:
	return N.smooth(HIT, HIT + 0.3, t) * (1.0 - N.smooth(GONE - 0.3, GONE + 0.25, t))


static func _put(img: Image, o: Vector2i, x: float, y: float, c: Color, a := 1.0) -> void:
	var X := int(floor(x)) - o.x
	var Y := int(floor(y)) - o.y
	if X < 0 or Y < 0 or X >= img.get_width() or Y >= img.get_height():
		return
	if a < 1.0:
		var d := img.get_pixel(X, Y)
		if d.a > 0.0:
			# over something already drawn: blend toward it, keep it opaque
			img.set_pixel(X, Y, Color(d.lerp(c, a), maxf(d.a, a)))
			return
	img.set_pixel(X, Y, Color(c, a))


static func _line(img: Image, o: Vector2i, x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var sx := int(floor(x0))
	var sy := int(floor(y0))
	var ex := int(floor(x1))
	var ey := int(floor(y1))
	var dx := absi(ex - sx)
	var dy := -absi(ey - sy)
	var stx := 1 if sx < ex else -1
	var sty := 1 if sy < ey else -1
	var err := dx + dy
	while true:
		_put(img, o, sx, sy, c)
		if sx == ex and sy == ey:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			sx += stx
		if e2 <= dx:
			err += dx
			sy += sty


## The crown at `e` s after the hit: a thin cup wall rising round the impact, a bright rim, spikes off the rim with
## beads on their tips; back: its far half (behind the pit), else the near half.
func crown(e: float, back: bool) -> Image:
	var o := Vector2i(-24, -26)
	var img := Image.create(48, 34, false, Image.FORMAT_RGBA8)
	var r := 4.0 + 11.0 * N.out_cubic(clampf(e / 0.16, 0.0, 1.0))
	var h := 5.0 * sin(PI * clampf(e / 0.26, 0.0, 1.0))
	var ry := r * 0.3
	for x in range(int(floor(-r)), int(ceil(r)) + 1):
		var c := (x + 0.5) / r
		if absf(c) > 1.0:
			continue
		var ee := sqrt(1.0 - c * c)
		var yb := (-ry if back else ry) * ee
		var hh := h * (0.75 + 0.25 * ee)
		var y0 := int(floor(yb - hh))
		for y in range(y0, int(roundf(yb)) + 1):
			if y == y0:
				_put(img, o, x, y, C[5] if back else (C[7] if c < 0.1 else C[6]))
			else:
				var i := (5 if c < -0.25 else 3 if c > 0.45 else 4) - (1 if back else 0)
				_put(img, o, x, y, C[i], 0.55 if back else 0.7)
	var u := clampf((e - 0.015) / 0.26, 0.0, 1.0)
	var k := sin(PI * pow(u, 0.6))
	for s in spikes:
		if (sin(s.a) < 0.0) != back:
			continue
		var tip := tip_of(s, r, h, k)
		_line(img, o, tip[0], tip[1], tip[2], tip[3], C[4] if back else C[6])
		_line(img, o, tip[0] + 1, tip[1], (tip[0] + tip[2]) / 2.0 + 0.5, (tip[1] + tip[3]) / 2.0, C[3] if back else C[5])
		if e <= 0.09:
			_put(img, o, tip[2], tip[3] - 1, C[5] if back else C[7])
			_put(img, o, tip[2] + 1, tip[3] - 1, C[5])
	return img


func tip_of(s: Dictionary, cr: float, h: float, k: float) -> Array:
	var r: float = cr * s.r
	var sn := sin(s.a)
	var sh: float = s.h * k
	var bx := cos(s.a) * r
	var by := sn * r * 0.3 - h * (0.75 + 0.25 * absf(sn))
	return [bx, by, bx + cos(s.a) * sh * 0.55, by - sh]


## The gob at time t: a teardrop stretched by its fall, lit on its upper left, a trail of droplets above it.
func gob(t: float) -> Image:
	var y := Y0 + V0 * t + 0.5 * 950.0 * t * t
	var o := Vector2i(-6, int(floor(y)) - 24)
	var img := Image.create(12, 32, false, Image.FORMAT_RGBA8)
	var v := V0 + 950.0 * t
	var st := 1.0 + v * 0.0022
	var rx := 2.6 / sqrt(st)
	var ry := 2.8 * st
	for Y in range(int(floor(y - ry - 4)), int(ceil(y + ry + 1)) + 1):
		for X in range(int(floor(-rx - 1)), int(ceil(rx + 1)) + 1):
			var px := X + 0.5
			var py := Y + 0.5
			if px < -rx - 1 or px > rx + 1 or py < y - ry - 4 or py > y + ry + 1:
				continue
			var dx := px / rx
			var dy := (py - y) / ry
			var tail := dy < 0.0 and absf(px) < rx * (1.0 + dy * 0.9) + 0.4 and dy > -1.7
			var d := dx * dx + dy * dy
			if d > 1.25 and not tail:
				continue
			var c: Color = C[2] if (d > 1.0 and not tail) else C[7] if (dx < -0.2 and dy < -0.1) else C[4] if dy > 0.45 else C[5]
			_put(img, o, px, py, c)
	_put(img, o, -1, y - ry * 0.3, Color.WHITE)
	for i in range(1, 4):
		_put(img, o, 0, y - ry - 2 - i * 4, C[5], 1.0 - i * 0.25)
	return img


func step_sprite(name: String, images: Array, origins: Array, times: Array, back := false) -> Sprite2D:
	var s := sprite(name, N.strip(images), {"centered": false, "back": back})
	s.hframes = images.size()
	var fk := []
	var pk := []
	for i in images.size():
		fk.append([times[i], i])
		pk.append([times[i], Vector2(origins[i])])
	key(s, "frame", fk, "nearest")
	key(s, "position", pk, "nearest")
	return s


func make() -> void:
	C = root.ramps.palette
	var D: float = meta.duration
	var scorch := C[0].lerp(Color("#140f0c"), 0.6)
	var burnt := C[1].lerp(Color("#2a1a10"), 0.6)
	var steam := C[7].lerp(Color("#e8ece6"), 0.75)
	keep_colour(scorch)
	keep_colour(burnt)
	keep_colour(steam)
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(meta.options.seed)
	for i in 13:
		spikes.append({"a": i / 13.0 * TAU + rng.randf_range(-0.18, 0.18), "h": rng.randf_range(4, 10), "r": rng.randf_range(0.85, 1.12)})

	# spots etched round it where drops land: bright, cooling to a burnt ring round a scorched heart
	var spot := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	spot.set_pixel(0, 0, Color.WHITE)
	spot.set_pixel(1, 0, Color.WHITE)
	spot.set_pixel(2, 0, Color.WHITE)
	var spots := particles("Spots", {"back": true, "at": Vector2(0, 0.5), "amount": 26, "lifetime": 1.8, "randomness": 0.2,
		"emitting": false, "texture": ImageTexture.create_from_image(spot), "emit": {"box": Vector2(62, 0)},
		"ramp": gradient([C[7], C[6], C[4], burnt, Color(burnt, 0.6), Color(burnt, 0.0)], [0.0, 0.08, 0.28, 0.5, 0.6, 0.95])})
	emit(spots, HIT + 0.08, HIT + 0.65)
	var spot_light := particles("SpotLight", {"layer": "light", "at": Vector2(0, -0.5), "amount": 26, "lifetime": 1.8,
		"randomness": 0.2, "emitting": false, "texture": "glow8", "emit": {"box": Vector2(62, 0)},
		"ramp": gradient([Color(C[5], 0.3), Color(C[5], 0.15), Color(C[5], 0.0)], [0.0, 0.14, 0.28])})
	spot_light.seed = spots.seed
	emit(spot_light, HIT + 0.08, HIT + 0.65)

	# the crown's far half, behind the pit
	var times := []
	var back_imgs := []
	var front_imgs := []
	var origins := []
	for i in 9:
		var e := i / 30.0
		times.append(HIT + e)
		back_imgs.append(crown(e, true))
		front_imgs.append(crown(e, false))
		origins.append(Vector2i(-24, -26))
	var crown_back := step_sprite("CrownBack", back_imgs, origins, times, true)
	show(crown_back, HIT, HIT + 0.27)

	# the pit and the acid in it, keyed every frame from the original's curves
	var pit := shape("Pit", load("res://addons/pixelfx_particles/fx/nature/_acid_pit.gdshader"), Vector2(76, 16),
		{"ramp": ramp("palette", {"stops": 8}), "scorch": scorch, "burnt": burnt, "seed": float(meta.options.seed)},
		{"at": Vector2(0, 2), "back": true})
	var kp := {"pw": [], "pit": [], "level": [], "heat": [], "fade": [], "acid": [], "t": []}
	for i in int(D * 30.0) + 2:
		var t := i / 30.0
		kp.pw.append([t, pw(t) if t > HIT else 0.0])
		kp.pit.append([t, pit_d(t)])
		kp.level.append([t, level(t)])
		kp.heat.append([t, heat(t)])
		kp.fade.append([t, 1.0 - N.smooth(D - 0.6, D - 0.08, t)])
		kp.acid.append([t, 1.0 if t < GONE else 0.0])
		kp.t.append([t, t])
	for k in kp:
		key(pit, "material:shader_parameter/" + k, kp[k], "nearest" if k == "acid" else "linear")
	# its light: the lips, a warm swell over it, a glow down in it
	var lips := []
	for sd in [-1, 1]:
		lips.append(glow("LipLight%s" % ("L" if sd < 0 else "R"), 10, {"radius": 8, "color": C[6], "alpha": 0.0}))
	var swell := glow("PitLight", 56, {"radius": 10, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -6)})
	var low := glow("PitGlow", 30, {"radius": 1, "color": C[6], "alpha": 0.0}, {"at": Vector2(0, 1)})
	var lk := [[], [], []]
	var sk := []
	var sr := []
	var gk := []
	var gr := []
	for i in int(D * 30.0) + 2:
		var t := i / 30.0
		var w := pw(t)
		var hk := heat(t)
		lk[0].append([t, Vector2(-w, -1)])
		lk[1].append([t, Vector2(w, -1)])
		lk[2].append([t, 0.45 * hk])
		sk.append([t, 0.3 * hk * (0.85 + 0.15 * sin(t * 9.0))])
		sr.append([t, w * 1.4 + 10.0])
		gk.append([t, 0.2 * hk])
		gr.append([t, maxf(1.0, w * 0.9)])
	for j in 2:
		key(lips[j], "position", lk[j])
		key(lips[j], "material:shader_parameter/alpha", lk[2])
	key(swell, "material:shader_parameter/alpha", sk)
	key(swell, "material:shader_parameter/radius", sr)
	key(low, "material:shader_parameter/alpha", gk)
	key(low, "material:shader_parameter/radius", gr)

	# the gob falling, its light riding with it
	var gimgs := []
	var gor := []
	var gt := []
	var gl := []
	for i in int(HIT * 30.0):
		var t := i / 30.0
		gimgs.append(gob(t))
		var y := Y0 + V0 * t + 0.5 * 950.0 * t * t
		gor.append(Vector2i(-6, int(floor(y)) - 24))
		gt.append(t)
		gl.append([t, Vector2(0, y)])
	var g := step_sprite("Gob", gimgs, gor, gt)
	show(g, 0.0, HIT)
	var gob_light := glow("GobLight", 12, {"radius": 10, "color": C[5], "alpha": 0.45})
	key(gob_light, "position", gl, "nearest")
	show(gob_light, 0.0, HIT)

	# the crown's near half, and the hero frame: a white burst where it lands, a sparkle
	var crown_front := step_sprite("CrownFront", front_imgs, origins, times)
	show(crown_front, HIT, HIT + 0.27)
	var burst := ring("Burst", 13, {"radius": 6, "squash": 2.5 / 6.0, "color": Color.WHITE}, {"at": Vector2(0, -2)})
	key(burst, "material:shader_parameter/radius", [[HIT, 6.0], [HIT + 1 / 30.0, 8.9], [HIT + 2 / 30.0, 11.0]], "nearest")
	key(burst, "material:shader_parameter/squash", [[HIT, 2.5 / 6.0], [HIT + 1 / 30.0, 2.5 / 8.9], [HIT + 2 / 30.0, 2.5 / 11.0]], "nearest")
	key(burst, "material:shader_parameter/color", [[HIT, Color.WHITE], [HIT + 2 / 30.0, C[7]]], "nearest")
	show(burst, HIT, HIT + 0.07)
	var star := gradient([C[6], C[7], C[6]], [0.0, 0.3, 0.7])
	for k in 2:
		var arm := roundf(8.0 * (1.0 - k / 30.0 / 0.07))
		for axis in [Vector2(1, 0), Vector2(0, 1)]:
			var sl := line("Sparkle%d%s" % [k, "H" if axis.x > 0 else "V"], PackedVector2Array([Vector2(0.5, -3.5) - axis * arm, Vector2(0.5, -3.5) + axis * arm]), {"gradient": star})
			show(sl, HIT + k / 30.0, HIT + (k + 1) / 30.0)
	var flash := glow("HitFlash", 30, {"radius": 28, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -4)})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0], [HIT, 0.7], [HIT + 0.04, 0.12], [HIT + 0.08, 0.0]])
	var green := glow("HitLight", 58, {"radius": 56, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -10)})
	var gk2 := [[0.0, 0.0], [HIT - 0.001, 0.0]]
	var gr2 := []
	for i in 13:
		var k := 1.0 - i / 12.0
		gk2.append([HIT + 0.05 * i, 0.5 * k * k])
		gr2.append([HIT + 0.05 * i, 56.0 * (0.55 + 0.45 * k)])
	key(green, "material:shader_parameter/alpha", gk2)
	key(green, "material:shader_parameter/radius", gr2)

	# droplets: a bright bead with a tail along its flight; they vanish into the floor where they land
	var d1 := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	for y in 3:
		d1.set_pixel(0, y, C[4])
	d1.set_pixel(0, 3, C[7])
	var d2 := Image.create(2, 5, false, Image.FORMAT_RGBA8)
	for y in 4:
		d2.set_pixel(0, y, C[4])
	d2.set_pixel(0, 3, C[6])
	d2.set_pixel(0, 4, C[7])
	d2.set_pixel(1, 4, C[5])
	var tex1 := ImageTexture.create_from_image(d1)
	var tex2 := ImageTexture.create_from_image(d2)
	var drop_sets := [["Drops", tex1, 18, Vector2(0, -2), {"box": Vector2(3, 0.5)}, 77.0, [60, 250]],
		["BigDrops", tex2, 8, Vector2(0, -2), {"box": Vector2(3, 0.5)}, 77.0, [60, 250]]]
	for ds in drop_sets:
		var o := {"at": ds[3], "amount": ds[2], "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": ds[1], "align": true, "emit": ds[4], "dir": -90, "spread": ds[5], "speed": ds[6], "gravity": Vector2(0, 950),
			"damping": [10, 30], "collide": {"hide": true, "size": 1}}
		var p := particles(ds[0], o)
		emit(p, HIT)
		var lo := o.duplicate()
		lo.layer = "light"
		lo.texture = "glow8"
		lo.align = false
		lo.color = Color(C[6], 0.3)
		var pl := particles(ds[0] + "Light", lo)
		pl.seed = p.seed
		emit(pl, HIT)
	# beads breaking off the crown's spikes as they peak
	var tips := PackedVector2Array()
	var r9 := 4.0 + 11.0 * N.out_cubic(0.1 / 0.16)
	var h9 := 5.0 * sin(PI * 0.1 / 0.26)
	var k9 := sin(PI * pow(clampf((0.1 - 0.015) / 0.26, 0.0, 1.0), 0.6))
	for s in spikes:
		var tp := tip_of(s, r9, h9, k9)
		tips.append(Vector2(tp[2], tp[3] - 1))
	var beads := particles("CrownBeads", {"amount": 13, "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": tex1, "align": true, "emit": {"points": tips}, "dir": -90, "spread": 35, "speed": [55, 150],
		"gravity": Vector2(0, 950), "damping": [10, 30], "collide": {"hide": true, "size": 1}})
	emit(beads, HIT + 0.1)
	var sparks := particles("Sparks", {"at": Vector2(0, -2), "amount": 10, "lifetime": 0.3, "randomness": 0.5, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "streak6", "align": true, "dir": -90, "spread": 69,
		"speed": [120, 260], "damping": [250, 400], "gravity": Vector2(0, 430), "ramp": gradient([C[7], C[6], C[5], C[4]])})
	emit(sparks, HIT)

	# the acid sizzles: beads spit off its surface, little star flashes, over the width it still has
	var surf_keys := []
	var box_keys := []
	for i in int(D * 30.0) + 2:
		var t := i / 30.0
		var lv := level(t)
		surf_keys.append([t, Vector2(0, minf(lv, pit_d(t) * 0.6) - 1.5)])
		box_keys.append([t, Vector3(maxf(0.5, width(t) * 0.85), 0.5, 0)])
	var spit := particles("Spit", {"amount": 14, "lifetime": 0.5, "randomness": 0.3, "emitting": false, "texture": tex1,
		"align": true, "emit": {"box": Vector2(20, 0.5)}, "dir": -90, "spread": 30, "speed": [55, 115],
		"gravity": Vector2(0, 950), "collide": {"hide": true, "size": 1}})
	var pops := particles("Pops", {"amount": 3, "lifetime": 0.1, "emitting": false, "texture": "plus3",
		"emit": {"box": Vector2(20, 0.5)}, "ramp": gradient([Color.WHITE, C[7]], [0.0, 0.5])})
	var pop_light := particles("PopLight", {"layer": "light", "amount": 3, "lifetime": 0.1, "emitting": false, "texture": "glow8",
		"emit": {"box": Vector2(20, 0.5)}, "color": Color(C[6], 0.4)})
	pop_light.seed = pops.seed
	for e in [spit, pops, pop_light]:
		emit(e, HIT + 0.15, GONE)
		key(e, "position", surf_keys)
		key(e, "process_material:emission_box_extents", box_keys)

	# steam: thin pale wisps curling up off the pit as it eats, off the spots, and smoking after
	var wisp := {"layer": "soft", "texture": "streak6", "align": true, "dir": -90, "spread": 12, "speed": [22, 32],
		"ramp": gradient([Color(steam, 0.0), Color(steam, 0.42), Color(steam, 0.42), Color(steam, 0.25), Color(steam, 0.0)], [0.0, 0.12, 0.45, 0.75, 0.95]),
		"turbulence": {"strength": 6.0, "scale": 1.5, "influence": [0.04, 0.08]}}
	var big := particles("SteamBurst", wisp.merged({"at": Vector2(0, -4), "amount": 5, "lifetime": 0.95, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "streak8", "emit": {"box": Vector2(10, 2)}}))
	emit(big, HIT)
	var off_spots := particles("SteamSpots", wisp.merged({"at": Vector2(0, -2), "amount": 40, "lifetime": 0.7, "randomness": 0.3,
		"emitting": false, "emit": {"box": Vector2(62, 0.5)}}))
	emit(off_spots, HIT + 0.1, HIT + 0.9)
	var off_pit := particles("SteamPit", wisp.merged({"amount": 26, "lifetime": 0.7, "randomness": 0.3, "emitting": false,
		"emit": {"box": Vector2(20, 0.5)}}))
	emit(off_pit, HIT + 0.15, GONE - 0.1)
	key(off_pit, "position", surf_keys)
	key(off_pit, "process_material:emission_box_extents", box_keys)
	var smoke := particles("SteamAfter", wisp.merged({"at": Vector2(0, -1), "amount": 10, "lifetime": 0.6, "randomness": 0.3,
		"emitting": false, "emit": {"box": Vector2(21, 0.5)}}))
	emit(smoke, GONE - 0.2, D - 0.6)
