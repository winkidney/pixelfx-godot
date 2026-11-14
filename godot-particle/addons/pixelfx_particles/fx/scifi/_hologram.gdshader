// The hologram's model (src/fx/scifi/hologram.js), from the keyed clock `t`: a tall six-sided crystal turning once a
// loop, tilted toward us, bobbing; the faces that face us filled with scanlines and the scan bar climbing through
// them, its edges sorted far to near (the far ones dim and dithered, hot where the bar crosses), its near corners
// white, a dashed data ring round its waist. Every pixel but the faces goes through the original's put(): when it
// glitches (`data`, one column a frame, rolled from the original's rand(seed, frame, ...): strength, flicker, jolt,
// two torn bands) odd rows drop out and torn rows slide sideways with a pink split fringe. Colour layer.
//   mode 0: the model; mode 1: the cone of light under it and the stage ring it stands on, the projector's lights
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform vec2 size = vec2(112.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform int mode = 0;
uniform vec4 pal[8] : source_color;
uniform vec4 split_c : source_color = vec4(1.0, 0.31, 0.85, 1.0);

#include "res://addons/pixelfx_particles/fx/scifi/_hologram.gdshaderinc"

ivec2 edge_of(int e) {
	int i = e / 3;
	int k = e % 3;
	if (k == 0) {
		return ivec2(0, 2 + i);
	}
	if (k == 1) {
		return ivec2(1, 2 + i);
	}
	return ivec2(2 + i, 2 + (i + 1) % 6);
}

// what the original's put() leaves at cell q of the model (edges far to near, the near corners, the data ring):
// its colour and alpha, or alpha 0. thr: the dither threshold of the pixel it lands on.
vec4 model_puts(Holo h, ivec2 q, float thr) {
	vec4 c = vec4(0.0);
	vec2 cc = vec2(q) + 0.5;
	float best = -1e9;
	for (int e = 0; e < 18; e++) {
		ivec2 ij = edge_of(e);
		vec3 a = h.V[ij.x];
		vec3 b = h.V[ij.y];
		float z = (a.z + b.z) / 2.0;
		if (z < best) {
			continue;
		}
		vec2 ab = b.xy - a.xy;
		float L = length(ab);
		if (L < 1e-4) {
			continue;
		}
		float d0 = dot(cc - a.xy, ab) / L;
		vec2 foot = a.xy + ab * clamp(d0 / L, 0.0, 1.0);
		if (length(foot - cc) > 1.6) {
			continue;
		}
		int j0 = max(0, int(floor((d0 - 2.0) / 0.5)));
		int j1 = int(ceil((d0 + 2.0) / 0.5));
		for (int j = j0; j <= j1; j++) {
			float d = float(j) * 0.5;
			if (d > L + 1e-5) {
				break;
			}
			vec2 p = mix(a.xy, b.xy, d / L);
			if (all(equal(floor(p), vec2(q)))) {
				bool hot = abs(p.y - h.scan) < 1.5;
				vec4 col;
				float al;
				if (z < -0.15) {
					col = hot ? pal[5] : pal[3];
					al = 0.7;
				} else {
					col = hot ? vec4(1.0) : z > 0.4 ? pal[6] : pal[5];
					al = 1.0;
				}
				if (al >= thr) {
					c = col;
					best = z;
				}
			}
		}
	}
	for (int i = 0; i < 8; i++) {
		if (h.V[i].z >= -0.15 && all(equal(floor(h.V[i].xy), vec2(q)))) {
			c = vec4(1.0);
		}
	}
	for (int i = 0; i < 64; i++) {
		if ((i / 3) % 3 == 2) {
			continue;
		}
		float a = float(i) / 64.0 * TAU + h.ph * TAU * 2.0;
		vec2 p = vec2(h.cx + cos(a) * (RAD + 9.0), h.cy + 3.0 + sin(a) * 4.0);
		if (all(equal(floor(p), vec2(q)))) {
			bool fr = sin(a) > 0.0;
			if ((fr ? 1.0 : 0.6) >= thr) {
				c = fr ? (i % 9 == 0 ? vec4(1.0) : pal[5]) : pal[3];
			}
		}
	}
	return c;
}

// the faces that face us at cell q: scanlines every third row, the scan bar solid
vec4 faces(Holo h, ivec2 q) {
	vec2 pc = vec2(q) + 0.5;
	for (int i = 0; i < 6; i++) {
		for (int s = 0; s < 2; s++) {
			vec3 a = s == 0 ? h.V[0] : h.V[1];
			vec3 b = s == 0 ? h.V[2 + i] : h.V[2 + (i + 1) % 6];
			vec3 c = s == 0 ? h.V[2 + (i + 1) % 6] : h.V[2 + i];
			float nz = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
			if (nz >= 0.0) {
				continue;
			}
			// even-odd: is the pixel centre inside the triangle
			bool inside = false;
			vec2 P0 = a.xy;
			vec2 P1 = b.xy;
			vec2 P2 = c.xy;
			for (int k = 0; k < 3; k++) {
				vec2 pi = k == 0 ? P0 : k == 1 ? P1 : P2;
				vec2 pj = k == 0 ? P2 : k == 1 ? P0 : P1;
				if ((pi.y > pc.y) != (pj.y > pc.y) && pc.x < (pj.x - pi.x) * (pc.y - pi.y) / (pj.y - pi.y) + pi.x) {
					inside = !inside;
				}
			}
			if (!inside) {
				continue;
			}
			int yy = q.y;
			bool on = (imod(yy, 3) == 0 && !(h.flick && (yy & 1) == 1)) || abs(pc.y - h.scan) < 1.5;
			if (!on) {
				return vec4(0.0);
			}
			float shade = clamp(0.3 + 0.7 * ((a.z + b.z + c.z) / 3.0 + 0.5), 0.0, 1.0);
			return abs(pc.y - h.scan) < 2.0 ? pal[6] : shade > 0.6 ? pal[4] : pal[3];
		}
	}
	return vec4(0.0);
}

// the cone's edges and the stage ring: what put() leaves at cell q
vec4 cone_puts(Holo h, ivec2 q, float thr) {
	vec4 c = vec4(0.0);
	float y = float(q.y);
	if (y >= ceil(h.top) && y < LENS) {
		float v = (y - LENS) / (h.top - LENS);
		float w = mix(4.0, RAD + 4.0, v);
		float qq = abs(float(q.x) + 0.5) / w;
		if (float(q.x) >= floor(-w) && float(q.x) <= ceil(w) && qq <= 1.0 && qq > 1.0 - 1.0 / w) {
			c = v < 0.5 ? pal[5] : pal[4];
		}
	}
	for (int i = 0; i < 56; i++) {
		if (i % 7 >= 5) {
			continue;
		}
		float a = float(i) / 56.0 * TAU - h.ph * TAU;
		vec2 p = vec2(cos(a) * (RAD + 4.0), h.top + sin(a) * 3.0);
		if (all(equal(floor(p), vec2(q)))) {
			bool fr = sin(a) > 0.0;
			if ((fr ? 1.0 : 0.7) >= thr) {
				c = fr ? pal[6] : pal[4];
			}
		}
	}
	return c;
}

void fragment() {
	Holo h = setup();
	ivec2 P = ivec2(floor(center + (UV - 0.5) * size + 0.001));
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 put = vec4(0.0);
	if (!(h.flick && (P.y & 1) == 1)) {
		int dx = tear_at(P.y);
		if (dx == 0) {
			put = mode == 0 ? model_puts(h, P, thr) : cone_puts(h, P, thr);
		} else {
			int s = dx > 0 ? 1 : -1;
			vec4 c1 = mode == 0 ? model_puts(h, P - ivec2(dx + s, 0), thr) : cone_puts(h, P - ivec2(dx + s, 0), thr);
			if (c1.a > 0.0) {
				put = c1;
			} else {
				vec4 c2 = mode == 0 ? model_puts(h, P - ivec2(dx, 0), 0.0) : cone_puts(h, P - ivec2(dx, 0), 0.0);
				if (c2.a > 0.0 && 0.8 >= thr) {
					put = split_c;
				}
			}
		}
	}
	vec4 c = put;
	bool soft = false;
	if (c.a <= 0.0) {
		if (mode == 0) {
			c = faces(h, P);
		} else {
			float y = float(P.y);
			if (y >= ceil(h.top) && y < LENS) {
				// the cone's glassy inside, scanlines climbing it
				float v = (y - LENS) / (h.top - LENS);
				float w = mix(4.0, RAD + 4.0, v);
				float qq = abs(float(P.x) + 0.5) / w;
				if (qq <= 1.0 - 1.0 / w && float(P.x) >= floor(-w)) {
					bool line_on = mod(y + t * 24.0, 5.0) < 1.0;
					float a = (0.05 + 0.12 * (1.0 - v)) * (1.0 - 0.6 * qq * qq) + (line_on ? 0.06 : 0.0);
					c = vec4(line_on ? pal[5].rgb : pal[4].rgb, a);
					soft = true;
				}
			}
			if (P.y == -2 && c.a <= 0.0) {
				// the projector's lights, chasing
				for (int i = 0; i < 4; i++) {
					if (P.x == -9 + i * 6) {
						float k = 0.5 + 0.5 * cos(TAU * (2.0 * h.ph - float(i) / 4.0));
						c = k > 0.7 ? pal[6] : pal[3];
					}
				}
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, soft)) {
		discard;
	}
	COLOR = c;
}
