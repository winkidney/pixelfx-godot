// The jetpack (src/fx/scifi/jetpack.js), from the keyed clock `t` and the frame's jitter (`data`, one column a frame:
// each plume's x and length, the pack's bob):
//   mode 0: the twin plumes: cones of heat torn ragged by noise streaming down them (the original's tileFbm), white
//           at the heart, red at the edges with a dark red rim; shock diamonds strung down each core, breathing
//   mode 1: the pack: twin tanks with rounded caps, a spine between them, belled nozzles glowing hot inside
// Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(96.0, 116.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform int seed = 30;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;
uniform vec4 metal[6] : source_color;

const float D = 2.0;
const float GAP = 8.0;

int wrapi(int i, int p) {
	return p > 0 ? imod(i, p) : i;
}

float tile_noise(float x, float y, int px, int py, int sd) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int x0 = wrapi(int(ix), px);
	int x1 = wrapi(int(ix) + 1, px);
	int y0 = wrapi(int(iy), py);
	int y1 = wrapi(int(iy) + 1, py);
	float a = float(js_hash3(x0, y0, sd)) / 4294967296.0;
	float b = float(js_hash3(x1, y0, sd)) / 4294967296.0;
	float c = float(js_hash3(x0, y1, sd)) / 4294967296.0;
	float d = float(js_hash3(x1, y1, sd)) / 4294967296.0;
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

vec4 F() {
	return texelFetch(data, ivec2(clamp(int(floor(t * 30.0 + 0.5)), 0, 59), 0), 0);
}

vec4 plume(vec2 pc, ivec2 P, int side) {
	vec4 f = F();
	float s = side == 0 ? -1.0 : 1.0;
	float cx = side == 0 ? f.x : f.z;
	float L = side == 0 ? f.y : f.w;
	float dy = texelFetch(data, ivec2(clamp(int(floor(t * 30.0 + 0.5)), 0, 59), 1), 0).x;
	float ph = t / D;
	vec4 c = vec4(0.0);
	float x = pc.x;
	float y = pc.y;
	if (float(P.x) >= floor(cx - 7.0) && float(P.x) <= ceil(cx + 7.0) && float(P.y) >= floor(dy) && float(P.y) <= ceil(dy + L + 4.0)) {
		float v = (y - dy) / L;
		float w = mix(3.4, 0.6, v) + 1.4 * sin(v * PI) * (v < 1.0 ? 1.0 : 0.0);
		int sd = seed + (s > 0.0 ? 9 : 0);
		float nx = (x - cx) / 3.0 + s * 5.0;
		float ny = (y - dy) / 4.0 - ph * 20.0;
		float n = (tile_noise(nx, ny, 0, 10, sd) * 0.5 + tile_noise(nx * 2.0, ny * 2.0, 0, 20, sd + 101) * 0.25) / 0.75;
		float q = abs(x - cx) / w + n * 0.45;
		if (!(v > 1.15 || q > 1.2)) {
			float heat = (1.0 - v) * 1.15 - q * 0.9 + n * 0.25;
			if (q > 0.95) {
				c = heat > 0.2 ? pal[3] : pal[2];
				if (heat < -0.3) {
					c.a = 0.5;
				}
			} else {
				c = heat > 0.82 ? vec4(1.0) : heat > 0.62 ? pal[6] : heat > 0.42 ? pal[5] : heat > 0.22 ? pal[4] : heat > 0.02 ? pal[3] : pal[2];
			}
		}
	}
	// shock diamonds strung down the core
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float yy = floor(dy + 5.0 + fi * 6.5 + sin(TAU * 4.0 * ph + fi) * 0.5 + 0.5);
		float r = floor(2.2 - fi * 0.45 + 0.4 * sin(TAU * 8.0 * ph + fi * 2.0) + 0.5);
		if (yy > dy + L * 0.75 || r < 1.0) {
			break;
		}
		vec2 o = vec2(P) - vec2(floor(cx), yy);
		float d = abs(o.x) + abs(o.y);
		if (d <= r) {
			c = d < r ? vec4(1.0) : i == 0 ? pal[6] : pal[5];
		}
	}
	return c;
}

vec4 pack(vec2 pc, ivec2 P) {
	float dy = texelFetch(data, ivec2(clamp(int(floor(t * 30.0 + 0.5)), 0, 59), 1), 0).x;
	vec4 c = vec4(0.0);
	for (int side = 0; side < 2; side++) {
		float cx = (side == 0 ? -1.0 : 1.0) * GAP;
		if (pc.x >= cx - 5.5 && pc.x <= cx + 5.5 && pc.y >= -24.5 + dy && pc.y <= -2.5 + dy) {
			float u = (pc.x - cx) / 4.5;
			float top = -19.0 + dy;
			float v = pc.y < top ? (pc.y - top) / 4.5 : 0.0;
			if (u * u + v * v <= 1.0) {
				float l = -u * 0.8 - v * 0.6;
				c = u * u + v * v > 0.78 ? metal[0] : abs(pc.y - (-12.0 + dy)) < 0.6 ? metal[1] : l > 0.55 ? metal[5] : l > 0.15 ? metal[4] : l > -0.35 ? metal[3] : metal[2];
			}
		}
		// the nozzle bell, wider at its mouth, its inside lit by the flame
		int y = P.y - int(dy);
		if (y >= -3 && y <= 0) {
			float w = 2.0 + float(y + 3) * 0.7;
			float x = float(P.x);
			if (x >= floor(cx - w) && x <= ceil(cx + w)) {
				bool inner = abs(x + 0.5 - cx) < w - 1.2 && y >= -1;
				c = inner ? (y == 0 ? pal[6] : pal[4]) : abs(x + 0.5 - cx) > w - 0.6 ? metal[0] : x < cx ? metal[3] : metal[1];
			}
		}
	}
	int y = P.y - int(dy);
	if (y >= -20 && y <= -6) {
		if (P.x == -1) {
			c = metal[1];
		} else if (P.x == 0) {
			c = metal[2];
		} else if (P.x == 1) {
			c = metal[0];
		}
	}
	if (P.x == 0 && y == -16) {
		c = pal[5];
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	vec4 c = vec4(0.0);
	if (mode == 0) {
		c = plume(pc, P, 0);
		vec4 c2 = plume(pc, P, 1);
		if (c2.a > 0.0) {
			c = c2;
		}
	} else {
		c = pack(pc, P);
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, false)) {
		discard;
	}
	COLOR = c;
}
