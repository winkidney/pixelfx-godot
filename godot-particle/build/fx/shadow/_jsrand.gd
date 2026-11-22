# The originals' deterministic randomness (src/core/math.js), for build scripts that place things exactly where the
# original does (not an effect): js_hash(...) / rand(...) and the mulberry32 Rng that rng(...) seeds.
extends RefCounted

const M := 0xffffffff


static func imul(a: int, b: int) -> int:
	a &= M
	b &= M
	return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & M


static func js_hash(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		h = imul(h ^ (int(n) & M), 0x85ebca6b)
		h ^= h >> 13
		h = imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & M


static func rand(ns: Array) -> float:
	return js_hash(ns) / 4294967296.0


static func rng(ns: Array) -> Rng:
	return Rng.new(js_hash(ns))


class Rng:
	var s := 1

	func _init(seed_: int = 1) -> void:
		s = seed_ & 0xffffffff
		if s == 0:
			s = 1

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = imul(t ^ (t >> 15), t | 1)
		t = t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xffffffff)
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	static func imul(a: int, b: int) -> int:
		a &= 0xffffffff
		b &= 0xffffffff
		return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff
