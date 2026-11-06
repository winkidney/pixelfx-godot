# ./pfx sheets [ids] [--spriteframes] [--out DIR]: sprite sheets for every effect (or some): <out>/<category>/<name>.png
# + .json (Aseprite-style, meta.pixelfx: fps, loop, pivot, columns, act timing), and <out>/index.json.
# --spriteframes also writes <name>.res, a Godot SpriteFrames (light baked in), ready for an AnimatedSprite2D.
# port-of: tools/sheets.mjs (upstream)
extends RefCounted

const Px := preload("res://addons/pixelfx/core/px.gd")
const Lib := preload("fxlib.gd")
const Baker := preload("res://addons/pixelfx/bake/baker.gd")


func run(ids: PackedStringArray, flags: Dictionary) -> int:
	var out: String = flags.get("out", "res://records/sheets")
	var index := []
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			printerr(fx.error)
			continue
		var r := Lib.renderFrames(fx, {"bg": "none"})
		var name := id.get_file()
		var s := Lib.spriteSheet(fx, r, name)
		Lib.save_png(out.path_join(id + ".png"), s.image)
		Lib.save_text(out.path_join(id + ".json"), JSON.stringify(s.json, " "))
		if flags.has("spriteframes"):
			Baker.save_sprite_frames(Baker.bake(fx.mod), out.path_join(id + ".res"))
		var m: Dictionary = fx.meta
		var e := {"id": id, "name": m.get("name", ""), "desc": m.get("desc", ""), "tags": m.get("tags", []), "loop": m.loop, "fps": r.fps, "frames": r.n, "frameSize": m.size, "pivot": m.origin, "columns": s.json.meta.pixelfx.columns, "image": id + ".png"}
		var timing: Variant = Px.Act.actTiming(fx.mod)
		if timing != null:
			e.act = timing
		index.append(e)
		printraw(".")
	Lib.save_text(out.path_join("index.json"), JSON.stringify(index, " "))
	print("\n%d sheets -> %s" % [index.size(), ProjectSettings.globalize_path(out)])
	return 0
