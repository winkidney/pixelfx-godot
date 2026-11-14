# Shared by the nature build scripts (not an effect): little textures drawn the way src/fx/nature/_lib.js draws its
# stones and leaves, made at build time and saved into the scene (no PNG to import), and the original's easings.
#   const N := preload("res://build/fx/nature/_lib.gd")
#   var tex := N.rock(7, 4.0, root.ramps.palette)
extends RefCounted


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


static func out_quad(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func in_out_quad(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0


static func out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


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


## A faceted stone (stoneShape + drawRock): corners round a centre, each facet lit by how squarely it faces the top
## left, a bright rim on lit edges, a dark rim round it. S: the stone ramp, dark to bright (7+ steps). white: flashed.
static func rock_image(seed_: int, s: float, S: PackedColorArray, white := false) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var n := rng.randi_range(5, 7)
	var a0 := rng.randf() * TAU
	var squash := rng.randf_range(0.7, 1.0)
	var V := PackedVector2Array()
	for i in n:
		var a := a0 + (i + rng.randf_range(-0.28, 0.28)) * TAU / n
		var r := rng.randf_range(0.72, 1.12)
		V.append(Vector2(cos(a) * r, sin(a) * r * squash) * s)
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
				var d := fposmod(g - ang[q], TAU)
				var span := fposmod(ang[(q + 1) % n] - ang[q], TAU)
				if d <= span:
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
	return img


static func rock(seed_: int, s: float, S: PackedColorArray, white := false) -> ImageTexture:
	return _tex(rock_image(seed_, s, S, white))


## A small shaded chunk (the core's B.CHUNK): a lozenge lit top-left, dark bottom-right, a dark rim. R dark..bright.
static func chunk(s: float, R: PackedColorArray, turn := 0.0) -> ImageTexture:
	var r := int(ceil(s)) + 1
	var img := Image.create(2 * r + 1, 2 * r + 1, false, Image.FORMAT_RGBA8)
	var n := R.size()
	var ca := cos(turn)
	var sa := sin(turn)
	for py in range(-r, r + 1):
		for px in range(-r, r + 1):
			var u := (px + 0.5) * ca + (py + 0.5) * sa
			var v := -(px + 0.5) * sa + (py + 0.5) * ca
			var d := absf(u) / s + absf(v) / (s * 0.62)
			if d > 1.3:
				continue
			var col: Color = R[0] if d > 1.0 else ((R[n - 1] if u < 0 else R[n - 2]) if v < 0 else (R[n - 3] if u < 0 else R[maxi(1, n - 4)]))
			img.set_pixel(px + r, py + r, col)
	return _tex(img)


## A leaf (drawLeaf) len px long, wid px across, lying along x, flipped about its midrib by fl (radians: the paler
## underside shows past pi/2). pal: [dark, shade, body, light].
static func leaf_image(length: float, wid: float, fl: float, pal: Array, ang := 0.0) -> Image:
	var ca := cos(ang)
	var sa := sin(ang)
	var sq := cos(fl)
	var w := maxf(0.55, absf(sq) * wid)
	var under := sq < 0.0
	var R := int(ceil(length / 2.0 + 2.0))
	var img := Image.create(2 * R + 1, 2 * R + 1, false, Image.FORMAT_RGBA8)
	var inside := func(i: int, j: int) -> int:
		var u := (i + 0.5) * ca + (j + 0.5) * sa + length / 2.0
		var v := -(i + 0.5) * sa + (j + 0.5) * ca
		if u < 0.0 or u > length:
			return 0
		var half := w * pow(sin(PI * u / length), 0.75)
		return (1 if v < 0.0 else 2) if absf(v) <= half else 0
	for j in range(-R, R + 1):
		for i in range(-R, R + 1):
			var s: int = inside.call(i, j)
			var col: Color
			if s == 0:
				if inside.call(i - 1, j) or inside.call(i + 1, j) or inside.call(i, j - 1) or inside.call(i, j + 1):
					col = Color(pal[0])
				else:
					continue
			else:
				var u := (i + 0.5) * ca + (j + 0.5) * sa + length / 2.0
				var v := -(i + 0.5) * sa + (j + 0.5) * ca
				var rib := absf(v) < 0.5 and u > length * 0.12 and u < length * 0.88 and w > 1.2
				col = Color(pal[1]) if rib else (Color(pal[3]) if (s == 1) != under else Color(pal[2]))
			img.set_pixel(i + R, j + R, col)
	var sx := int(roundf(-ca * (length / 2.0 + 1.0))) + R
	var sy := int(roundf(-sa * (length / 2.0 + 1.0))) + R
	if sx >= 0 and sy >= 0 and sx <= 2 * R and sy <= 2 * R:
		img.set_pixel(sx, sy, Color(pal[1]))
	return img


static func leaf(length: float, wid: float, fl: float, pal: Array, ang := 0.0) -> ImageTexture:
	return _tex(leaf_image(length, wid, fl, pal, ang))


## A strip of images side by side (for a Sprite2D with hframes, keyed frame by frame).
static func strip(images: Array) -> ImageTexture:
	var w := 0
	var h := 0
	for im in images:
		w = maxi(w, im.get_width())
		h = maxi(h, im.get_height())
	var out := Image.create(w * images.size(), h, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		out.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(i * w + (w - im.get_width()) / 2, (h - im.get_height()) / 2))
	return _tex(out)


## A pixel disc of radius r in one colour (for soft puffs drawn by the soft layer), optionally with a lit cap.
static func disc(r: float, c: Color) -> ImageTexture:
	var R := int(ceil(r))
	var img := Image.create(2 * R + 1, 2 * R + 1, false, Image.FORMAT_RGBA8)
	for j in range(-R, R + 1):
		for i in range(-R, R + 1):
			if Vector2(i, j).length() <= r:
				img.set_pixel(i + R, j + R, c)
	return _tex(img)


## Points round an ellipse (a ring on the floor drawn as a 1 px Line2D, which a squashed ring shader breaks up).
## keep: Callable(angle) -> bool picks which part (the far half: sin(a) < 0); the points run in order, gaps split it.
static func ellipse(c: Vector2, r: float, sy: float, n := 0) -> PackedVector2Array:
	var m := n if n > 0 else maxi(12, int(r * 1.2))
	var out := PackedVector2Array()
	for i in m + 1:
		var a := i / float(m) * TAU
		out.append(c + Vector2(cos(a) * r, sin(a) * r * sy))
	return out
