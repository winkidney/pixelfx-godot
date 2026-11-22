// ice/ice-shatter's block of ice, seen from the front and a little above: a dark rim, a front face lit at the top and
// deep at the foot with reflections streaked across it, a lighter fracture plane and a shaded far corner, a pale top,
// a side in shadow, frost veins and trapped bubbles inside (`veins`, `bubbles`), lit edges. `sweep` runs a white
// reflection across the front; `white` flashes the whole block. Coordinates are px from the effect's origin
// (`center`). Colour layer; the ramp is the ice ramp, dark to bright.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(48.0);
uniform vec2 center = vec2(0.0);
uniform float sweep = -40.0;
uniform float white = 0.0;
uniform vec2 veins[32];
uniform float vein_count = 0.0;
uniform vec3 bubbles[5];
uniform float alpha = 1.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 C(int i) {
	return texture(ramp, vec2((float(i) + 0.5) / 8.0, 0.5));
}

uint mix32(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float jrand3(int a, int b, int c) {
	return float(mix32(mix32(mix32(0x9e3779b9u, a), b), c)) / 4294967296.0;
}

// even-odd point in polygon (up to 6 corners)
bool in_poly(vec2 q, vec2 pts[6], int n) {
	bool inside = false;
	int j = n - 1;
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		vec2 a = pts[i];
		vec2 b = pts[j];
		if ((a.y > q.y) != (b.y > q.y) && q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x) {
			inside = !inside;
		}
		j = i;
	}
	return inside;
}

// the original's 1 px line between two cells
bool on_line(ivec2 P, ivec2 A, ivec2 B) {
	ivec2 d = B - A;
	if (abs(d.x) >= abs(d.y)) {
		if (d.x == 0) {
			return P == A;
		}
		float u = float(P.x - A.x) / float(d.x);
		return u >= 0.0 && u <= 1.0 && P.y == A.y + int(round(u * float(d.y)));
	}
	float u = float(P.y - A.y) / float(d.y);
	return u >= 0.0 && u <= 1.0 && P.x == A.x + int(round(u * float(d.x)));
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	ivec2 P = ivec2(floor(p));
	vec2 rim[6] = vec2[](vec2(-17.0, 1.0), vec2(-17.0, -28.5), vec2(-8.3, -35.2), vec2(21.0, -35.2), vec2(21.0, -5.6), vec2(12.5, 1.0));
	vec2 sil[6] = vec2[](vec2(-16.0, 0.0), vec2(-16.0, -28.0), vec2(-8.0, -34.0), vec2(20.0, -34.0), vec2(20.0, -6.0), vec2(12.0, 0.0));
	vec2 front[6] = vec2[](vec2(-16.0, 0.0), vec2(-16.0, -28.0), vec2(12.0, -28.0), vec2(12.0, 0.0), vec2(0.0), vec2(0.0));
	vec2 top[6] = vec2[](vec2(-16.0, -28.0), vec2(-8.0, -34.0), vec2(20.0, -34.0), vec2(12.0, -28.0), vec2(0.0), vec2(0.0));
	vec2 side[6] = vec2[](vec2(12.0, 0.0), vec2(12.0, -28.0), vec2(20.0, -34.0), vec2(20.0, -6.0), vec2(0.0), vec2(0.0));
	vec2 plane[6] = vec2[](vec2(-16.0, -21.0), vec2(-5.0, -28.0), vec2(3.0, -13.0), vec2(-16.0, -9.0), vec2(0.0), vec2(0.0));
	vec2 shade[6] = vec2[](vec2(5.0, -28.0), vec2(12.0, -28.0), vec2(12.0, -10.0), vec2(0.0), vec2(0.0), vec2(0.0));
	bool hit = false;
	vec4 c = vec4(0.0);
	if (in_poly(p, rim, 6)) {
		c = C(0);
		hit = true;
	}
	if (white > 0.5) {
		if (in_poly(p, sil, 6)) {
			c = vec4(1.0);
			hit = true;
		}
	} else {
		float x = p.x;
		float y = p.y;
		if (in_poly(p, front, 4)) {
			float d = x + y * 0.8;
			hit = true;
			if (abs(d - sweep) < 1.3 && y < -6.0) {
				c = vec4(1.0);
			} else if (y < -9.0 && (abs(d + 21.0) < 1.1 || abs(d + 16.5) < 0.6)) {
				c = C(6);
			} else if (((abs(x + 7.5) < 0.5 && y < -6.0) || (abs(y + 5.5) < 0.5 && x > -8.0)) && ((int(floor(x)) + int(floor(y))) & 1) == 0) {
				c = C(5);
			} else if (in_poly(p, plane, 4)) {
				c = y < -25.5 ? C(6) : C(5);
			} else if (in_poly(p, shade, 3)) {
				c = C(3);
			} else {
				c = y < -25.5 ? C(5) : (y < -8.0 ? C(4) : (y < -2.5 ? C(3) : C(2)));
			}
		}
		if (in_poly(p, top, 4)) {
			hit = true;
			c = y > -29.5 ? C(7) : (y < -32.5 ? C(5) : (jrand3(int(floor(x)), int(floor(y)), 3) < 0.08 ? C(7) : C(6)));
		}
		if (in_poly(p, side, 4)) {
			hit = true;
			c = x < 13.5 ? C(3) : ((abs(x - 16.5) < 0.6 && y < -8.0) ? C(3) : (y > (x - 12.0) * -0.75 - 3.0 ? C(1) : C(2)));
		}
		for (int i = 0; i < 32; i++) {
			if (float(i) >= vein_count) {
				break;
			}
			if (ivec2(veins[i]) == P) {
				c = C(5);
				hit = true;
			}
		}
		for (int i = 0; i < 5; i++) {
			ivec2 b = ivec2(bubbles[i].xy);
			if (b == P) {
				c = C(6);
				hit = true;
			} else if (bubbles[i].z > 0.5 && (P == b + ivec2(1, 0) || P == b + ivec2(0, 1))) {
				c = C(5);
				hit = true;
			}
		}
		// edges
		if (on_line(P, ivec2(-16, -28), ivec2(12, -28))) { c = vec4(1.0); hit = true; }
		if (on_line(P, ivec2(-16, -28), ivec2(-8, -34))) { c = C(6); hit = true; }
		if (on_line(P, ivec2(-8, -34), ivec2(20, -34))) { c = C(5); hit = true; }
		if (on_line(P, ivec2(12, -28), ivec2(20, -34))) { c = C(7); hit = true; }
		if (on_line(P, ivec2(-16, -1), ivec2(-16, -28))) { c = C(5); hit = true; }
		if (on_line(P, ivec2(12, -1), ivec2(12, -28))) { c = C(6); hit = true; }
		if (on_line(P, ivec2(20, -6), ivec2(20, -34))) { c = C(3); hit = true; }
		if (on_line(P, ivec2(13, -1), ivec2(20, -6))) { c = C(1); hit = true; }
	}
	if (!hit) {
		discard;
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
