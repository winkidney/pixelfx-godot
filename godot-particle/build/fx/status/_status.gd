# Shared by the status build scripts (not an effect: ./pfxp only builds ids it finds in port/meta.json).
# The stand-in's shape as the originals' src/fx/status/_lib.js sees it (body, edges, rows, eyes, colours, in mask
# space: 0, 0 = its top-left, which sits at AX, AY from the feet), the originals' little maths (rand, Rng, cycle,
# travel, smooth, ease), their shaded outlined icons (bitmap, shaped, heart, star -> an Image you put on a Sprite2D
# or a strip of frames), the sparkle cross as a keyed shader, and frame-by-frame key sampling.
extends "res://addons/pixelfx_particles/core/build.gd"

const FPS := 30.0
const STATUS := "res://addons/pixelfx_particles/fx/status/"
## the originals' dark ink (0xff1f1726): brows, shut lids
const INK := Color("#1f1726")
const WHITE := Color(1, 1, 1, 1)

## the stand-in's mask: w x h, its top-left at (AX, AY) from the feet (the original's a.x, a.y)
var AW := 24
var AH := 38
var AX := -12
var AY := -38
var _img: Image
var _shape := {}


func begin(effect_id: String) -> void:
	super(effect_id)
	_img = load(EFFECT.STAND_INS[maxi(1, root.actor)]).get_image()
	AW = _img.get_width()
	AH = _img.get_height()
	AX = -int(floorf(AW / 2.0))
	AY = -AH


## fit(ramp, n) of the original: the option `name` resampled to n steps, ends kept.
func fit(name: String, n: int) -> PackedColorArray:
	var r: PackedColorArray = root.ramps[name]
	var out := PackedColorArray()
	for i in n:
		out.append(r[int(roundf(i * (r.size() - 1) / float(maxi(1, n - 1))))])
	return out


# ------------------------------------------------------------------ maths from the originals

static func clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var u := x - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u


## JS Math.round (halves go up, also below zero)
static func jround(x: float) -> float:
	return floorf(x + 0.5)


## JS ((a % b) + b) % b
static func wrapf(a: float, b: float) -> float:
	return fposmod(a, b)


## How far something has moved after age a, launched at v under acceleration g with linear drag d (_lib.js travel).
static func travel(v: float, g: float, d: float, a: float) -> float:
	if d > 0.0:
		return (g / d) * a + ((v - g / d) * (1.0 - exp(-d * a))) / d
	return v * a + 0.5 * g * a * a


static func imul(a: int, b: int) -> int:
	a &= 0xffffffff
	b &= 0xffffffff
	return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


## The originals' hash(...ns) as an unsigned 32-bit int, bit for bit.
static func jhash(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		h = imul(h ^ (int(n) & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & 0xffffffff


## The originals' rand(...ns): [0, 1), bit for bit.
static func jrand(ns: Array) -> float:
	return jhash(ns) / 4294967296.0


## The originals' seeded generator (mulberry32), bit for bit: rng([seed, i]) is their rng(seed, i).
class Rng:
	var s := 1

	func _init(seed_: int) -> void:
		s = seed_ & 0xffffffff
		if s == 0:
			s = 1

	static func _m(a: int, b: int) -> int:
		a &= 0xffffffff
		b &= 0xffffffff
		return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = _m(t ^ (t >> 15), t | 1)
		t = (t ^ ((t + _m(t ^ (t >> 7), t | 61)) & 0xffffffff)) & 0xffffffff
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	func integer(a: int, b: int) -> int:
		return int(floorf(self.range(a, b + 1)))

	func chance(p: float) -> bool:
		return next() < p

	func sgn() -> float:
		return -1.0 if next() < 0.5 else 1.0

	func pick(list: Array) -> Variant:
		return list[int(floorf(next() * list.size()))]


static func rng(ns: Array) -> Rng:
	return Rng.new(jhash(ns))


## The originals' cycle(): count particles repeating every `period` s, each born at its own phase and living
## `life` s (a number, or a Callable(Rng) -> float). fn(age, life, r: Rng, i) for every live copy at t.
static func cycle(t: float, period: float, count: int, seed_: int, life: Variant, fn: Callable) -> void:
	for i in count:
		var g := rng([seed_, i, 911])
		var born := g.next() * period
		var L: float = life.call(g) if life is Callable else float(life)
		var age := fposmod(t - born, period)
		while age < L:
			fn.call(age, L, rng([seed_, i]), i)
			age += period


## The frame times the renderer samples, 0 .. duration (both ends: a loop's last key equals its first).
func frame_times(hz := FPS) -> Array:
	var out := []
	var n := int(roundf(root.duration * hz))
	for i in n + 1:
		out.append(i / hz)
	return out


## Key node.prop from fn(t) at every frame time (the original's formula where the renderer samples it).
func sample(node: Node, prop: String, fn: Callable, interp := "nearest", hz := FPS) -> void:
	var keys := []
	for t in frame_times(hz):
		keys.append([t, fn.call(t)])
	key(node, prop, keys, interp)


# ------------------------------------------------------------------ the stand-in (mask space)

func on(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < AW and y < AH and _img.get_pixel(x, y).a >= 0.5


## its own colour at mask pixel (x, y) (transparent off it)
func col_at(x: int, y: int) -> Color:
	return _img.get_pixel(x, y) if on(x, y) else Color(0, 0, 0, 0)


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## where mask pixel (x, y) sits, from the feet (its top-left corner)
func apos(x: float, y: float) -> Vector2:
	return Vector2(AX + x, AY + y)


## _lib.js shape(a): body [Vector2i...] (row by row), up (nothing above), side [[x, y, dir]...] (open to the left -1
## or right 1), rows [[l, r]...] per row, top (each column's first row, -1 if empty), outline [[x, y, nx, ny]...].
func shape_of() -> Dictionary:
	if not _shape.is_empty():
		return _shape
	var body := []
	var up := []
	var side := []
	var rows := []
	var top := []
	var outline := []
	for x in AW:
		var y := 0
		while y < AH and not on(x, y):
			y += 1
		top.append(y if y < AH else -1)
	for y in AH:
		var l := -1
		var r := -1
		for x in AW:
			if not on(x, y):
				continue
			if l < 0:
				l = x
			r = x
			body.append(Vector2i(x, y))
			if not on(x, y - 1):
				up.append(Vector2i(x, y))
			if not on(x - 1, y):
				side.append([x, y, -1])
			if not on(x + 1, y):
				side.append([x, y, 1])
		rows.append([l, r])
	for y in range(-1, AH + 1):
		for x in range(-1, AW + 1):
			if on(x, y):
				continue
			var nx := 0.0
			var ny := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if on(x + dx, y + dy):
						nx -= dx
						ny -= dy
			if on(x - 1, y) or on(x + 1, y) or on(x, y - 1) or on(x, y + 1):
				var l := Vector2(nx, ny).length()
				if l == 0.0:
					l = 1.0
				outline.append([x, y, nx / l, ny / l])
	_shape = {"body": body, "up": up, "side": side, "rows": rows, "top": top, "outline": outline, "w": AW, "h": AH}
	return _shape


## _lib.js eyes(a): the knight stand-in (2) says where its eyes go: [{x0, x1, y0, y1, px: [Vector2i...], skin}].
func eyes() -> Array:
	var out := []
	if root.actor == 2:
		for e in [[13, 3], [15, 3]]:
			out.append({"x0": e[0], "x1": e[0], "y0": e[1], "y1": e[1] + 1,
				"px": [Vector2i(e[0], e[1]), Vector2i(e[0], e[1] + 1)], "skin": col_at(e[0], e[1])})
	return out


## The 1 px ring just outside the stand-in as an image (margin 1, white unless col says), for after-images and auras;
## col: Callable(mx, my) -> Color (alpha 0 skips) or a Color.
func outline_image(col: Variant = Color.WHITE) -> Image:
	var out := Image.create(AW + 2, AH + 2, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in range(-1, AH + 1):
		for x in range(-1, AW + 1):
			if not on(x, y) and (on(x - 1, y) or on(x + 1, y) or on(x, y - 1) or on(x, y + 1)):
				var c: Color = col.call(x, y) if col is Callable else col
				if c.a > 0.0:
					out.set_pixel(x + 1, y + 1, c)
	return out


## An image in mask space (w x h, or with a margin m all round) on a Sprite2D over the stand-in, pixel for pixel.
## o: layer, back, name of the asset file (file), parent.
func body_sprite(name: String, img: Image, m := 0, o: Dictionary = {}) -> Sprite2D:
	var oo := {"centered": false, "at": Vector2(AX - m, AY - m)}
	oo.merge(o, true)
	return sprite(name, asset(o.get("file", "_" + name.to_lower()), img), oo)


## Pixels {Vector2i(x, y) (from the feet): Color} as a Sprite2D: the originals' p.px / p.dot for a still mark.
func pixels(name: String, px: Dictionary, o: Dictionary = {}) -> Sprite2D:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for q in px:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var img := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for q in px:
		var c: Color = px[q]
		img.set_pixel(q.x - lo.x, q.y - lo.y, c)
		if o.get("layer", "color") != "light":
			keep_colour(c)
	var oo := {"at": Vector2(lo), "centered": false}
	oo.merge(o, true)
	return sprite(name, asset(o.get("file", "_" + name.to_lower()), img), oo)


# ------------------------------------------------------------------ icons (_lib.js bitmap, shaped, icon)

## inside(dx, dy) -> String for a bitmap (rows of strings, "." empty) centred on (0, 0), scaled by whole k.
static func bitmap(rows: Array, k := 1, flip := false) -> Callable:
	var h := rows.size()
	var w := String(rows[0]).length()
	var ox := int(floorf(w * k / 2.0))
	var oy := int(floorf(h * k / 2.0))
	return func(dx: int, dy: int) -> String:
		var bx := int(floorf(float(dx + ox) / k))
		var by := int(floorf(float(dy + oy) / k))
		if bx < 0 or by < 0 or bx >= w or by >= h:
			return ""
		if flip:
			bx = w - 1 - bx
		var c := String(rows[by])[bx]
		return "" if c == "." else c


## inside(dx, dy) for a shape f(u, v) -> bool in its own unit space, rotated by ang and scaled by s px.
static func shaped(f: Callable, s: float, ang := 0.0) -> Callable:
	var c := cos(ang)
	var n := sin(ang)
	return func(dx: int, dy: int) -> String:
		var x := dx + 0.5
		var y := dy + 0.5
		return "#" if f.call((x * c + y * n) / s, (-x * n + y * c) / s) else ""


## A heart in unit space (two lobes and a point, about 2 x 2, centred).
static func heart_shape(u: float, v: float) -> bool:
	return (u + 0.5) ** 2 + (v + 0.32) ** 2 <= 0.55 ** 2 or (u - 0.5) ** 2 + (v + 0.32) ** 2 <= 0.55 ** 2 \
		or (v >= -0.32 and v <= 1.0 and absf(u) <= 1.04 * pow(1.0 - (v + 0.32) / 1.32, 0.75))


## A five-pointed star in unit space (points at radius 1, inner corners at r0).
static func star_shape(r0 := 0.45) -> Callable:
	return func(u: float, v: float) -> bool:
		var a := atan2(v, u) + PI / 2.0
		var d := Vector2(u, v).length()
		var sg := TAU / 5.0
		var k := 1.0 - absf(fposmod(a, sg) - sg / 2.0) / (sg / 2.0)
		return d <= 1.0 - (1.0 - r0) * pow(k, 0.8)


## The originals' icon(): every cell where inside(dx, dy) is non-empty within ext (+1) of the centre, from
## R = [outline, shadow, body, light] (lit top and left, shaded bottom and right, ringed by the outline; an outline
## with alpha 0 or null: none), recoloured where inside returns a character in paint ({"e": Color}). The image is
## (2 ext + 3) square with the centre at (ext + 1, ext + 1).
static func icon_image(inside: Callable, ext: int, R: Array, paint: Dictionary = {}) -> Image:
	var n := 2 * ext + 3
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ring_on: bool = R[0] != null and (R[0] as Color).a > 0.0
	for dy in range(-ext - 1, ext + 2):
		for dx in range(-ext - 1, ext + 2):
			var ch: String = inside.call(dx, dy)
			var c := Color(0, 0, 0, 0)
			if ch != "":
				if paint.has(ch):
					c = paint[ch]
				else:
					var top: bool = inside.call(dx, dy - 1) == ""
					var left: bool = inside.call(dx - 1, dy) == ""
					var bottom: bool = inside.call(dx, dy + 1) == ""
					var right: bool = inside.call(dx + 1, dy) == ""
					c = R[3] if (top or left) else (R[1] if (bottom or right) else R[2])
			elif ring_on and (inside.call(dx - 1, dy) != "" or inside.call(dx + 1, dy) != "" or inside.call(dx, dy - 1) != "" or inside.call(dx, dy + 1) != ""):
				c = R[0]
			else:
				continue
			img.set_pixel(dx + ext + 1, dy + ext + 1, c)
	return img


## Keep every opaque colour of an image out of the palette snap.
func keep_image_colours(img: Image) -> void:
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				var o := Color(c.r, c.g, c.b, 1.0)
				if not seen.has(o):
					seen[o] = true
					keep_colour(o)


## One icon image (from icon_image) on a Sprite2D whose position is the icon's centre pixel (the original's
## Math.round(x), Math.round(y)). o: at, layer, back, parent, file.
func icon_sprite(name: String, img: Image, o: Dictionary = {}) -> Sprite2D:
	return icon_strip(name, [img], o)


## Several icon images (odd squares, any sizes) as frames of one Sprite2D, each centred on the same pixel: key
## `frame` to pick one (an icon that grows, spins, flaps). o as icon_sprite.
func icon_strip(name: String, imgs: Array, o: Dictionary = {}) -> Sprite2D:
	var N := 1
	for im in imgs:
		N = maxi(N, (im as Image).get_width())
	var strip := Image.create(N * imgs.size(), N, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in imgs.size():
		var im: Image = imgs[i]
		var d := (N - im.get_width()) / 2
		strip.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(i * N + d, d))
	if o.get("layer", "color") != "light":
		keep_image_colours(strip)
	var oo := {"centered": false, "hframes": imgs.size()}
	oo.merge(o, true)
	var s := sprite(name, asset(o.get("file", "_" + name.to_lower()), strip), oo)
	s.offset = -Vector2((N - 1) / 2, (N - 1) / 2)
	return s


# ------------------------------------------------------------------ sparkles

## The originals' sparkle(): a cross keyed by `arm` (0 hides it; fx/status/_sparkle.gdshader) and, unless
## o.glow is false, its glow (4 + 2 arm px, light layer). Returns [cross, glow or null]; key with sparkle_keys().
## o: at, back, color, tip, size (odd), reach, glow.
func sparkle(name: String, o: Dictionary = {}) -> Array:
	var col: Color = o.get("color", WHITE)
	var tip: Color = o.get("tip", col)
	var sz: float = o.get("size", 15)
	var s := shape(name, load(STATUS + "_sparkle.gdshader"), Vector2(sz, sz),
		{"arm": 0.0, "color": col, "tip": tip, "heart": WHITE}, {"at": o.get("at", Vector2(0.5, 0.5)), "back": o.get("back", false)})
	keep_colour(WHITE)
	var g: ColorRect = null
	if o.get("glow", true):
		g = glow(name + "Glow", float(o.get("reach", 18)), {"radius": 6.0, "color": col, "alpha": 0.0},
			{"at": o.get("at", Vector2(0.5, 0.5)), "back": o.get("back", false)})
	return [s, g]


## keys: [[t, position, arm, glow alpha], ...] (arm < 1 hides it). Positions snap to the original's pixel.
func sparkle_keys(sp: Array, keys: Array) -> void:
	var pos := []
	var arm := []
	var rad := []
	var al := []
	for k in keys:
		var n := jround(float(k[2]))
		var p: Vector2 = k[1]
		var c := p.floor() + Vector2(0.5, 0.5)
		pos.append([k[0], c])
		arm.append([k[0], n])
		rad.append([k[0], 4.0 + 2.0 * n])
		al.append([k[0], float(k[3]) if n >= 1.0 else 0.0])
	key(sp[0], "position", pos, "nearest")
	key(sp[0], "material:shader_parameter/arm", arm, "nearest")
	if sp[1] != null:
		key(sp[1], "position", pos, "nearest")
		key(sp[1], "material:shader_parameter/radius", rad, "nearest")
		key(sp[1], "material:shader_parameter/alpha", al, "nearest")
