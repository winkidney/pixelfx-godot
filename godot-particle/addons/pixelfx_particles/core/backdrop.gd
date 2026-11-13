# The backdrops the original draws behind an effect in previews (src/core/scene.js): "dark", "ground" (a stone floor
# from groundY down), "sky" (a dithered night gradient with stars), "light" and "black". Same colours and floor
# pattern as the original; the stars fall in different places.
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


static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return float(h ^ (h >> 16)) / 4294967296.0


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
				c = SKY_TOP.lerp(SKY_LOW, minf(1.0, step / 4.0))
				var r := _hash(x, y)
				if r > 0.994:
					c = c.lerp(STAR, 0.35 + (r - 0.994) * 90.0)
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
