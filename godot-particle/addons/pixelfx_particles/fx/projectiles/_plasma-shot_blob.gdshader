// The plasma shot's blob (projectiles/plasma-shot.js): a field of balls (the body, three hot knots churning round
// inside it at their own speeds, a wagging tail tapering behind, and the droplets the air tears off its end, keyed
// from the build script) whose skin comes from the summed field, so the tail tapers and the droplets neck as they
// part; the hot bands inside come from the balls' cores (a deep rim, the body, a bright inner, a pale core, white
// where the knots run hottest). Behind it, the ion streak left in the air, rippling and cooling in steps; over it, a
// white point on each young droplet. Coordinates are px from the effect's origin; key t (0 -> 1 over the loop).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(88.0, 44.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float R = 6.0;
uniform vec4 cols[8];
// the droplets: (x, y, radius, heat) and (core, age / life, -, -); radius 0: none
uniform vec4 drop_a[11];
uniform vec4 drop_b[11];
// where the droplets stop being lit (the canvas' left edge + 4)
uniform float left = -100.0;

void ball(vec2 p, vec2 at, float r, float hh, float core, inout float f, inout float heat, inout float hot) {
	if (r <= 0.0) {
		return;
	}
	vec2 d = p - at;
	float d2 = dot(d, d);
	float q = d2 / (4.0 * r * r);
	if (q < 1.0) {
		float c = (1.0 - q) * (1.0 - q) / 0.5625;
		f += c;
		heat += c * hh;
	}
	hot += core * core * r * r / (d2 + 0.3);
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	vec2 p = cell + 0.5;
	float TAU_ = 6.28318530718;
	float w = TAU_ * t;
	vec4 col = vec4(0.0);

	// the ion streak: a dot every px back from T0, its second row while it's young
	float T0 = -R * 3.2;
	float j = floor(T0 - cell.x);
	if (j >= 0.0 && j < 44.0) {
		float x = T0 - j;
		float u = (T0 - x) / 44.0;
		float y = floor(sin(x * 0.2 + w * 2.0) * (0.3 + ((T0 - x) / 44.0) * 1.8));
		if (cell.y == y) {
			col = u < 0.2 ? cols[6] : u < 0.45 ? cols[5] : cols[4];
			col.a = u < 0.55 ? 1.0 : (1.0 - u) / 0.45;
		} else if (cell.y == y + 1.0 && u < 0.3) {
			col = u < 0.15 ? cols[5] : cols[4];
		}
	}

	// the field
	float f = 0.0;
	float heat = 0.0;
	float hot = 0.0;
	ball(p, vec2(0.0), R, 1.0, 0.8, f, heat, hot);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float sp = i == 0 ? 2.0 : (i == 1 ? -3.0 : 5.0);
		float a = w * sp + fi * TAU_ / 3.0;
		float d = R * (0.5 + 0.1 * sin(w * 3.0 + fi * 2.0));
		ball(p, vec2(cos(a) * d - 0.4, sin(a) * d * 0.8), R * 0.32, 1.0, 1.0, f, heat, hot);
	}
	for (int i = 1; i <= 6; i++) {
		float fi = float(i);
		float r = R * (0.62 - fi * 0.08);
		ball(p, vec2(-R * (0.5 + fi * 0.42), sin(w * 2.0 - fi * 0.9) * (0.3 + fi * 0.28)), r, 0.96 - fi * 0.05,
			sqrt((5.2 - fi * 0.65) * 0.3) / r, f, heat, hot);
	}
	for (int i = 0; i < 11; i++) {
		ball(p, drop_a[i].xy, drop_a[i].z, drop_a[i].w, drop_b[i].x, f, heat, hot);
	}
	if (f >= 1.0) {
		int lvl = hot > 10.0 ? 7 : hot > 4.6 ? 6 : hot > 2.2 ? 5 : f > 1.4 ? 4 : 3;
		int cap = int(round(2.0 + (heat / f) * 5.4));
		int l = p.x > R * 0.3 && lvl < 5 ? lvl + 1 : lvl;
		col = cols[max(2, min(l, cap))];
	}

	// a white point on each young droplet that's pulled clear
	for (int i = 0; i < 11; i++) {
		vec4 a = drop_a[i];
		vec4 b = drop_b[i];
		if (a.z > 0.0 && a.x >= left && b.y < 0.6 && a.x < -R * 3.5 && cell == floor(a.xy)) {
			col = b.y < 0.3 ? cols[7] : cols[6];
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
