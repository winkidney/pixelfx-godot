# Shared by holy/smite and holy/holy-pillar (not an effect): the original's seeded generator (so its cracks and
# shafts come out as the original rolls them), its jagged bolt paths and hash, and its simulated particle kinds as
# Godot emitters: SPARK (streaks thrown, falling and bouncing), STAR (twinkling crosses), EMBER (motes that rise and
# sway) and the light twin that rides each one.
extends "res://build/fx/holy/_holy.gd"

const M32 := 0xFFFFFFFF
const GRAV := 950.0


## The original's Rng (mulberry32), bit for bit.
class Rng:
	var s := 1

	func _init(seed_: int = 1) -> void:
		s = seed_ & 0xFFFFFFFF
		if s == 0:
			s = 1

	static func imul(a: int, b: int) -> int:
		a &= 0xFFFFFFFF
		b &= 0xFFFFFFFF
		var lo := (a * (b & 0xFFFF)) & 0xFFFFFFFF
		var hi := ((a * (b >> 16)) & 0xFFFF) << 16
		return (lo + hi) & 0xFFFFFFFF

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xFFFFFFFF
		var t := s
		t = imul(t ^ (t >> 15), t | 1)
		t ^= (t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	func chance(p: float) -> bool:
		return next() < p

	func sign() -> float:
		return -1.0 if next() < 0.5 else 1.0

	func pick(list: Array) -> Variant:
		return list[int(floor(next() * list.size()))]

	func int_in(a: int, b: int) -> int:
		return int(floor(range(a, b + 1)))


## The original's hash(...ns) / 2^32.
static func rand(ns: Array) -> float:
	var h := 0x9e3779b9
	for n in ns:
		h = Rng.imul(h ^ (int(n) & 0xFFFFFFFF), 0x85ebca6b)
		h ^= h >> 13
		h = Rng.imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return float(h & 0xFFFFFFFF) / 4294967296.0


## The original's bolt(): a jagged path a -> b by midpoint displacement.
static func bolt_path(r: Rng, a: Vector2, b: Vector2, jag := 0.22, depth := 5) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	for d in depth:
		var nx := PackedVector2Array([pts[0]])
		for i in range(1, pts.size()):
			var p0 := pts[i - 1]
			var p1 := pts[i]
			var dd := p1 - p0
			var L := dd.length()
			var off := (r.next() * 2.0 - 1.0) * jag * L
			var nrm := Vector2(-dd.y, dd.x) / (L if L > 0.0 else 1.0)
			nx.append((p0 + p1) / 2.0 + nrm * off)
			nx.append(p1)
		pts = nx
	return pts


## The original's SPARK: a short streak along its flight, its head cooling S0 -> S1 -> S2 over its life, falling at
## 0.45 g with drag 2.2, bouncing on the floor. o as particles(); needs a ground().
func spark_particles(name: String, S: Array, o: Dictionary) -> GPUParticles2D:
	var d := {"texture": "streak3", "align": true, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"gravity": Vector2(0, GRAV * 0.45), "drag": 2.2,
		"ramp": gradient([S[0], S[1], S[2], S[3]], [0.0, 0.4, 0.7, 0.92]), "collide": {"bounce": 0.45, "friction": 0.3}}
	d.merge(o, true)
	return particles(name, d)


## The original's STAR: a twinkling cross whose arms (size) close in over the last third of its life; arms c, tips
## tip. A flip strip (fx/holy/_flip.gdshader); o as particles().
func star_particles(name: String, size: float, c: Color, tip: Color, o: Dictionary) -> GPUParticles2D:
	var NF := 12
	var strip := sparkle_strip(NF, func(u: float) -> float: return size * (0.6 + 0.4 * sin(u * 23.0)) * minf(1.0, (1.0 - u) * 3.0), c, tip, maxi(2, int(ceilf(size))))
	var d := {"texture": asset(name.to_lower() + ".png", strip), "one_shot": true, "explosiveness": 1.0, "emitting": false, "drag": 1.6,
		"gravity": Vector2(0, -5)}
	d.merge(o, true)
	var p := particles(name, d)
	flip(p, NF)
	return p


## A light twin of an emitter made from options `o` (the same options, so the same particles): a glow texture on the
## light layer tinted `tint`, fading over its life by alpha_curve.
func light_twin(name: String, o: Dictionary, tex: String, tint: Color) -> GPUParticles2D:
	var d := o.duplicate()
	d.texture = tex
	d.layer = "light"
	d.modulate = tint
	var p := particles(name, d)
	return p
