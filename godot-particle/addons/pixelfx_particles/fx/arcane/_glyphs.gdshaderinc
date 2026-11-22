// The original's rune alphabet (arcane/_lib.js GLYPHS): eight 3 x 5 glyphs, bit (row * 3 + col) of each.
const int PFX_GLYPHS[8] = int[](
	2 | (5 << 3) | (2 << 6) | (2 << 9) | (5 << 12),
	5 | (5 << 3) | (2 << 6) | (5 << 9) | (5 << 12),
	3 | (5 << 3) | (3 << 6) | (1 << 9) | (1 << 12),
	1 | (5 << 3) | (7 << 6) | (5 << 9) | (4 << 12),
	6 | (1 << 3) | (2 << 6) | (4 << 9) | (3 << 12),
	7 | (2 << 3) | (7 << 6) | (2 << 9) | (2 << 12),
	5 | (7 << 3) | (5 << 6) | (4 << 9) | (4 << 12),
	2 | (6 << 3) | (2 << 6) | (3 << 9) | (2 << 12)
);

// is cell q (0..2, 0..4 from the glyph's top left) lit in glyph i?
bool pfx_glyph(int i, ivec2 q) {
	if (q.x < 0 || q.x > 2 || q.y < 0 || q.y > 4) {
		return false;
	}
	return ((PFX_GLYPHS[((i % 8) + 8) % 8] >> (q.y * 3 + q.x)) & 1) == 1;
}
