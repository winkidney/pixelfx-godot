# The Godot port against the JS original, frame by frame (./pfx parity). Reference data comes from
# `node godot/port/ref.mjs` (made on demand when it's missing or older than the JS); see godot/docs/PORTING.md.
#
# Gate, per variant: every frame's color and light buffers hash the same as the JS ones, or, where they don't, the
# raw frames differ in at most max(4 px, 0.1 % of the pixels either side drew) for color and the same for light
# off by more than 1 per channel, and the number and xor of the Rng draws match in every frame. Anything that
# legitimately diverges goes in port/parity-allow.json with a reason.
extends RefCounted

const Px := preload("res://addons/pixelfx/core/px.gd")
const Lib := preload("fxlib.gd")
const QUICK := ["default", "flip", "pal4", "seed7"]

var hc := HashingContext.new()
var node := "node"
var quiet := false
var sheets := true
var allow := {}
var timings := {}


func _init() -> void:
	var f := "res://port/parity-allow.json"
	if FileAccess.file_exists(f):
		var a: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
		if a is Dictionary:
			allow = a


static func _exact(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("$d"):
			return String(v["$d"]).hex_decode().decode_double(0)
		var o := {}
		for k in v:
			o[k] = _exact(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _exact(x))
	return v


static func root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


static func refPath(id: String) -> String:
	return "res://.parity/js/" + id + ".json"


## Ids whose reference is missing or older than the JS effect, its _lib, the JS core or ref.mjs.
func stale(ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var core_t := 0
	for f in DirAccess.get_files_at(root().path_join("src/core")):
		core_t = maxi(core_t, FileAccess.get_modified_time(root().path_join("src/core").path_join(f)))
	core_t = maxi(core_t, FileAccess.get_modified_time(ProjectSettings.globalize_path("res://port/ref.mjs")))
	for id in ids:
		var ref := ProjectSettings.globalize_path(refPath(id))
		if not FileAccess.file_exists(ref):
			out.append(id)
			continue
		var t := FileAccess.get_modified_time(ref)
		var js := root().path_join("src/fx/" + id + ".js")
		var lib := root().path_join("src/fx/" + id.get_base_dir() + "/_lib.js")
		if FileAccess.get_modified_time(js) > t or core_t > t or (FileAccess.file_exists(lib) and FileAccess.get_modified_time(lib) > t):
			out.append(id)
	return out


func makeRefs(ids: PackedStringArray) -> bool:
	if ids.is_empty():
		return true
	var args := PackedStringArray([ProjectSettings.globalize_path("res://port/ref.mjs")])
	args.append_array(ids)
	var out := []
	var code := OS.execute(node, args, out, true)
	if code != 0:
		printerr("ref.mjs failed (is Node 18+ on PATH?):\n", "\n".join(out))
	return code == 0


func _sha1(buf: PackedInt32Array) -> String:
	hc.start(HashingContext.HASH_SHA1)
	hc.update(buf.to_byte_array())
	return hc.finish().hex_encode()


## Render one variant the way ref.mjs does: [{ c, l, rn, rx }], and the raw buffers when keep is true.
func render(fx: Dictionary, v: Dictionary, keep: bool) -> Dictionary:
	var meta: Dictionary = fx.meta
	var W: int = meta.size[0]
	var H: int = meta.size[1]
	var fps: float = meta.fps
	var frame := Px.createFrame(W, H)
	var o := {"x": float(meta.origin[0]), "y": float(meta.origin[1])}
	o.merge(_exact(v.get("opts", {})), true)
	Px.Rng.trace_on = true
	Px.Rng.trace_n = 0
	Px.Rng.trace_x = 0
	var inst := Px.createFx(fx.mod, o)
	var frames := []
	var raw := []
	var stopAt: int = int(v.get("stopAt", -1))
	var total: int = v.frames.size()
	var ms := []
	for i in total:
		var t0 := Time.get_ticks_usec()
		if i > 0:
			inst.update(1.0 / fps)
		if i == stopAt:
			inst.stop()
		frame.clear()
		inst.draw(frame)
		ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		frames.append({"c": _sha1(frame.color), "l": _sha1(frame.light), "rn": Px.Rng.trace_n, "rx": Px.Rng.trace_x})
		Px.Rng.trace_n = 0
		Px.Rng.trace_x = 0
		if keep:
			raw.append([frame.color.duplicate(), frame.light.duplicate()])
	Px.Rng.trace_on = false
	ms.sort()
	return {"frames": frames, "raw": raw, "ms": ms[ms.size() >> 1] if ms.size() else 0.0, "w": W, "h": H}


## The JS raw frames of one variant, from `ref.mjs <id> --dump --variant <v>`: [[color, light], ...].
func jsFrames(id: String, vname: String) -> Array:
	var gz := "res://.parity/js/%s.%s.bin.gz" % [id, vname]
	var out := []
	OS.execute(node, PackedStringArray([ProjectSettings.globalize_path("res://port/ref.mjs"), id, "--dump", "--variant", vname]), out, true)
	var bytes := FileAccess.get_file_as_bytes(gz)
	if bytes.is_empty():
		return []
	bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var w := bytes.decode_u32(0)
	var h := bytes.decode_u32(4)
	var n := bytes.decode_u32(8)
	var sz := w * h * 4
	var frames := []
	var at := 12
	for i in n:
		frames.append([bytes.slice(at, at + sz).to_int32_array(), bytes.slice(at + sz, at + sz * 2).to_int32_array()])
		at += sz * 2
	return frames


## How far apart two raw frames are: { color: differing px, light: px off by more than 1, drawn: px either drew }.
static func diff(a: Array, b: Array) -> Dictionary:
	var ca: PackedInt32Array = a[0]
	var cb: PackedInt32Array = b[0]
	var la: PackedInt32Array = a[1]
	var lb: PackedInt32Array = b[1]
	var dc := 0
	var dl := 0
	var drawn := 0
	for i in ca.size():
		var x := ca[i]
		var y := cb[i]
		if x or y or la[i] or lb[i]:
			drawn += 1
		if x != y:
			dc += 1
		var p := la[i]
		var q := lb[i]
		if p != q:
			if absi((p & 255) - (q & 255)) > 1 or absi(((p >> 8) & 255) - ((q >> 8) & 255)) > 1 or absi(((p >> 16) & 255) - ((q >> 16) & 255)) > 1:
				dl += 1
	return {"color": dc, "light": dl, "drawn": drawn}


func _sheet(id: String, vname: String, w: int, h: int, js: Array, gd: Array, worst: Array) -> String:
	var k := maxi(1, mini(4, int(480.0 / maxf(w, h))))
	var picks := worst.slice(0, 4)
	var img := Lib.Canvas.new(8 + 3 * (w * k + 8), 30 + picks.size() * (h * k + 24))
	img.text("%s %s   JS | GODOT | DIFF" % [id, vname], 8, 8, 3)
	var y := 30
	for f in picks:
		img.text("FRAME %d" % f, 8, y, 2, Color8(140, 134, 160))
		var a := Px.createFrame(w, h)
		a.color = js[f][0]
		a.light = js[f][1]
		var b := Px.createFrame(w, h)
		b.color = gd[f][0]
		b.light = gd[f][1]
		var d := Px.createFrame(w, h)
		for i in w * h:
			if a.color[i] != b.color[i]:
				d.color[i] = Px.hex("#ff2a6d")
			elif a.light[i] != b.light[i]:
				d.color[i] = Px.hex("#2af0ff")
			elif a.color[i]:
				d.color[i] = Px.hex("#3a3448")
		var bg := Px.hex("#15131d")
		for j in 3:
			var fr: Variant = [a, b, d][j]
			img.paste(Lib.upscale(Px.composite(fr, PackedByteArray(), bg), w, h, k), w * k, h * k, 8 + j * (w * k + 8), y + 16)
		y += h * k + 24
	var file := "res://records/parity/%s.%s.png" % [id.replace("/", "-"), vname]
	Lib.save_png(file, img.img)
	return ProjectSettings.globalize_path(file)


static func _norm(v: Variant) -> Variant:
	if v is Dictionary:
		var o := {}
		for k in v:
			if v[k] != null:
				o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if typeof(v) == TYPE_INT:
		return float(v)
	return v


## Check effects; returns the number that failed.
func check(ids: PackedStringArray, variants: Array) -> int:
	if not makeRefs(stale(ids)):
		return ids.size()
	var fails := 0
	var allowed := 0
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			print("FAIL  %s\n      %s" % [id, fx.error])
			fails += 1
			continue
		var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(refPath(id)))
		var notes := []
		var bad := false
		var ms := 0.0
		# the act, as data
		var timing: Variant = Px.Act.actTiming(fx.mod)
		if JSON.stringify(_norm(timing), "", true) != JSON.stringify(_norm(_exact(ref.act)), "", true):
			notes.append("act timing differs:\n        js     %s\n        godot  %s" % [JSON.stringify(_norm(_exact(ref.act))), JSON.stringify(_norm(timing))])
			bad = true
		for vname in variants:
			if not ref.variants.has(vname):
				continue
			var v: Dictionary = ref.variants[vname]
			var r := render(fx, v, false)
			ms = maxf(ms, r.ms)
			var off := []
			var rng_off := -1
			for i in v.frames.size():
				var a: Dictionary = v.frames[i]
				var b: Dictionary = r.frames[i]
				if a.c != b.c or a.l != b.l:
					off.append(i)
				if rng_off < 0 and (int(a.rn) != b.rn or int(a.rx) != b.rx):
					rng_off = i
			if off.is_empty() and rng_off < 0:
				continue
			# not identical: look at the pixels
			var js := jsFrames(id, vname)
			var gd: Array = render(fx, v, true).raw
			var worst := []
			var over := 0
			var mc := 0
			var ml := 0
			for i in off:
				if i >= js.size():
					break
				var d := diff(js[i], gd[i])
				var lim := maxi(4, int(d.drawn * 0.001))
				mc = maxi(mc, d.color)
				ml = maxi(ml, d.light)
				if d.color > lim or d.light > lim:
					over += 1
					worst.append(i)
			var allowed_here := _allowed(id, vname)
			var verdict := "frames %d/%d differ (worst %d color px, %d light px)" % [off.size(), v.frames.size(), mc, ml]
			if rng_off >= 0:
				verdict += "; Rng draws differ from frame %d (js %d draws, godot %d)" % [rng_off, int(v.frames[rng_off].rn), r.frames[rng_off].rn]
			if over > 0 or rng_off >= 0:
				if allowed_here:
					notes.append("%s: allowed (%s): %s" % [vname, allow[id].get("reason", ""), verdict])
					allowed += 1
				else:
					bad = true
					var sheet := ""
					if sheets:
						if worst.is_empty():
							worst = [rng_off if rng_off >= 0 else off[0]]
						sheet = "\n        " + _sheet(id, vname, r.w, r.h, js, gd, worst)
					notes.append("%s: %s%s" % [vname, verdict, sheet])
			elif not quiet:
				notes.append("%s: within tolerance: %s" % [vname, verdict])
		timings[id] = ms
		if bad:
			fails += 1
		var tag := "FAIL" if bad else ("ok~ " if notes.size() else "ok  ")
		if bad or not quiet or notes.size():
			print("%s  %s  (%.1f ms/frame)%s" % [tag, id, ms, "".join(notes.map(func(s): return "\n      " + s))])
	print("\n%d effects: %d pass, %d fail%s" % [ids.size(), ids.size() - fails, fails, (", %d allowed divergences" % allowed) if allowed else ""])
	return fails


## Acts: the character, the target, freezes and shakes, against `ref.mjs --acts`. Returns the number that failed.
func checkActs(ids: PackedStringArray) -> int:
	var need := PackedStringArray()
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error") or Px.Fx.actOf(fx.mod) == null:
			continue
		var ref := ProjectSettings.globalize_path("res://.parity/js/%s.act.json" % id)
		var js := root().path_join("src/fx/" + id + ".js")
		if not FileAccess.file_exists(ref) or FileAccess.get_modified_time(js) > FileAccess.get_modified_time(ref):
			need.append(id)
	if need.size():
		var args := PackedStringArray([ProjectSettings.globalize_path("res://port/ref.mjs"), "--acts"])
		args.append_array(need)
		OS.execute(node, args, [], true)
	var fails := 0
	var n := 0
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error") or Px.Fx.actOf(fx.mod) == null:
			continue
		n += 1
		var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.parity/js/%s.act.json" % id))
		var meta: Dictionary = fx.meta
		Px.Rig.CACHE.clear()
		var b := Px.Act.actBounds(fx.mod)
		var w := int(b.x1 - b.x0 + 12.0)
		var h := int(b.y1 - b.y0 + 12.0)
		var X: float = 6.0 - b.x0
		var Y: float = 6.0 - b.y0
		var note := ""
		if w != int(ref.w) or h != int(ref.h):
			note = "bounds %dx%d, js %dx%d" % [w, h, int(ref.w), int(ref.h)]
		else:
			var frame := Px.createFrame(w, h)
			# actBounds above rendered poses into the rig's cache, as the JS did in its own fresh process
			var act := Px.Act.createAct(fx.mod, {"x": X, "y": Y})
			var fps := float(ref.fps)
			var mx := int(Px.round((meta.duration * 2.0 - act.t if meta.loop else 8.0) * fps))
			var got := []
			var show := func():
				frame.clear()
				act.draw(frame, {})
				got.append({"c": _sha1(frame.color), "l": _sha1(frame.light), "s": act.shake(), "f": act.frozen()})
			show.call()
			var i := 0
			while i < mx and not act.done():
				act.update(1.0 / fps)
				show.call()
				i += 1
			if not meta.loop:
				i = 0
				while i < fps * 0.3:
					act.update(1.0 / fps)
					show.call()
					i += 1
			if got.size() != ref.frames.size():
				note = "%d frames, js %d" % [got.size(), ref.frames.size()]
			else:
				var off := []
				for k in got.size():
					var a: Dictionary = ref.frames[k]
					var g: Dictionary = got[k]
					if int(a.s[0]) != g.s[0] or int(a.s[1]) != g.s[1] or a.f != g.f:
						note = "frame %d: shake/freeze differ" % k
						break
					if a.c != g.c or a.l != g.l:
						off.append(k)
				if not note and off.size():
					# not identical: compare the pixels, with the same tolerance as effects
					var js := _actDump(id)
					Px.Rig.CACHE.clear()
					Px.Act.actBounds(fx.mod)
					var gd := _actFrames(fx.mod, w, h, X, Y, float(ref.fps), meta)
					var worst := 0
					var over := 0
					for k in off:
						if k >= js.size() or k >= gd.size():
							break
						var d := diff(js[k], gd[k])
						var lim := maxi(4, int(d.drawn * 0.001))
						worst = maxi(worst, maxi(d.color, d.light))
						if d.color > lim or d.light > lim:
							over += 1
					if over:
						note = "%d of %d frames differ beyond tolerance (first %d, worst %d px)" % [over, got.size(), off[0], worst]
					else:
						note = "~%d frames differ, within tolerance (worst %d px)" % [off.size(), worst]
		if note.begins_with("~"):
			if not quiet:
				print("ok~   %s act: %s" % [id, note.substr(1)])
		elif note and allow.has(id) and allow[id].get("acts", false):
			print("ok*   %s act: allowed (%s): %s" % [id, allow[id].get("reason", ""), note])
		elif note:
			fails += 1
			print("FAIL  %s act: %s" % [id, note])
		elif not quiet:
			print("ok    %s act" % id)
	print("\n%d acts: %d pass, %d fail" % [n, n - fails, fails])
	return fails


func _actDump(id: String) -> Array:
	OS.execute(node, PackedStringArray([ProjectSettings.globalize_path("res://port/ref.mjs"), "--acts", "--dump", id]), [], true)
	var bytes := FileAccess.get_file_as_bytes("res://.parity/js/%s.act.bin.gz" % id)
	if bytes.is_empty():
		return []
	bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var w := bytes.decode_u32(0)
	var h := bytes.decode_u32(4)
	var n := bytes.decode_u32(8)
	var sz := w * h * 4
	var out := []
	var at := 12
	for i in n:
		out.append([bytes.slice(at, at + sz).to_int32_array(), bytes.slice(at + sz, at + sz * 2).to_int32_array()])
		at += sz * 2
	return out


func _actFrames(mod: Script, w: int, h: int, X: float, Y: float, fps: float, meta: Dictionary) -> Array:
	var frame := Px.createFrame(w, h)
	var act := Px.Act.createAct(mod, {"x": X, "y": Y})
	var mx := int(Px.round((meta.duration * 2.0 - act.t if meta.loop else 8.0) * fps))
	var out := []
	var shoot := func():
		frame.clear()
		act.draw(frame, {})
		out.append([frame.color.duplicate(), frame.light.duplicate()])
	shoot.call()
	var i := 0
	while i < mx and not act.done():
		act.update(1.0 / fps)
		shoot.call()
		i += 1
	if not meta.loop:
		i = 0
		while i < fps * 0.3:
			act.update(1.0 / fps)
			shoot.call()
			i += 1
	return out


func _allowed(id: String, vname: String) -> bool:
	if not allow.has(id):
		return false
	var vs: Variant = allow[id].get("variants", "*")
	return vs == "*" or (vs is Array and vname in vs)
