// power-star's star (src/fx/pickups/power-star.js star() in a Layer, outlined in ink): five arms, each with a ridge
// down its middle, the two halves of an arm catching the light differently, a white heart; centred on (0, cy), turned
// by rot, swollen by sc. Keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color = vec4(0.1, 0.055, 0.016, 1.0);
uniform float cy = -25.0;
uniform float rot = 0.0;
uniform float sc = 1.0;

const float RO = 11.5;
const float RI = 5.2;

// an index into C (8: white), -1 off the star
int star_px(vec2 pc) {
	vec2 c = floor(pc);
	if (c.x < -21.0 || c.x > 20.0 || c.y < floor(cy) - 21.0 || c.y > floor(cy) + 20.0) {
		return -1;
	}
	float dx = pc.x / sc;
	float dy = (pc.y - cy) / sc;
	float r = length(vec2(dx, dy));
	if (r > RO + 0.5) {
		return -1;
	}
	float a = atan(dy, dx) - rot + PI / 2.0;
	a = mod(a, TAU);
	float k = floor(a / (PI / 5.0));
	float half_ = mod(k, 2.0);
	float sgn = half_ > 0.5 ? -1.0 : 1.0;
	float tip = (floor(k / 2.0) + half_) * (2.0 * PI / 5.0);
	float tA = tip - PI / 2.0 + rot;
	float iA = tA + sgn * (PI / 5.0);
	float tx = cos(tA) * RO;
	float ty = sin(tA) * RO;
	float ix = cos(iA) * RI;
	float iy = sin(iA) * RI;
	float ex = ix - tx;
	float ey = iy - ty;
	float side = (dx - tx) * ey - (dy - ty) * ex;
	float cside = -tx * ey + ty * ex;
	if (side * cside < 0.0) {
		return -1;
	}
	float LA = atan(-0.8, -0.6);
	float l = cos(tA + sgn * (PI / 2.0) - LA);
	bool ridge = abs(sin(atan(dy, dx) - tA)) * r < 0.6;
	if (r < 1.2) {
		return 8;
	}
	float toLight = cos(tA - LA);
	if (ridge) {
		return toLight > 0.3 ? 8 : toLight > -0.4 ? 6 : 5;
	}
	return l > 0.6 ? 6 : l > 0.15 ? 5 : l > -0.35 ? 4 : l > -0.75 ? 3 : 2;
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	if (abs(pc.y - cy) > 17.0 || abs(pc.x) > 17.0) {
		discard;
	}
	int k = star_px(pc);
	vec4 c;
	if (k >= 0) {
		c = k == 8 ? vec4(1.0) : C[k];
	} else if (star_px(pc + vec2(1.0, 0.0)) >= 0 || star_px(pc - vec2(1.0, 0.0)) >= 0 || star_px(pc + vec2(0.0, 1.0)) >= 0 || star_px(pc - vec2(0.0, 1.0)) >= 0) {
		c = ink;
	} else {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
