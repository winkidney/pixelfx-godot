// key-glint's key (src/fx/pickups/key-glint.js key() in a Layer, outlined in C[0]): a bow ring, a collar, a shaft and
// a bit, shaded by which way each bit of metal faces the light from the top left, with the glint's slanted white band
// (at gu along the key) running down it. Hangs at (0, cy) turned by the angle whose cos and sin are ca, sa. Keyed
// every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform float cy = -19.0;
uniform float ca = 1.0;
uniform float sa = 0.0;
uniform float gu = -100.0;

const float MID = 8.0;
const float TIP = 17.5;

int part(float u, float v) {
	float rb = length(vec2(u, v));
	if (rb <= 4.6 && rb >= 2.1) {
		return 1;
	}
	if (u >= 4.3 && u <= 6.0 && abs(v) <= 1.9) {
		return 2;
	}
	if (u >= 6.0 && u <= TIP && abs(v) <= 1.0) {
		return 3;
	}
	if (u >= 12.6 && u <= TIP - 0.3 && v > 1.0 && v <= 4.6 && !(u > 14.3 && u < 15.4 && v > 2.7)) {
		return 4;
	}
	return 0;
}

// an index into C (8: white), -1 off the key
int key_px(vec2 pc) {
	vec2 c = floor(pc);
	if (c.x < -24.0 || c.x > 23.0 || c.y < floor(cy) - 20.0 || c.y > floor(cy) + 19.0) {
		return -1;
	}
	float dx = pc.x;
	float dy = pc.y - cy;
	float u = dx * ca + dy * sa + MID;
	float v = -dx * sa + dy * ca;
	int k = part(u, v);
	if (k == 0) {
		return -1;
	}
	float ny;
	if (k == 1) {
		float rb = length(vec2(u, v));
		float o = rb > 3.4 ? 1.0 : -1.0;
		float wx = (u / rb) * o;
		float wy = (v / rb) * o;
		ny = -(((wx * ca - wy * sa) * -0.6) + (wx * sa + wy * ca) * -0.8);
	} else {
		ny = v < -0.35 ? 0.8 : (v > 0.35 && k != 4) ? -0.6 : k == 4 ? (v > 3.6 ? -0.5 : 0.1) : 0.2;
	}
	int ci = ny > 0.55 ? 6 : ny > 0.15 ? 4 : ny > -0.3 ? 3 : 2;
	if (k == 2) {
		ci = min(7, ci + 1);
	}
	float g = abs(u + v * 0.45 - gu);
	if (g < 0.8) {
		return 8;
	}
	if (g < 2.0) {
		ci = min(7, ci + 2);
	}
	return ci;
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	if (abs(pc.y - cy) > 16.0 || abs(pc.x) > 20.0) {
		discard;
	}
	int k = key_px(pc);
	vec4 c;
	if (k >= 0) {
		c = k == 8 ? vec4(1.0) : C[k];
	} else if (key_px(pc + vec2(1.0, 0.0)) >= 0 || key_px(pc - vec2(1.0, 0.0)) >= 0 || key_px(pc + vec2(0.0, 1.0)) >= 0 || key_px(pc - vec2(0.0, 1.0)) >= 0) {
		c = C[0];
	} else {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
