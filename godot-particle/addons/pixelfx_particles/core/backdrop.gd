# The backdrops the original draws behind an effect in previews (src/core/scene.js): "dark", "ground" (a stone floor
# from groundY down), "sky" (a dithered night gradient with stars), "light" and "black". Pixel for pixel the
# original's, stars included (its hash and colour mix, ported exactly), so a render compares against the reference
# on the same backdrop.
extends RefCounted

const SKY := Color("#15131d")
const SKY_TOP := Color("#0d0b14")
const SKY_LOW := Color("#221d33")
const FLOOR_EDGE := Color("#4a4263")
const FLOOR := Color("#2b2639")
const FLOOR_DARK := Color("#211d2d")
const MORTAR := Color("#1a1724")
const STAR := Color("#cfc8ff")
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


const M32 := 0xFFFFFFFF


## The original's 32-bit hash step (src/core/math.js), on unsigned ints.
static func _mix(h: int, u: int) -> int:
	var x := h ^ (u & M32)
	h = ((x * 0xca6b) + (((x * 0x85eb) & 0xFFFF) << 16)) & M32
	h ^= h >> 13
	h = ((h * 0xae35) + (((h * 0xc2b2) & 0xFFFF) << 16)) & M32
	h ^= h >> 16
	return h


## rand(x, y, z) in [0, 1), as the original's.
static func _rand(x: int, y: int, z: int) -> float:
	return _mix(_mix(_mix(0x9e3779b9, x), y), z) / 4294967296.0


## The original's mix(a, b, t) on 8-bit channels: truncated, as its rgb() does.
static func _mix_c(a: Color, b: Color, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	return Color8(int(a.r8 + (b.r8 - a.r8) * t), int(a.g8 + (b.g8 - a.g8) * t), int(a.b8 + (b.b8 - a.b8) * t))


## A w x h backdrop of the given kind; groundY is where the floor starts (the effect's origin, usually).
static func image(kind: String, w: int, h: int, groundY: float = -1.0) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	if kind == "none":
		return img
	if kind == "light":
		img.fill(Color("#ebe8f0"))
		return img
	if kind == "black":
		img.fill(Color.BLACK)
		return img
	var gY := float(h) if groundY < 0.0 else groundY
	for y in h:
		for x in w:
			var c := SKY
			if kind == "sky":
				var t := y / float(maxi(1, h - 1))
				var step := int(t * 5.0 + BAYER[((y & 3) << 2) | (x & 3)] / 16.0)
				c = _mix_c(SKY_TOP, SKY_LOW, minf(1.0, step / 4.0))
				var r := _rand(x, y, 77)
				if r > 0.994:
					c = _mix_c(c, STAR, 0.35 + (r - 0.994) * 90.0)
			if kind == "ground" and y >= gY:
				var gy := y - int(gY)
				if gy == 0:
					c = FLOOR_EDGE
				else:
					var row := floori((gy - 1) / 5.0)
					var off := 6 if row % 2 else 0
					var mortar := (gy - 1) % 5 == 4 or (x + off) % 12 == 0
					c = MORTAR if mortar else (FLOOR if gy < 3 else FLOOR_DARK)
			img.set_pixel(x, y, c)
	return img


static func texture(kind: String, w: int, h: int, groundY: float = -1.0) -> ImageTexture:
	return ImageTexture.create_from_image(image(kind, w, h, groundY))
