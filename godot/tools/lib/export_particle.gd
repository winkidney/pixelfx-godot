# ./pfx export meta|actors --out DIR: what the particle port (godot-particle/) takes from this one.
#   meta     DIR/meta.json: every effect's meta (size, origin, bg, fps, duration, loop, options and colour ramps,
#            actor, act timing and canvas), its kind and the upstream file it ports.
#   actors   DIR/stock/hero1.png, hero2.png (the stand-ins, feet at the bottom middle) and, for every act,
#            DIR/acts/<cat>-<name>/body.png, target.png and act.json: the knight and the straw target alone, frame by
#            frame (no effect, no straw, no dust, no after-images: the particle port draws those), deduplicated into
#            sheets, with each frame's act time, effect time, freeze, shake, joints, after-image flag and dust.
# Frames follow tools/lib/fxlib.gd renderAct exactly (60 fps, same canvas, same length), so they line up with the
# reference renders in records/act.
extends RefCounted

const Px := preload("res://addons/pixelfx/core/px.gd")
const Lib := preload("fxlib.gd")


func run(args: PackedStringArray, flags: Dictionary) -> int:
	var out: String = flags.get("out", "res://records/export")
	if out.begins_with("res://"):
		out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var what := args[0] if args.size() else ""
	var ids := Lib.resolveIds(args.slice(1)) if args.size() > 1 else Lib.resolveIds(PackedStringArray(["*"]))
	match what:
		"meta":
			return _meta(ids, out)
		"actors":
			return _actors(ids, out)
		"color":
			return _color(ids, out, int(flags.get("frames", 24)))
	printerr("export: meta | actors | color [ids] --out DIR")
	return 1


## The colour layer alone (no light, no backdrop, no stand-in), at up to k frames spread over the effect:
## DIR/<cat>/<name>/color.png (a grid of frames) and color.json. The particle port lifts still props from it.
func _color(ids: PackedStringArray, out: String, k: int) -> int:
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			printerr(fx.error)
			continue
		var r := Lib.renderFrames(fx, {"bg": "none", "actor": false})
		var w: int = r.w
		var h: int = r.h
		var n: int = r.n
		var pick := []
		for i in mini(k, n):
			pick.append(int(roundf(i * (n - 1) / float(maxi(1, mini(k, n) - 1)))))
		var cols := mini(pick.size(), 6)
		var rows := int(ceil(pick.size() / float(cols)))
		var sheet := Image.create(cols * w, rows * h, false, Image.FORMAT_RGBA8)
		for j in pick.size():
			var f: Dictionary = r.frames[pick[j]]
			var raw: PackedInt32Array = f.raw
			var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, raw.to_byte_array())
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((j % cols) * w, floori(j / float(cols)) * h))
		var dir := out.path_join(id)
		DirAccess.make_dir_recursive_absolute(dir)
		sheet.save_png(dir.path_join("color.png"))
		var f2 := FileAccess.open(dir.path_join("color.json"), FileAccess.WRITE)
		f2.store_string(JSON.stringify({"w": w, "h": h, "cols": cols, "count": pick.size(), "frames": pick, "fps": r.fps}))
		f2.close()
		printraw(".")
	print("\n%d colour layers -> %s" % [ids.size(), out])
	return 0


static func _plain(v: Variant) -> Variant:
	# options as JSON: colours as hex strings, Packed arrays as arrays
	if v is Color:
		return "#" + v.to_html(v.a < 1.0)
	if v is PackedStringArray or v is PackedColorArray or v is PackedInt32Array or v is PackedFloat32Array or v is PackedFloat64Array or v is Array:
		return Array(v).map(func(x): return _plain(x))
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _plain(v[k])
		return o
	if v is Object or v is Callable:
		return null
	return v


func _meta(ids: PackedStringArray, out: String) -> int:
	var all := {}
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			printerr(fx.error)
			return 1
		var m: Dictionary = fx.meta
		var src := FileAccess.get_file_as_string(fx.path)
		var port := ""
		for line in src.split("\n"):
			if line.begins_with("# port-of: "):
				port = line.substr(11).strip_edges()
				break
		var info: Dictionary = Px.Fx.info(fx.mod)
		var e := {
			"name": m.get("name", ""), "desc": m.get("desc", ""), "tags": _plain(m.get("tags", [])),
			"duration": float(m.duration), "loop": bool(m.loop), "fps": int(m.fps), "size": _plain(m.size),
			"origin": _plain(m.origin), "bg": m.bg, "actor": int(m.get("actor", 0)) if m.get("actor") else 0,
			"screen": Lib.isScreen(m), "kind": ["pure", "sim", "factory"][info.kind], "source": port,
			"options": _plain(m.get("options", {})),
		}
		if Px.Fx.actOf(fx.mod) != null:
			Px.Rig.CACHE.clear()
			var b := Px.Act.actBounds(fx.mod)
			e.act = {"timing": _plain(Px.Act.actTiming(fx.mod)), "w": int(b.x1 - b.x0) + 12, "h": int(b.y1 - b.y0) + 12,
				"x": 6.0 - b.x0, "y": 6.0 - b.y0, "onBody": bool(Px.Fx.actOf(fx.mod).get("onBody", false))}
		all[id] = e
	var f := FileAccess.open(out.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(all, " ", true))
	f.close()
	print("%d effects -> %s" % [all.size(), out.path_join("meta.json")])
	return 0


static func _rgba(frame: Px.Frame) -> Image:
	var bytes := Px.composite(frame, PackedByteArray(), null)
	return Image.create_from_data(frame.w, frame.h, false, Image.FORMAT_RGBA8, bytes)


## Unique images, packed into a sheet of equal cells cropped to the union of what any of them drew.
class Sheet:
	extends RefCounted
	var imgs: Array = []
	var keys := {}
	var box := Rect2i()

	func add(img: Image) -> int:
		var k := _hash(img)
		if keys.has(k):
			return keys[k]
		var u := img.get_used_rect()
		if u.size.x > 0:
			box = u if box.size.x == 0 else box.merge(u)
		keys[k] = imgs.size()
		imgs.append(img)
		return imgs.size() - 1

	static func _hash(img: Image) -> String:
		var hc := HashingContext.new()
		hc.start(HashingContext.HASH_SHA1)
		hc.update(img.get_data())
		return hc.finish().hex_encode()

	func save(path: String) -> Dictionary:
		var n := imgs.size()
		var b := box if box.size.x > 0 else Rect2i(0, 0, 1, 1)
		var cols := mini(n, maxi(1, int(ceil(sqrt(float(n))))))
		var rows := int(ceil(float(n) / cols))
		var sheet := Image.create(cols * b.size.x, rows * b.size.y, false, Image.FORMAT_RGBA8)
		for i in n:
			sheet.blit_rect(imgs[i], b, Vector2i((i % cols) * b.size.x, floori(i / float(cols)) * b.size.y))
		sheet.save_png(path)
		return {"cell": [b.size.x, b.size.y], "at": [b.position.x, b.position.y], "cols": cols, "count": n}


func _actors(ids: PackedStringArray, out: String) -> int:
	DirAccess.make_dir_recursive_absolute(out.path_join("stock"))
	for k in [1, 2]:
		var ac: Dictionary = Px.stockActor(k)
		var img := Image.create_from_data(ac.w, ac.h, false, Image.FORMAT_RGBA8, (Px.Actor.PIXELS[k] as PackedInt32Array).to_byte_array())
		img.save_png(out.path_join("stock/hero%d.png" % k))
	var n := 0
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error") or Px.Fx.actOf(fx.mod) == null:
			continue
		_act(fx, out.path_join("acts").path_join(id.replace("/", "-")))
		n += 1
		printraw(".")
	print("\n2 stand-ins and %d acts -> %s" % [n, out])
	return 0


func _act(fx: Dictionary, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var meta: Dictionary = fx.meta
	var fps := 60.0
	Px.Rig.CACHE.clear()
	var b := Px.Act.actBounds(fx.mod)
	var pad := 6
	var w := int(b.x1 - b.x0) + pad * 2
	var h := int(b.y1 - b.y0) + pad * 2
	var X: float = pad - b.x0
	var Y: float = pad - b.y0
	var act := Px.Act.createAct(fx.mod, {"x": X, "y": Y})
	var bodies := Sheet.new()
	var targets := Sheet.new()
	var body := Px.createFrame(w, h)
	var tgt := Px.createFrame(w, h)
	var frames := []
	var dustDone := {}
	var shot := func():
		var q: Dictionary = act.last if act.last != null else act.poseNow()
		var FX := int(act.X) - body.ox
		var FY := int(act.Y) - body.oy
		var rx := int(Px.round(q.x if q.get("x") != null else 0.0))
		var ry := int(Px.round(q.y if q.get("y") != null else 0.0))
		var BX := FX + (-rx if act.flip else rx)
		var BY := FY + ry
		body.clear()
		act._shadow(body, q, FX, FY, rx, ry)
		var r := Px.Rig.posed(q)
		for i in r.n:
			act._paint(body, r, i, r.color[i], BX, BY)
		tgt.clear()
		for g in act.targets:
			g.draw(tgt.color, w, h, FX, FY, act.flip)
		var sk: Dictionary = Px.Rig.skeleton(q).joints
		var joints := {}
		for k in ["handN", "handF", "head", "chest", "pelvis", "ankleN", "ankleF"]:
			var p: Array = sk[k]
			joints[k] = [BX + (-p[0] if act.flip else p[0]), BY + p[1]]
		var sh: Array = act.shake()
		frames.append({"t": act.t, "ft": act.fx.t, "frozen": act.frozen(), "shake": [int(sh[0]), int(sh[1])],
			"b": bodies.add(_rgba(body)), "g": targets.add(_rgba(tgt)), "ghost": true if q.get("ghost") else false, "j": joints})
	var secs: float = meta.duration * 2.0 - act.t if meta.loop else 8.0
	var mx := int(Px.round(secs * fps))
	shot.call()
	var i := 0
	while i < mx and not act.done():
		act.update(1.0 / fps)
		shot.call()
		i += 1
	if not meta.loop:
		i = 0
		while i < fps * 0.3:
			act.update(1.0 / fps)
			shot.call()
			i += 1
	var a: Dictionary = Px.Fx.actOf(fx.mod)
	var info := {
		"id": fx.id, "fps": fps, "w": w, "h": h, "pivot": [X, Y], "flip": act.flip, "onBody": bool(a.get("onBody", false)),
		"ghostColor": Px.toHex(act.gc),
		"targets": act.targets.map(func(g): return g.x),
		"hits": export_hits(act.hits), "dust": _plain(act.dust),
		"body": bodies.save(dir.path_join("body.png")), "target": targets.save(dir.path_join("target.png")),
		"frames": frames,
	}
	var f := FileAccess.open(dir.path_join("act.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(info))
	f.close()


static func export_hits(hits: Array) -> Array:
	return hits.map(func(h): return _plain(h))
