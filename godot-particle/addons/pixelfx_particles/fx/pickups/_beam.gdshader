// loot-beam's column (src/fx/pickups/loot-beam.js column()), colour layer. part 0: the rows: bands of the ramp out
// from a white core, three strands drifting through it, pulses climbing it, a glint's trail darkening it, thinning
// and breaking into flickering dashes and threads toward the sky. part 1: the flare at its foot (sim.js flare: eight
// rays, long on the axes; dirs holds the original's own cos and sin of each). ph, beat, gh (the glint's height),
// flare_l and flare_k keyed every frame.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_beam.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform int part = 0;
uniform float gh = -100.0;
uniform float flare_l = 0.0;
uniform float flare_k = 0.0;
uniform vec2 dirs[8];
// where the flare is (chest-open uses it too)
uniform vec2 flare_at = vec2(0.5, -5.0);

vec4 rows(vec2 cell) {
	float y = cell.y;
	float x = cell.x;
	if (y > -1.0 || y < -H || !beam_row(y)) {
		return vec4(0.0);
	}
	float h = -y - 0.5;
	float u = h / H;
	float fade = 1.0 - beam_smooth(0.25, 1.0, u);
	float w = beam_w(h);
	int sg = beam_seg(h);
	int flick = int(floor(ph * 12.0));
	bool thread = u > 0.58 && js_rand3(sg, flick, 9) < (u - 0.58) * 3.0;
	float climb = mod(mod(h / 30.0 - ph * 3.0, 1.0) + 1.0, 1.0) < 0.1 ? 1.0 : 0.0;
	float trail = (gh - h > 0.0 && gh - h < 18.0) ? 1.0 - (gh - h) / 18.0 : 0.0;
	float X = thread ? 0.0 : ceil(w * 1.6);
	if (abs(x) > X) {
		return vec4(0.0);
	}
	float q = abs(x) / w;
	float cw = 0.2 + 0.18 * (1.0 - beam_smooth(0.0, 0.5, u));
	int lvl = q < cw ? 0 : q < 0.47 ? 1 : q < 0.72 ? 2 : q < 1.0 ? 3 : 4;
	for (int s = 0; s < 3; s++) {
		float sx = float(s - 1) * w * 0.55 + sin(h * 0.09 + ph * TAU * float(s + 1) + float(s) * 2.0) * 0.9;
		if (abs(x - sx) < 0.5) {
			lvl = max(0, lvl - 1);
		}
	}
	int shimmer = int(floor(ph * 24.0));
	if (js_rand3(int(y), shimmer, 3) < 0.05 && lvl > 0) {
		lvl--;
	}
	if (q < 0.72) {
		lvl = max(0, lvl - int(climb) - (trail > 0.3 ? 1 : 0));
	}
	float a = lvl <= 2 ? 1.0 : ((1.55 - q) / 0.75) * fade * 1.2;
	if (a <= 0.0) {
		return vec4(0.0);
	}
	vec3 c = thread ? (u > 0.85 ? C[6].rgb : vec3(1.0)) : lvl == 0 ? (u > 0.8 ? C[6].rgb : vec3(1.0)) : C[7 - lvl].rgb;
	return vec4(c, a);
}

vec4 flare(vec2 cell, float thr) {
	float L = flare_l;
	if (L < 1.0) {
		return vec4(0.0);
	}
	for (int i = 7; i >= 0; i--) {
		float len = i % 4 == 0 ? L : i % 2 == 0 ? L * 0.6 : L * 0.3;
		int n = int(floor(len / 0.5));
		for (int s = n; s >= 0; s--) {
			float d = float(s) * 0.5;
			vec2 p = flare_at + dirs[i] * d;
			if (floor(p) != cell) {
				continue;
			}
			float u = d / len;
			float a = u < 0.6 ? 1.0 : flare_k * 1.5 * (1.0 - u) + 0.2;
			if (a <= 0.0 || (a < 1.0 && a <= thr)) {
				continue;
			}
			return vec4(u < 0.35 ? vec3(1.0) : u < 0.7 ? C[6].rgb : C[5].rgb, 1.0);
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	vec4 c = vec4(0.0);
	if (part == 0) {
		if (abs(cell.x) > 16.0) {
			discard;
		}
		c = rows(cell);
	} else {
		if (any(greaterThan(abs(cell + 0.5 - flare_at), vec2(flare_l + 2.0)))) {
			discard;
		}
		c = flare(cell, pfx_threshold(FRAGCOORD.xy));
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
