// heart-lost's heart (src/fx/ui/heart-lost.js drawPart and the socket): the 19 x 16 mask (`mask`), shaded as the
// original shades it (a lit left lobe with a white glint, shade down the right), outlined, with the crack running down
// it; whole, or as two halves split along the crack, each turned about its pivot; the empty socket under them.
// pa[j]: side (-1 left, 1 right, 0 whole), x, y, turn; pb[j]: white, crack (0..1), alpha, on. Keyed every frame.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 S[3] : source_color;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform float crack_x[16];
uniform float sk = 0.0;
uniform vec4 pa[2];
uniform vec4 pb[2];

const float OX = -9.5;
const float OY = -8.0;

bool in_mask(int i, int j) {
	return i >= 0 && j >= 0 && i < 19 && j < 16 && texelFetch(mask, ivec2(i, j), 0).r > 0.5;
}

bool own(int i, int j, float side) {
	if (!in_mask(i, j)) {
		return false;
	}
	if (side == 0.0) {
		return true;
	}
	float cx = crack_x[j];
	return side < 0.0 ? float(i) < cx : float(i) >= cx;
}

vec3 shade_at(int i, int j) {
	float u = (float(i) - 9.0) / 9.5;
	float v = (float(j) - 7.0) / 8.0;
	if ((i == 3 || i == 4) && (j == 2 || j == 3) && !(i == 4 && j == 3)) {
		return vec3(1.0);
	}
	if (i >= 2 && i <= 5 && j >= 2 && j <= 5 && u + v < -0.75) {
		return C[5].rgb;
	}
	float l = -(u * 0.55 + v * 0.65);
	return l > 0.25 ? C[4].rgb : l > -0.3 ? C[3].rgb : l > -0.6 ? C[2].rgb : C[1].rgb;
}

// part j at pixel centre pc: true and its colour and alpha when it draws there
bool part(int k, vec2 pc, out vec4 c) {
	c = vec4(0.0);
	vec4 a = pa[k];
	vec4 b = pb[k];
	if (b.w < 0.5) {
		return false;
	}
	vec2 cell = floor(pc);
	if (cell.x < floor(a.y - 13.0) || cell.x > ceil(a.y + 13.0) || cell.y < floor(a.z - 13.0) || cell.y > ceil(a.z + 13.0)) {
		return false;
	}
	float side = a.x;
	float ca = cos(a.w);
	float sa = sin(a.w);
	float px0 = side < 0.0 ? -4.5 : side > 0.0 ? 4.5 : 0.0;
	float dx = pc.x - a.y;
	float dy = pc.y - a.z;
	float lx = dx * ca + dy * sa + px0;
	float ly = -dx * sa + dy * ca;
	int i = int(floor(lx - OX));
	int j = int(floor(ly - OY));
	if (!own(i, j, side)) {
		return false;
	}
	bool edge = !own(i - 1, j, side) || !own(i + 1, j, side) || !own(i, j - 1, side) || !own(i, j + 1, side);
	vec3 col;
	if (b.x > 0.5) {
		col = edge ? C[6].rgb : vec3(1.0);
	} else if (edge) {
		col = C[0].rgb;
	} else {
		col = shade_at(i, j);
		if (side == 0.0 && float(j) / 16.0 < b.y) {
			if (float(i) == crack_x[j]) {
				col = C[0].rgb;
			} else if (float(i) == crack_x[j] - 1.0) {
				col = C[6].rgb;
			}
		}
	}
	c = vec4(col, b.z);
	return true;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 pc = cell + 0.5;
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	bool hit = false;
	for (int k = 1; k >= 0; k--) {
		vec4 q;
		if (part(k, pc, q) && (q.a >= 1.0 || q.a > th)) {
			c = vec4(q.rgb, 1.0);
			hit = true;
			break;
		}
	}
	if (!hit && sk > 0.0 && cell.x >= -12.0 && cell.x <= 12.0 && cell.y >= -10.0 && cell.y <= 10.0) {
		int i = int(floor(pc.x - OX));
		int j = int(floor(pc.y - OY));
		if (in_mask(i, j) && (sk >= 1.0 || sk > th)) {
			bool edge = !in_mask(i - 1, j) || !in_mask(i + 1, j) || !in_mask(i, j - 1) || !in_mask(i, j + 1);
			c = vec4(edge ? S[2].rgb : j < 3 ? S[1].rgb : S[0].rgb, 1.0);
			hit = true;
		}
	}
	if (!hit || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
