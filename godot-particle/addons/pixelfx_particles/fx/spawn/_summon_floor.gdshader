// spawn/summon-rise's floor, as the original draws it behind everything: cracks opening from the middle of the circle
// and glowing, cooling once the brute is through (`cracks`: their points, on the floor plane); the two rings burnt in
// from the front round to the back, flickering on the original's noise; the runes between them; the glowing gash the
// brute climbs out of. Colour layer. mode 1: the rings' light (light layer, its own shader: _summon_floor_light).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_summon_floor.gdshaderinc"

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 o = vec4(0.0);
	if (heat_k > 0.01) {
		// the cracks
		if (ck > 0.0) {
			for (int c = 0; c < 7; c++) {
				int n = int(texelFetch(cracks, ivec2(0, c), 0).w + 0.5);
				for (int i = 1; i < 32; i++) {
					if (i >= n) {
						break;
					}
					float u = float(i) / float(n);
					if (u > ck * 1.1) {
						break;
					}
					vec2 a = texelFetch(cracks, ivec2(i - 1, c), 0).xy;
					vec2 b = texelFetch(cracks, ivec2(i, c), 0).xy;
					if (seg_on(cell, floor(a), floor(b))) {
						int ci = clamp(int(floor(6.0 - u * 2.0 - cool * 2.6 + 0.5)), 2, 6);
						o = pal[ci];
					}
				}
			}
		}
		// the rings
		float prog = clamp(t / ign_t, 0.0, 1.0) * PI;
		for (int j = 0; j < 220; j++) {
			float a = (float(j) / 220.0) * TAU;
			float d = abs(mod(a - PI / 2.0 + PI * 3.0, TAU) - PI);
			if (d > prog) {
				continue;
			}
			float ca = cos(a);
			float sa = sin(a);
			vec2 p0 = vec2(ca * r0, sa * r0 * sy);
			vec2 p1 = vec2(ca * (r0 + 2.2), sa * (r0 + 2.2) * sy);
			vec2 p2 = vec2(ca * r1, sa * r1 * sy);
			bool h0 = all(equal(cell, floor(p0)));
			bool h1 = all(equal(cell, floor(p1)));
			bool h2 = inner > 0.0 && all(equal(cell, floor(p2)));
			if (!(h0 || h1 || h2)) {
				continue;
			}
			bool fresh = prog - d < 0.25 && t < ign_t + 0.1;
			float f = js_noise(a * 6.0 + t * 5.0, 4) * 0.5 + 0.5;
			float k = heat_k * (0.7 + 0.5 * f);
			if (h0) {
				o = fresh ? white : k > 0.95 ? pal[6] : k > 0.6 ? pal[5] : k > 0.35 ? pal[4] : pal[3];
			}
			if (h1 && 0.9 > th) {
				o = k > 0.8 ? pal[4] : pal[3];
			}
			if (h2 && (inner >= 1.0 || inner > th)) {
				o = k > 0.9 ? pal[5] : k > 0.5 ? pal[4] : pal[3];
			}
		}
		// the runes
		if (rk > 0.0) {
			for (int i = 0; i < 64; i++) {
				vec4 s = texelFetch(runes, ivec2(i, 0), 0);
				vec4 e = texelFetch(runes, ivec2(i, 1), 0);
				if (e.y < 0.5) {
					break;
				}
				float k = heat_k * rk * (0.75 + 0.35 * js_noise(t * 4.0 + e.x * 5.0, 8));
				float al = min(1.0, k * 1.5);
				if (seg_on(cell, floor(s.xy), floor(s.zw)) && (al >= 1.0 || al > th)) {
					o = k > 0.9 ? pal[6] : k > 0.55 ? pal[5] : pal[4];
				}
			}
		}
		// the gash
		if (hole > 0.0) {
			float hw = 15.0 * hole;
			if (cell.x >= floor(-hw - 1.0) && cell.x <= ceil(hw + 1.0) && cell.y >= -1.0 && cell.y <= 4.0) {
				vec2 p = cell + 0.5;
				float d = length(vec2(p.x / hw, (p.y - 0.5) / 3.2));
				if (d <= 1.0) {
					o = d > 0.86 ? pal[4] : d > 0.62 ? pal[1] : pal[0];
				}
			}
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
