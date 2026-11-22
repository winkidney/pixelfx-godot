// The bullet tracer's trace (projectiles/bullet-tracer.js): a tapering body of burning gas behind the slug, banded
// white core, gold, an orange rim; past it a one-pixel line cooling to red whose brightness ripples back along it
// and whose cold end breaks into dashes. Coordinates are px from the effect's origin; key t (seconds) and fr (the
// frame, for the dashes).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float fr = 0.0;
uniform float period = 0.6;
uniform float len = 120.0;
uniform float seed = 4.0;
uniform vec4 cols[9];

float h1(float i) {
	return fract(sin(i * 127.1 + seed * 311.7) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(h1(i), h1(i + 1.0), u) * 2.0 - 1.0;
}

float heat(float d, float ph) {
	return 1.0 - pow(d / len, 0.8) + noise(d * 0.12 - t * 40.0) * 0.12 + 0.08 * sin(d * 0.35 - ph * 9.0);
}

float y_at(float d, float ph) {
	return 0.5 + sin(d * 0.09 + ph * 2.0) * (d / len) * 0.8;
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	vec2 p = cell + 0.5;
	float ph = 6.28318530718 * t / period;
	float hot = len * 0.32;
	vec4 col = vec4(0.0);
	float d = -p.x;
	float u = d / hot;
	if (u >= 0.0 && u <= 1.0) {
		float w = 0.7 + 2.3 * pow(1.0 - u, 1.4) * (0.9 + 0.1 * sin(d * 0.8 - ph * 12.0));
		float v = abs(p.y - y_at(d, ph)) / w;
		if (v <= 1.0) {
			float h = heat(d, ph);
			col = v < 0.38 ? (h > 0.8 ? vec4(1.0) : cols[7]) : v < 0.7 ? (h > 0.75 ? cols[7] : h > 0.6 ? cols[6] : cols[5]) : u < 0.5 ? cols[5] : cols[4];
		}
	}
	float dd = -cell.x;
	if (dd >= hot && dd <= len && cell.y == floor(y_at(dd, ph))) {
		float uu = dd / len;
		float h = heat(dd, ph);
		bool skip = uu > 0.55 && fract(sin(floor(dd / 3.0) * 12.9898 + fr * 78.233 + seed) * 43758.5453) < (uu - 0.55) * 1.6;
		if (!skip) {
			col = h > 0.55 ? cols[6] : h > 0.42 ? cols[5] : h > 0.3 ? cols[4] : h > 0.18 ? cols[3] : h > 0.08 ? cols[2] : cols[1];
			col.a = uu < 0.85 ? 1.0 : (1.0 - uu) / 0.15;
		}
	}
	if (col.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
