@tool
extends Node2D
## A word in the original's pixel fonts ("mini" 3x5, "big" 5x7), drawn as the original's UI words are (ui/_lib.js
## drawWord): scaled by sx / sy pixel by pixel (fractional scales squash cleanly), slanted, filled with a vertical
## ramp, bevelled (a lit top edge, a shaded underside, a lit left side) on flat edges, outlined and shadowed, and
## flashed white. Change `text` and it redraws: damage numbers, COMBO, LEVEL UP. Its origin is the word's bottom
## middle (where a number lands).

const PFont := preload("pixel_font.gd")

@export var text := "":
	set(v):
		text = v
		queue_redraw()
@export_enum("mini", "big") var font := "big":
	set(v):
		font = v
		queue_redraw()
## Scale of a font pixel across and down (2 is double size; fractions squash and stretch).
@export var sx := 1.0:
	set(v):
		sx = v
		queue_redraw()
@export var sy := 1.0:
	set(v):
		sy = v
		queue_redraw()
## Italic: px across per px up.
@export var slant := 0.0:
	set(v):
		slant = v
		queue_redraw()
## The fill, bottom row to top row (a single colour is a flat fill).
@export var fill := PackedColorArray([Color.WHITE]):
	set(v):
		fill = v
		queue_redraw()
## Bevel colours (alpha 0: the fill's top / bottom colour).
@export var edge := Color(0, 0, 0, 0):
	set(v):
		edge = v
		queue_redraw()
@export var under := Color(0, 0, 0, 0):
	set(v):
		under = v
		queue_redraw()
## Outline round every letter, and a shadow below and right of it (alpha 0: none).
@export var outline := Color(0, 0, 0, 0):
	set(v):
		outline = v
		queue_redraw()
@export var shadow := Color(0, 0, 0, 0):
	set(v):
		shadow = v
		queue_redraw()
## 0..1: white all over above 0.6, its lower half above 0.25 (the original's hit flash).
@export var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()


## The word's size in px at the current scale.
func size() -> Vector2:
	return Vector2(PFont.textWidth(text, font) * sx, PFont.FONTS[font].h * sy)


func _draw() -> void:
	if text.is_empty() or fill.is_empty():
		return
	var F: Dictionary = PFont.FONTS[font]
	var gh: int = F.h
	var sz := size()
	var ox := -sz.x / 2.0
	var oy := -sz.y
	var sl := absf(slant) * gh
	var x0 := int(floor(ox - sl)) - 2
	var y0 := int(floor(oy)) - 2
	var x1 := int(ceil(ox + sz.x + sl)) + 3
	var y1 := int(ceil(oy + sz.y)) + 4
	var W := x1 - x0
	var H := y1 - y0
	var ids := PackedByteArray()
	ids.resize(W * H)
	var edges := PackedByteArray()
	edges.resize(W * H)
	var vs := PackedFloat32Array()
	vs.resize(W * H)
	# lay the letters down, as drawWord does: which pixels are ink, and which of them sit on a flat edge
	var cx := 0.0
	for ch in text:
		var g: Variant = PFont._glyph(F, ch)
		if g == null:
			cx += (F.space + F.gap) * sx
			continue
		var lx := ox + cx
		var bot := oy + gh * sy
		for py in range(int(floor(oy)), int(ceil(bot))):
			var gy := int(floor((py + 0.5 - oy) / sy))
			if gy < 0 or gy >= gh:
				continue
			var shift := roundf(((bot - py - 0.5) / sy) * slant)
			var ry := py + 0.5 - oy - gy * sy
			var row: Array = g.rows[gy]
			var up: Variant = g.rows[gy - 1] if gy > 0 else null
			var dn: Variant = g.rows[gy + 1] if gy < gh - 1 else null
			for px in range(int(floor(lx + shift)) - 1, int(ceil(lx + shift + g.w * sx)) + 1):
				var fx := px + 0.5 - lx - shift
				var gx := int(floor(fx / sx))
				if gx < 0 or gx >= g.w or not row[gx]:
					continue
				var i := (py - y0) * W + (px - x0)
				if i < 0 or i >= W * H:
					continue
				ids[i] = 1
				vs[i] = (py + 0.5 - oy) / (gh * sy)
				var rx := fx - gx * sx
				var e := 0
				if ry < 1.0 and _open(up, gx):
					e |= 1
				if ry >= sy - 1.0 and _open(dn, gx):
					e |= 2
				if rx < 1.0 and not (gx > 0 and row[gx - 1]):
					e |= 4
				edges[i] = e
		cx += (g.w + F.gap) * sx
	var nF := fill.size()
	for y in H:
		for x in W:
			var i := y * W + x
			var at := Vector2(x0 + x, y0 + y)
			if ids[i]:
				var v := vs[i]
				var fi := clampi(int(floor((1.0 - v) * nF)), 0, nF - 1)
				var c := fill[fi]
				var e := edges[i]
				if e & 1:
					c = edge if edge.a > 0.0 else fill[nF - 1]
				elif e & 2:
					c = under if under.a > 0.0 else fill[0]
				elif e & 4 and fi < nF - 1:
					c = fill[fi + 1]
				if flash > 0.6 or (flash > 0.25 and v < 0.5):
					c = Color.WHITE
				draw_rect(Rect2(at, Vector2.ONE), c)
				continue
			if outline.a > 0.0 and _near(ids, W, H, x, y):
				draw_rect(Rect2(at, Vector2.ONE), outline)
				continue
			if shadow.a > 0.0 and (_ink(ids, W, H, x - 1, y - 2) or _ink(ids, W, H, x, y - 2) or _ink(ids, W, H, x - 1, y - 1)):
				draw_rect(Rect2(at, Vector2.ONE), Color(shadow, shadow.a * 0.9))


static func _open(r: Variant, gx: int) -> bool:
	if r == null:
		return true
	var row: Array = r
	return not row[gx] and not (gx > 0 and row[gx - 1]) and not (gx + 1 < row.size() and row[gx + 1])


static func _ink(ids: PackedByteArray, W: int, H: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and ids[y * W + x] != 0


static func _near(ids: PackedByteArray, W: int, H: int, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _ink(ids, W, H, x + dx, y + dy):
				return true
	return false
