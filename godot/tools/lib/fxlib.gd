# Shared by the tools: find effects, render their frames, lay frames out, write PNG, GIF and MP4.
# port-of: tools/lib/fxlib.mjs@<see godot/port/sync.mjs> (renderFrames, edgeFade, contactSheet, spriteSheet, writeVideo)
extends RefCounted

const Px := preload("res://addons/pixelfx/core/px.gd")
const FX_DIR := "res://addons/pixelfx/fx"


## Every effect id ("fire/torch"), sorted. Files starting with _ are helpers, not effects.
static func allIds() -> PackedStringArray:
	var out := PackedStringArray()
	var cats := DirAccess.get_directories_at(FX_DIR)
	cats.sort()
	for cat in cats:
		if cat.begins_with("_"):
			continue
		var files := DirAccess.get_files_at(FX_DIR + "/" + cat)
		files.sort()
		for f in files:
			if f.ends_with(".gd") and not f.begins_with("_"):
				out.append(cat + "/" + f.get_basename())
	return out


## Ids matching patterns: "fire/torch", "fire" (a category), "fire/*", "*torch*".
static func resolveIds(patterns: PackedStringArray) -> PackedStringArray:
	var all := allIds()
	var out := PackedStringArray()
	for p in patterns:
		if p.ends_with(".gd"):
			p = p.get_base_dir().get_file() + "/" + p.get_file().get_basename()
		var hits := 0
		for id in all:
			if (id == p or id.begins_with(p + "/") or id.match(p)) and not (id in out):
				out.append(id)
				hits += 1
		if hits == 0:
			printerr("no effect matches ", p)
	return out


static func pathOf(id: String) -> String:
	return FX_DIR + "/" + id + ".gd"


## Load an effect: { id, path, mod, meta }. Errors come back as { error }.
static func loadEffect(id: String) -> Dictionary:
	var path := pathOf(id)
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return {"error": "%s: no such effect (%s)" % [id, path]}
	var mod: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if mod == null or not mod.can_instantiate():
		return {"error": "%s: the script doesn't load (see the errors above)" % id}
	if mod.get("meta") == null:
		return {"error": "%s: no meta" % id}
	return {"id": id, "path": path, "mod": mod, "meta": Px.Fx.metaOf(mod)}


## Full-screen effects (transitions, weather, impact frames): 16:9 and at least 320 wide.
static func isScreen(meta: Dictionary) -> bool:
	return meta.size[0] >= 320 and absf(float(meta.size[0]) / meta.size[1] - 16.0 / 9.0) < 0.05


## A glow cut off by the canvas edge shows as a box once a frame sits in a game: ease the light out over the last
## E pixels of the canvas, in place.
static func edgeFade(f: Px.Frame, E: int = 8) -> void:
	var w := f.w
	var h := f.h
	var L := f.light
	for y in h:
		var ey := mini(y, h - 1 - y)
		var x := 0
		while x < w:
			var e := mini(ey, mini(x, w - 1 - x))
			if e >= E:
				x = w - 1 - E + 1
				continue
			var i := y * w + x
			var l := L[i]
			if l & 0xffffff:
				var u := (e + 0.5) / E
				var k := u * u * (3.0 - 2.0 * u)
				L[i] = (l & -16777216) | int(Px.round((l & 255) * k)) | (int(Px.round(((l >> 8) & 255) * k)) << 8) | (int(Px.round(((l >> 16) & 255) * k)) << 16)
			x += 1


## Render an effect's frames, as tools/lib/fxlib.mjs does. Returns { w, h, fps, n, frames: [{ t, color (RGBA over
## the backdrop), clear (RGBA on transparency), raw, light }] }. opts: { fps, seed, bg, margin, options, actor }.
static func renderFrames(fx: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var meta: Dictionary = fx.meta
	var W: int = meta.size[0]
	var H: int = meta.size[1]
	var OX: float = meta.origin[0]
	var OY: float = meta.origin[1]
	var m: int = opts.get("margin", 0)
	var w := W + m * 2
	var h := H + m * 2
	var fps: float = opts.get("fps", meta.fps) if opts.get("fps") != null else meta.fps
	var n := maxi(1, int(Px.round(meta.duration * fps)) + (0 if meta.loop else 1))
	var shown := Px.createFrame(w, h, -m, -m)
	var bare := Px.createFrame(w, h, -m, -m)
	var bgKind: String = opts.bg if opts.get("bg") != null else meta.bg
	var bg: Variant = null if bgKind == "none" else Px.Scene.backdrop(bgKind, w, h, OY + m)
	var o := {"x": OX, "y": OY}
	if opts.get("seed") != null:
		o.seed = opts.seed
	o.merge(opts.get("options", {}), true)
	var inst := Px.createFx(fx.mod, o)
	var actor: Variant = null
	if meta.get("actor") and opts.get("actor") != false:
		actor = inst.options.get("actor") if inst.options.get("actor") != null else Px.stockActor()
	var fade := m == 0 and not isScreen(meta)
	var frames := []
	var D: float = meta.duration
	for i in n:
		if i > 0:
			inst.update(1.0 / fps)
		shown.clear()
		bare.clear()
		inst.draw(bare)
		inst.draw(shown, "back")
		if actor != null:
			var tt := fmod(inst.t, D) if meta.loop else minf(inst.t, D)
			Px.drawActor(Px.painterFor(shown).place(OX, OY, true if opts.get("options", {}).get("flip") else false), actor, Px.Actor.actorAlphaOf(fx.mod, tt, inst.options))
		inst.draw(shown, "front")
		if fade:
			edgeFade(bare)
			edgeFade(shown)
		frames.append({
			"t": i / fps,
			"color": Px.composite(shown, PackedByteArray(), bg),
			"clear": Px.composite(bare, PackedByteArray(), null),
			"raw": bare.color.duplicate(),
			"light": bare.light.duplicate(),
		})
	return {"w": w, "h": h, "fps": fps, "n": n, "frames": frames, "margin": m}


## An effect acted out: the character, the target, the freeze, the shake, on a canvas big enough for all of it.
## Returns { w, h, fps, n, pivot, frames: [{ t (effect time, negative before it starts), frozen, color, clear }] }.
## opts: { fps (60), bg, seed, options, actor (false: no body), target (false: no target), seconds, hold (0.3) }.
static func renderAct(fx: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var meta: Dictionary = fx.meta
	var fps: float = opts.get("fps", 60.0) if opts.get("fps") != null else 60.0
	var b := Px.Act.actBounds(fx.mod)
	var pad := 6
	var w := int(b.x1 - b.x0) + pad * 2
	var h := int(b.y1 - b.y0) + pad * 2
	var X: float = pad - b.x0
	var Y: float = pad - b.y0
	var frame := Px.createFrame(w, h)
	var bgKind: String = opts.bg if opts.get("bg") != null else meta.bg
	var bg: Variant = null if bgKind == "none" else Px.Scene.backdrop(bgKind, w, h, Y)
	var o := {"x": X, "y": Y}
	if opts.get("seed") != null:
		o.seed = opts.seed
	o.merge(opts.get("options", {}), true)
	var act := Px.Act.createAct(fx.mod, o)
	var frames := []
	var secs: float = opts.seconds if opts.get("seconds") != null else (meta.duration * 2.0 - act.t if meta.loop else 8.0)
	var mx := int(Px.round(secs * fps))
	var show := func():
		frame.clear()
		act.draw(frame, {"body": opts.get("actor") != false, "target": opts.get("target") != false})
		var rgba := Px.composite(frame, PackedByteArray(), bg)
		var sh := act.shake()
		frames.append({"t": act.t, "frozen": act.frozen(), "color": _shifted(rgba, w, h, sh[0], sh[1]) if (sh[0] or sh[1]) else rgba, "clear": rgba})
	show.call()
	var i := 0
	while i < mx and not act.done():
		act.update(1.0 / fps)
		show.call()
		i += 1
	# a beat on the end, so a video doesn't cut off the last pose
	if not meta.loop:
		i = 0
		var hold: float = opts.hold if opts.get("hold") != null else 0.3
		while i < fps * hold:
			act.update(1.0 / fps)
			show.call()
			i += 1
	return {"w": w, "h": h, "fps": fps, "n": frames.size(), "frames": frames, "pivot": [X, Y]}


static func _shifted(rgba: PackedByteArray, w: int, h: int, sx: int, sy: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for y in h:
		for x in w:
			var X := clampi(x - sx, 0, w - 1)
			var Y := clampi(y - sy, 0, h - 1)
			var d := (y * w + x) * 4
			var s := (Y * w + X) * 4
			out[d] = rgba[s]
			out[d + 1] = rgba[s + 1]
			out[d + 2] = rgba[s + 2]
			out[d + 3] = rgba[s + 3]
	return out


## Nearest-neighbour upscale of RGBA.
static func upscale(rgba: PackedByteArray, w: int, h: int, k: int) -> PackedByteArray:
	if k == 1:
		return rgba
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	img.resize(w * k, h * k, Image.INTERPOLATE_NEAREST)
	return img.get_data()


## A blank RGBA canvas with helpers to paste images and write labels.
class Canvas:
	extends RefCounted
	var w: int
	var h: int
	var img: Image

	func _init(width: int, height: int, fill: Color = Color8(12, 11, 16, 255)) -> void:
		w = width
		h = height
		img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		img.fill(fill)

	func paste(src: PackedByteArray, sw: int, sh: int, x: int, y: int) -> void:
		var s := Image.create_from_data(sw, sh, false, Image.FORMAT_RGBA8, src)
		img.blend_rect(s, Rect2i(0, 0, sw, sh), Vector2i(x, y))

	func text(s: String, x: int, y: int, k: int = 2, col: Color = Color8(200, 196, 214), font: String = "mini") -> void:
		Px.PixelFont.rasterText(s, font, func(gx, gy):
			img.fill_rect(Rect2i(x + gx * k, y + gy * k, k, k), col))

	func rect(x: int, y: int, rw: int, rh: int, col: Color) -> void:
		img.fill_rect(Rect2i(x, y, rw, rh), col)


## Which frames a contact sheet shows: all of them up to max, else evenly spaced.
static func pickFrames(n: int, mx: int = 16) -> Array:
	var out := []
	if n <= mx:
		for i in n:
			out.append(i)
		return out
	for i in mx:
		out.append(int(Px.round((i * (n - 1)) / float(mx - 1))))
	return out


## A contact sheet: frames in a grid, labelled, scaled to stay readable. Returns an Image.
static func contactSheet(fx: Dictionary, r: Dictionary, opts: Dictionary = {}) -> Image:
	var w: int = r.w
	var h: int = r.h
	var frames: Array = r.frames
	var idx := pickFrames(frames.size(), opts.get("max", 16))
	var width: int = opts.get("width", 1600)
	var k: int = opts.zoom if opts.get("zoom") != null else maxi(1, mini(6, int(floorf((width - 16) / float(mini(idx.size(), 6)) / float(w + 6)))))
	var cw := w * k
	var ch := h * k
	var pad := 8
	var label := 16
	var cols := maxi(1, mini(idx.size(), int(floorf((maxi(width, cw + pad * 2) - pad) / float(cw + pad)))))
	var rows := ceili(idx.size() / float(cols))
	var head := 30
	var img := Canvas.new(pad + cols * (cw + pad), head + rows * (ch + label + pad) + pad)
	var m: Dictionary = fx.meta
	var title: String = opts.title if opts.get("title") != null else "%s  %dx%d  %sS  %dF @%d  %s" % [fx.id, m.size[0], m.size[1], str(m.duration), frames.size(), r.fps, "LOOP" if m.loop else "ONE-SHOT"]
	img.text(title, pad, 8, 3)
	for j in idx.size():
		var fi: int = idx[j]
		var x := pad + (j % cols) * (cw + pad)
		var y := head + floori(j / float(cols)) * (ch + label + pad)
		img.text("%d  %.2f" % [fi, frames[fi].t], x, y, 2, Color8(140, 134, 160))
		img.paste(upscale(frames[fi].color, w, h, k), cw, ch, x, y + label)
	return img.img


## A sprite sheet (transparent frames in a grid) plus Aseprite-style JSON that most engines import.
static func spriteSheet(fx: Dictionary, r: Dictionary, name: String) -> Dictionary:
	var w: int = r.w
	var h: int = r.h
	var frames: Array = r.frames
	var n := frames.size()
	var cols := mini(n, maxi(1, ceili(sqrt((n * h) / float(w)))))
	var rows := ceili(n / float(cols))
	var img := Canvas.new(cols * w, rows * h, Color(0, 0, 0, 0))
	var jf := []
	for i in n:
		var x := (i % cols) * w
		var y := floori(i / float(cols)) * h
		img.img.blit_rect(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, frames[i].clear), Rect2i(0, 0, w, h), Vector2i(x, y))
		jf.append({
			"filename": "%s %d" % [name, i], "frame": {"x": x, "y": y, "w": w, "h": h}, "rotated": false, "trimmed": false,
			"spriteSourceSize": {"x": 0, "y": 0, "w": w, "h": h}, "sourceSize": {"w": w, "h": h}, "duration": int(Px.round(1000.0 / r.fps)),
		})
	var m: Dictionary = fx.meta
	var pfx := {"id": fx.id, "name": m.get("name", ""), "fps": r.fps, "loop": m.loop, "frames": n, "frameSize": [w, h], "pivot": m.origin, "columns": cols}
	var timing: Variant = Px.Act.actTiming(fx.mod)
	if timing != null:
		pfx.act = timing
	var json := {"frames": jf, "meta": {
		"app": "https://github.com/winkidney/pixelfx-godot", "version": "1", "image": name + ".png", "format": "RGBA8888",
		"size": {"w": cols * w, "h": rows * h}, "scale": "1",
		"frameTags": [{"name": name, "from": 0, "to": n - 1, "direction": "forward"}],
		"pixelfx": pfx,
	}}
	return {"image": img.img, "json": json}


## Animated preview through ffmpeg (GIF or MP4), scaled k times. Returns false if ffmpeg is missing.
static func writeVideo(file: String, r: Dictionary, k: int, loops: int = 1) -> bool:
	var w: int = r.w
	var h: int = r.h
	var W := w * k
	var H := h * k
	var mp4 := file.ends_with(".mp4")
	var webp := file.ends_with(".webp")
	var raw := ProjectSettings.globalize_path(file + ".rgba")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file).get_base_dir())
	var fa := FileAccess.open(raw, FileAccess.WRITE)
	if fa == null:
		return false
	for l in loops:
		for f in r.frames:
			fa.store_buffer(upscale(f.color, w, h, k))
	fa.close()
	var args := ["-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % [W, H], "-r", str(r.fps), "-i", raw]
	if mp4:
		args.append_array(["-vf", "pad=%d:%d:0:0:black,format=yuv420p" % [W + W % 2, H + H % 2]])
		args.append_array(["-c:v", "libx264", "-crf", "14", "-preset", "slow", "-movflags", "+faststart"])
	elif webp:
		# lossless: every pixel, the alpha and the frame timing exactly as rendered
		args.append_array(["-c:v", "libwebp_anim", "-lossless", "1", "-compression_level", "4", "-pix_fmt", "bgra", "-loop", "0"])
	else:
		# GIF: at most 255 colors a frame, 1-bit alpha, delays in 1/100 s
		args.append_array(["-vf", "split[a][b];[a]palettegen=max_colors=255:stats_mode=full[p];[b][p]paletteuse=dither=none", "-loop", "0"])
	args.append(ProjectSettings.globalize_path(file))
	var out := []
	var code := OS.execute("ffmpeg", PackedStringArray(args), out, true)
	DirAccess.remove_absolute(raw)
	return code == 0


static func save_png(file: String, img: Image) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file).get_base_dir())
	img.save_png(file)
	return file


static func save_text(file: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file).get_base_dir())
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return file
