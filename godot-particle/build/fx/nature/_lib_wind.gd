# Shared by the wind and root build scripts (leaf-storm, tornado, root-snare; not an effect): the original's seeded
# randomness (src/core/math.js: hash, rand, Rng = mulberry32), bit for bit, so the shapes it rolls once (wind bands,
# roots, cracks) come out exactly as the original's.
#   const W := preload("res://build/fx/nature/_lib_wind.gd")
#   var r := W.rng([seed, j])
extends RefCounted

const M := 0xffffffff


static func imul(a: int, b: int) -> int:
	return ((a & M) * (b & M)) & M


## hash(...ns): a 32-bit hash of integers (math.js).
static func ihash(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		h = imul(h ^ (int(n) & M), 0x85ebca6b)
		h ^= h >> 13
		h = imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & M


## rand(...ns) in [0, 1).
static func rand(ns: Array) -> float:
	return ihash(ns) / 4294967296.0


static func rng(ns: Array) -> Rng:
	return Rng.new(ihash(ns))


class Rng:
	var s := 1

	func _init(seed_: int = 1) -> void:
		s = seed_ & 0xffffffff
		if s == 0:
			s = 1

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = ((t ^ (t >> 15)) * (t | 1)) & 0xffffffff
		t = t ^ ((t + (((t ^ (t >> 7)) * (t | 61)) & 0xffffffff)) & 0xffffffff)
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	func int_(a: int, b: int) -> int:
		return int(floor(self.range(a, b + 1)))

	func chance(p: float) -> bool:
		return next() < p

	func sign() -> float:
		return -1.0 if next() < 0.5 else 1.0
