# ./pfxp new <id>: a build script to start from, with the original's description, colour ramps and timing written in.
extends RefCounted

const Build := preload("res://addons/pixelfx_particles/core/build.gd")


func run(args: PackedStringArray, flags: Dictionary) -> int:
	if args.is_empty():
		printerr("new <category>/<name>")
		return 1
	var id := args[0]
	var m := Build.meta_of(id)
	if m.is_empty():
		printerr("%s: no such effect in port/meta.json" % id)
		return 1
	var path := "res://build/fx/%s.gd" % id
	if FileAccess.file_exists(path) and not flags.has("force"):
		printerr("%s exists (--force to overwrite)" % path)
		return 1
	var ramps := Build.ramps_of(m)
	var lines := PackedStringArray()
	lines.append("# reimagined-from: " + m.source)
	lines.append("# %s: %s" % [m.name, m.desc])
	lines.append("# %s, %.2f s, %dx%d canvas, origin %s, backdrop %s%s" % ["loop" if m.loop else "one-shot", m.duration, m.size[0], m.size[1], m.origin, m.bg, (", stand-in %d" % m.actor) if m.actor else ""])
	for k in ramps:
		lines.append("# ramp %s: %s" % [k, " ".join(Array(ramps[k]).map(func(c): return "#" + c.to_html(false)))])
	lines.append('extends "res://addons/pixelfx_particles/core/build.gd"')
	lines.append("")
	lines.append("")
	lines.append("func make() -> void:")
	lines.append('	var p := particles("Main", {"amount": 24, "lifetime": 0.8, "texture": "dot2", "speed": [20, 40], "spread": 30,')
	var first: String = ramps.keys()[0] if ramps.size() else ""
	if first:
		lines.append('		"ramp": ramp("%s", {"reverse": true})})' % first)
	else:
		lines.append('		"color": Color.WHITE})')
	lines.append("")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("wrote ", ProjectSettings.globalize_path(path))
	return 0
