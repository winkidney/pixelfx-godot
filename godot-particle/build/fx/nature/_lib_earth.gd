# Shared by nature/earth-spike, nature/quake and nature/thorns (not an effect): the original's random looks for a stone
# spike (spikeLook, spikeCrack, floorCrack in src/fx/nature/_lib.js) and a faceted stone from given corners.
#   const E := preload("res://build/fx/nature/_lib_earth.gd")
extends RefCounted


## notches [{u, side, d}], strata [u], slope, seed
static func spike_look(rng: RandomNumberGenerator) -> Dictionary:
	var notches := []
	for i in rng.randi_range(3, 5):
		notches.append(Vector3(rng.randf_range(0.1, 0.8), -1.0 if rng.randf() < 0.5 else 1.0, rng.randf_range(0.8, 1.8)))
	var strata := PackedFloat32Array()
	for i in rng.randi_range(2, 4):
		strata.append(rng.randf_range(0.12, 0.8))
	return {"notches": notches, "strata": strata, "slope": rng.randf_range(-0.25, 0.25), "seed": float(rng.randi_range(1, 9999))}


## A crack branching up a spike: points (u: height 0..1, v: -1 left edge .. 1 right edge).
static func spike_crack(rng: RandomNumberGenerator, u0: float, v0: float, dir: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(u0, v0)])
	var u := u0
	var v := v0
	for i in 9:
		u += rng.randf_range(0.03, 0.08)
		v += dir * rng.randf_range(0.05, 0.28) + rng.randf_range(-0.12, 0.12)
		if u > 0.95 or absf(v) > 1.0:
			break
		pts.append(Vector2(u, v))
	return pts


## A jagged floor crack from x = 0 out to side * len: points (x, y), y 0..2 into the floor.
static func floor_crack(rng: RandomNumberGenerator, side: float, length: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var x := 0.0
	while absf(x) < length:
		x += side * rng.randf_range(2, 5)
		pts.append(Vector2(x, rng.randi_range(0, 2)))
	return pts


## The spike shader's uniforms for a look and its cracks.
static func spike_params(look: Dictionary, cracks: Array) -> Dictionary:
	var notches := []
	for i in 5:
		notches.append(look.notches[i] if i < look.notches.size() else Vector3.ZERO)
	var strata := PackedFloat32Array()
	for i in 4:
		strata.append(look.strata[i] if i < look.strata.size() else 0.0)
	var pts := PackedVector2Array()
	var lens := Vector3.ZERO
	for j in 3:
		var c: PackedVector2Array = cracks[j] if j < cracks.size() else PackedVector2Array()
		lens[j] = float(mini(10, c.size()))
		for k in 10:
			pts.append(c[k] if k < c.size() else Vector2.ZERO)
	return {"notches": notches, "notch_count": float(look.notches.size()), "strata": strata,
		"strata_count": float(look.strata.size()), "slope": look.slope, "look_seed": look.seed, "crack_pts": pts, "crack_len": lens}


static func _in_poly(v: PackedVector2Array, x: float, y: float) -> bool:
	var inside := false
	var j := v.size() - 1
	for i in v.size():
		var a := v[i]
		var b := v[j]
		if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


## drawRock for given unit corners `pts`, scaled by s and turned by a. S: the stone ramp (dark..bright, 8 steps).
static func rock_from(pts: Array, s: float, a: float, S: PackedColorArray, white := false) -> ImageTexture:
	var ca := cos(a)
	var sa := sin(a)
	var V := PackedVector2Array()
	for p in pts:
		V.append(Vector2((p[0] * ca - p[1] * sa) * s, (p[0] * sa + p[1] * ca) * s))
	var n := V.size()
	var ang := PackedFloat32Array()
	for p in V:
		ang.append(atan2(p.y, p.x))
	var lit := PackedFloat32Array()
	for i in n:
		var A := V[i]
		var B := V[(i + 1) % n]
		var e := B - A
		var l := maxf(e.length(), 1e-3)
		var nn := Vector2(e.y / l, -e.x / l)
		if nn.dot(A + B) < 0.0:
			nn = -nn
		lit.append(nn.x * -0.6 + nn.y * -0.8)
	var N := 2 * int(ceil(s * 1.25)) + 3
	var c := N / 2.0
	var img := Image.create(N + 2, N + 2, false, Image.FORMAT_RGBA8)
	var mask := {}
	var face := {}
	for j in N:
		for i in N:
			var dx := i + 0.5 - c
			var dy := j + 0.5 - c
			if not _in_poly(V, dx, dy):
				continue
			mask[Vector2i(i, j)] = true
			var g := atan2(dy, dx)
			var f := 0
			for q in n:
				if fposmod(g - ang[q], TAU) <= fposmod(ang[(q + 1) % n] - ang[q], TAU):
					f = q
					break
			face[Vector2i(i, j)] = f
	var top := S.size() - 2
	for j in range(-1, N + 1):
		for i in range(-1, N + 1):
			var k := Vector2i(i, j)
			var col: Color
			if not mask.has(k):
				if mask.has(k + Vector2i(1, 0)) or mask.has(k - Vector2i(1, 0)) or mask.has(k + Vector2i(0, 1)) or mask.has(k - Vector2i(0, 1)):
					col = S[0]
				else:
					continue
			elif white:
				col = Color.WHITE
			else:
				var L: float = lit[face[k]]
				var edge: bool = not (mask.has(k + Vector2i(1, 0)) and mask.has(k - Vector2i(1, 0)) and mask.has(k + Vector2i(0, 1)) and mask.has(k - Vector2i(0, 1)))
				col = S[top] if L > 0.55 else S[top - 1] if L > 0.15 else S[top - 2] if L > -0.3 else S[top - 3]
				if edge:
					col = S[top + 1] if L > 0.3 else S[maxi(1, top - 4)] if L < -0.2 else col
			img.set_pixel(i + 1, j + 1, col)
	return ImageTexture.create_from_image(img)
