# pixelfx particles command line. Run it through ./pfxp (rendering goes through xvfb-run: GPU particles need a real
# renderer; everything else runs headless).
#
#   ./pfxp build [ids]                    build/fx/<id>.gd -> addons/pixelfx_particles/fx/<id>.tscn
#   ./pfxp render <ids> [--out DIR]       frames as the reference renders them: records/render/<id>/0000.png ...
#   ./pfxp compare <ids>                  render, then frames against the reference: records/compare/<id>/ (python)
#   ./pfxp check [ids]                    scenes load, meta matches the original, timeline sane, seeds fixed
#   ./pfxp smoke [ids]                    every built effect (and act) through the nodes, played to its end (xvfb-run)
#   ./pfxp index                          addons/pixelfx_particles/fx/registry.gd and docs/CATALOG.md
#   ./pfxp new <id>                       a build script to start from
#   ./pfxp list [words]                   ids, names and descriptions
#
# Ids are "category/name"; a category ("fire"), a pattern ("fire/*", "*torch*") or "*" works too.
extends SceneTree

const Build := preload("res://addons/pixelfx_particles/core/build.gd")

var flags := {}
var pos := PackedStringArray()


func _initialize() -> void:
	var code: Variant = await main()
	quit(code if code is int else 1)


func main() -> int:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--"):
			var k := a.substr(2)
			if k in ["act", "all", "quiet", "force"] or i + 1 >= args.size() or args[i + 1].begins_with("--"):
				flags[k] = true
			else:
				flags[k] = args[i + 1]
				i += 1
		else:
			pos.append(a)
		i += 1
	if pos.is_empty():
		return help()
	var cmd := pos[0]
	pos = pos.slice(1)
	match cmd:
		"build": return cmd_build()
		"render": return await load("res://tools/lib/render.gd").new().run(self, ids_or_all(), flags)
		"smoke": return await load("res://tools/lib/smoke.gd").new().run(self, ids_or_built(), flags)
		"check": return load("res://tools/lib/check.gd").new().run(ids_or_built(), flags)
		"index": return load("res://tools/lib/index.gd").new().run()
		"new": return load("res://tools/lib/newfx.gd").new().run(pos, flags)
		"list": return cmd_list()
		"help": return help()
	printerr("unknown command: ", cmd)
	return help(1)


func help(code: int = 0) -> int:
	for line in FileAccess.get_file_as_string("res://tools/cli.gd").split("\n"):
		if not line.begins_with("#"):
			break
		print(line.substr(2))
	return code


static func all_ids() -> PackedStringArray:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Build.META))
	var out := PackedStringArray(m.keys())
	out.sort()
	return out


static func resolve(patterns: PackedStringArray) -> PackedStringArray:
	var all := all_ids()
	var out := PackedStringArray()
	for p in patterns:
		var pat := p
		if not ("/" in p or "*" in p):
			pat = p + "/*"
		for id in all:
			if (id == pat or id.match(pat)) and not out.has(id):
				out.append(id)
		if out.is_empty() and not "*" in p:
			printerr("no effect matches ", p)
	return out


func ids_or_all() -> PackedStringArray:
	return resolve(pos) if pos.size() else all_ids()


## The ids given, or every effect that has a scene.
func ids_or_built() -> PackedStringArray:
	if pos.size():
		return resolve(pos)
	var out := PackedStringArray()
	for id in all_ids():
		if FileAccess.file_exists(scene_path(id)):
			out.append(id)
	return out


static func scene_path(id: String) -> String:
	return "res://addons/pixelfx_particles/fx/%s.tscn" % id


static func build_path(id: String) -> String:
	return "res://build/fx/%s.gd" % id


func cmd_build() -> int:
	var ids := ids_or_all() if pos.size() else PackedStringArray()
	if ids.is_empty():
		for id in all_ids():
			if FileAccess.file_exists(build_path(id)):
				ids.append(id)
	var failed := 0
	for id in ids:
		var path := build_path(id)
		if not FileAccess.file_exists(path):
			printerr("%s: no build script (%s): ./pfxp new %s" % [id, path, id])
			failed += 1
			continue
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			printerr("%s: the build script doesn't load (see above)" % id)
			failed += 1
			continue
		var b: Variant = script.new()
		b.begin(id)
		b.make()
		var err: int = b.save(scene_path(id))
		if err != OK:
			printerr("%s: saving failed (%s)" % [id, error_string(err)])
			failed += 1
		elif not flags.has("quiet"):
			print("built ", id)
	print("%d built, %d failed" % [ids.size() - failed, failed])
	return 1 if failed else 0


func cmd_list() -> int:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Build.META))
	var n := 0
	for id in all_ids():
		var e: Dictionary = m[id]
		var hay := ("%s %s %s" % [id, e.name, e.desc]).to_lower()
		if pos.size() and not Array(pos).all(func(w): return w.to_lower() in hay):
			continue
		n += 1
		var built := "*" if FileAccess.file_exists(scene_path(id)) else " "
		print("%s %-28s %s%s  %s" % [built, id, e.name, " (loop)" if e.loop else "", e.desc])
	print("%d effects (* has a scene)" % n)
	return 0
