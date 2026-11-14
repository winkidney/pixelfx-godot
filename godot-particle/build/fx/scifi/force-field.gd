# reimagined-from: src/fx/scifi/force-field.js@2297fe09c7ab0673a0b21af19301730e2eb85acd
# Force field: A glassy dome of hex plates over the hero: plates glint, tracers from the right slam into it, a ripple and cracks of light race across, sparks glance off.
# loop, 2.40 s, 184x104 canvas, origin [76.0, 84.0], backdrop ground, stand-in 2
# The dome's shell is worked out here pixel by pixel as the original's shell() does (where each pixel sits on the
# sphere and on the hex plates, seams, lit edges, when its plate glints) into data textures; shaders keyed by the
# loop clock light it each frame (fx/scifi/_force_field.gdshader: the far side through the glass behind the stand-in,
# the near side in front, with the ripples racing out from each hit, the struck plates, the scan band; then the
# fractures along the original's own bolt paths over the sphere, the tracers, the impact stars). The foot's ring is
# the original's band() laid down here as dots; its light is _force_field_light.gdshader. What the shots throw off
# (sparks glancing off, motes, stars, smoke) and the glint on each plate are the original's own Ghosts.
extends "res://build/fx/scifi/_scifi.gd"

const S3 := 1.7320508075688772
const SA := 0.13
const G := 6.3
const KY := 1.12
const SHOTS := [[0.42, 0.66, 0.62, true], [1.5, 0.95, 0.26, false]]

var CA := sqrt(1.0 - SA * SA)


func cell(gx: float, gy: float) -> Dictionary:
	var fq := (S3 / 3.0) * gx - gy / 3.0
	var fr := (2.0 / 3.0) * gy
	var fs := -fq - fr
	var q := floorf(fq + 0.5)
	var r := floorf(fr + 0.5)
	var s := floorf(fs + 0.5)
	var dq := absf(q - fq)
	var dr := absf(r - fr)
	var ds := absf(s - fs)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	var hx := S3 * (q + r / 2.0)
	var hy := 1.5 * r
	var dx := gx - hx
	var dy := gy - hy
	var ax := absf(dx)
	var e := maxf(ax, maxf(absf(ax / 2.0 + (dy * S3) / 2.0), absf(ax / 2.0 - (dy * S3) / 2.0))) / (S3 / 2.0)
	var k := floorf((atan2(dy, dx) - PI / 6.0) / (PI / 3.0) + 0.5)
	var ca := PI / 6.0 + (k * PI) / 3.0
	return {"q": int(q), "r": int(r), "e": e, "corner": Vector2(dx - cos(ca), dy - sin(ca)).length()}


func project(R: float, lon: float, lat: float) -> Vector3:
	var X := cos(lat) * sin(lon)
	var Y := sin(lat)
	var Z := cos(lat) * cos(lon)
	return Vector3(R * X, -R * (Y * CA - Z * SA), Y * SA + Z * CA)


static func glints(S: int, q: int, r: int) -> bool:
	return rand([S, q, r, 3]) < 0.2


static func glint_at(S: int, q: int, r: int) -> float:
	var g := rand([S, q, r]) * 1.7
	return 1.0 + g if g < 1.4 else g - 1.4


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var R: float = meta.options.radius
	var SP: PackedColorArray = fit(root.ramps.sparks, 4)
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var WR: float = meta.size[0] - meta.origin[0]

	# the shell, every pixel of its near and far side, as the original's shell() lays it out
	var N := int(ceil(R)) + 1
	var Wd := 2 * N + 1
	var Hh := 53
	var ims := [Image.create(Wd, Hh * 3, false, Image.FORMAT_RGBAF), Image.create(Wd, Hh * 3, false, Image.FORMAT_RGBAF)]
	for im in ims:
		for y in Hh:
			for x in Wd:
				im.set_pixel(x, y + 2 * Hh, Color(-1, 0, 0, -1))
	var ids := [{}, {}]
	var lists := [[], []]
	for y in range(-N, int(ceil(R * SA)) + 2):
		for x in range(-N, N + 1):
			var u := (x + 0.5) / R
			var vy := -(y + 0.5) / R
			var qq := u * u + vy * vy
			if qq > 1.0:
				continue
			var vz := sqrt(1.0 - qq)
			for si in 2:
				var s := 1.0 if si == 0 else -1.0
				var Y := vy * CA + s * vz * SA
				var Z := -vy * SA + s * vz * CA
				if Y < 0.0:
					continue
				var lon := atan2(u, Z)
				var lat := asin(minf(1.0, Y))
				var c := cell(lon * G, lat * G * KY)
				var id: int = c.q * 1000 + c.r
				lists[si].append({"x": x, "y": y, "X": u, "Y": Y, "Z": Z, "lon": lon, "lat": lat, "q": c.q, "r": c.r, "id": id, "e": c.e,
					"corner": c.corner, "rim": 1.0 - vz, "sil": (1.0 - sqrt(qq)) * R})
				ids[si][Vector2i(x, y)] = id
	for si in 2:
		for p in lists[si]:
			var rt: Variant = ids[si].get(Vector2i(p.x + 1, p.y))
			var dn: Variant = ids[si].get(Vector2i(p.x, p.y + 1))
			var lf: Variant = ids[si].get(Vector2i(p.x - 1, p.y))
			var up: Variant = ids[si].get(Vector2i(p.x, p.y - 1))
			var seam: bool = (rt != null and rt != p.id) or (dn != null and dn != p.id)
			var bevel: bool = not seam and ((lf != null and lf != p.id) or (up != null and up != p.id))
			var gx: int = p.x + N
			var gy: int = p.y + N
			var ga := glint_at(S, p.q, p.r) if glints(S, p.q, p.r) else -1.0
			ims[si].set_pixel(gx, gy, Color(p.X, p.Y, p.Z, p.lat))
			ims[si].set_pixel(gx, gy + Hh, Color(p.lon, p.e, p.corner, p.rim))
			ims[si].set_pixel(gx, gy + 2 * Hh, Color(p.sil, 1.0 if seam else 0.0, 1.0 if bevel else 0.0, ga))
	var near_t := asset("_near", ims[0])
	var far_t := asset("_far", ims[1])

	# the fractures of the big hit: jagged forked paths over the sphere (the original's cracks())
	var segs := []
	var rn := JsRng.new(S * 13 + 5)
	var s0: Array = SHOTS[0]
	var paths := []
	var to_screen := func(path: PackedVector2Array, u0: float, u1: float) -> Array:
		var pts := []
		for i in path.size():
			var lon: float = path[i].x
			var lat: float = path[i].y
			if lat < 0.03 or lat > 1.52 or absf(lon) > 1.5:
				break
			var pr := project(R, lon, lat)
			pts.append([pr.x, pr.y, pr.z, u0 + ((u1 - u0) * i) / (path.size() - 1)])
		return pts
	for i in 5:
		var a := (i / 5.0) * TAU + rn.range(-0.35, 0.35)
		var L := rn.range(0.42, 0.8)
		var path := bolt_path(rn, s0[1], s0[2], s0[1] + (cos(a) * L) / cos(s0[2]), s0[2] + sin(a) * L, 0.2, 4)
		paths.append(to_screen.call(path, 0.0, 1.0))
		var cnt := rn.int_(0, 2)
		for f in fork_paths(rn, path, cnt, L * 0.5, 0.25, 0.9):
			var j := -1
			for k in path.size():
				if path[k].x == f[0].x and path[k].y == f[0].y:
					j = k
					break
			var u0 := maxi(0, j) / float(path.size() - 1)
			paths.append(to_screen.call(f, u0, u0 + 0.5))
	for c in paths:
		for i in range(1, c.size()):
			segs.append([c[i - 1], c[i], i % 3 == 0])
	var cimg := Image.create(maxi(1, segs.size()), 2, false, Image.FORMAT_RGBAF)
	for i in segs.size():
		var a: Array = segs[i][0]
		var b: Array = segs[i][1]
		cimg.set_pixel(i, 0, Color(a[0], a[1], b[0], b[1]))
		cimg.set_pixel(i, 1, Color(a[2], b[2], b[3], 1.0 if segs[i][2] else 0.0))
	var crack_t := asset("_cracks", cimg)

	var pool := PackedFloat32Array()
	var px := -R
	while px <= R and pool.size() < 7:
		pool.append(px)
		px += R / 3.0
	while pool.size() < 7:
		pool.append(-1000.0)
	var base := {"t": 0.0, "near": near_t, "far": far_t, "cracks": crack_t, "crack_count": segs.size(), "pal": C, "sparks": SP, "right_edge": WR - 3.0}

	# behind the stand-in: the pool of light, the foot's far half, the far shell
	var lb := {"t": 0.0, "mode": 0, "near": near_t, "far": far_t, "cracks": crack_t, "crack_count": segs.size(), "pal": C, "sparks": SP, "pool_x": pool}
	var back_light := shape("PoolLight", sh("force_field_light"), canvas, lb, {"at": mid})
	var ramp := [C[1], C[3], C[5], C[6]]
	dots_sprite("FootFar", band_dots(0, 0, R + 1, SA, 2, 1, ramp, func(g: float) -> bool: return sin(g) < 0.0), {"back": true})
	var m0 := base.duplicate()
	m0.mode = 0
	var far_shell := shape("FarShell", sh("force_field"), canvas, m0, {"at": mid, "back": true})
	# in front: the near shell, the foot's near half, the shots
	var m1 := base.duplicate()
	m1.mode = 1
	var near_shell := shape("NearShell", sh("force_field"), canvas, m1, {"at": mid})
	dots_sprite("FootNear", band_dots(0, 0, R + 1, SA, 2, 1, ramp, func(g: float) -> bool: return sin(g) >= 0.0))
	var m2 := base.duplicate()
	m2.mode = 2
	var shots := shape("Shots", sh("force_field"), canvas, m2, {"at": mid})

	# what the shots throw off and the glints on the plates, born once a loop
	ghosts_begin(D)
	var g := JsRng.new(S)
	for sh_ in SHOTS:
		var h := project(R, sh_[1], sh_[2])
		var n := 1.0 if sh_[3] else 0.55
		var i := 0
		while i < 24.0 * n:
			var a: float = (-0.9 if sh_[3] else -0.55) + g.range(-0.7, 0.65)
			var sp := g.range(100, 280) * (0.7 + 0.3 * n)
			var born: float = sh_[0] + g.range(0, 0.02)
			ghost(born, SPARK, h.x, h.y, cos(a) * sp, sin(a) * sp - 30.0, g.range(0.25, 0.75))
			i += 1
		i = 0
		while i < 7.0 * n:
			var a := -0.9 + g.range(-1.2, 1.2)
			var sp := g.range(30, 90)
			var born: float = sh_[0] + g.range(0, 0.05)
			var life := g.range(0.3, 0.6)
			ghost(born, MOTE, h.x, h.y, cos(a) * sp, sin(a) * sp - 15.0, life, g.pick([C[5], C[6], C[4]]), 0.7)
			i += 1
		i = 0
		while i < 3.0 * n:
			var x := h.x + g.range(-6, 6)
			var y := h.y + g.range(-5, 5)
			var life := g.range(0.3, 0.5)
			ghost(sh_[0] + 0.04 + i * 0.07, STAR, x, y, 0, -4, life, C[6], g.range(1, 2))
			i += 1
		i = 0
		while i < 3.0 * n:
			var x := h.x + 2.0 + g.range(-2, 2)
			var vx := g.range(8, 22)
			var vy := g.range(-14, -4)
			var life := g.range(0.9, 1.3)
			ghost(sh_[0] + 0.03 + i * 0.04, SMOKE, x, h.y - 1.0, vx, vy, life, Color("#5b5f78"), g.range(2.2, 3.4))
			i += 1
	for r in 12:
		for q in range(-14, 15):
			if not glints(S, q, r):
				continue
			var lon := (S3 * (q + r / 2.0)) / G
			var lat := (1.5 * r) / (G * KY)
			var pr := project(R, lon, lat)
			if pr.z < 0.25 or lat < 0.15 or lat > 1.45 or absf(lon) > 1.3:
				continue
			ghost(glint_at(S, q, r) + 0.03, STAR, pr.x, pr.y, 0, -3, 0.4, C[6], 1.4 + rand([q, r, 9]))
	ghosts({"sparks": SP, "floor": 0.0, "box": [-70, -80, WR - 6.0, 14], "back": false})

	var lf := lb.duplicate()
	lf.mode = 1
	var front_light := shape("Light", sh("force_field_light"), canvas, lf, {"at": mid})
	for n in [back_light, far_shell, near_shell, shots, front_light]:
		clock(n)
