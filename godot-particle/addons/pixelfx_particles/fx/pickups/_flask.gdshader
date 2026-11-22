// potion's flask (src/fx/pickups/potion.js flask() in a Layer, outlined in ink): a cork, a lip, a neck and a round
// bulb of glass, rocked by tilt (ct, st: its cos and sin), hovering at cy; inside it the brew below its sloshing
// surface (level in the world, lagging the rock), dark at the bottom and edges, a lit heart, a bright skin. ph (the
// loop's phase) moves the surface. The glass and cork colours are the original's mixes, worked out at build time.
// Keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 cork[5] : source_color;
uniform vec4 glass : source_color;
uniform vec4 ink : source_color;
// lip left / right, neck left / right, wall highlight, lit wall, empty wall
uniform vec4 lip_l : source_color;
uniform vec4 lip_r : source_color;
uniform vec4 neck_l : source_color;
uniform vec4 neck_r : source_color;
uniform vec4 wall_hi : source_color;
uniform vec4 wall_lit : source_color;
uniform vec4 wall_dry : source_color;
uniform float cy = -17.0;
uniform float ct = 1.0;
uniform float st = 0.0;
uniform float ph = 0.0;

const float RB = 7.0;
const float NECK = 2.0;
const float LIP = -12.0;
const float CORK_TOP = -16.0;

float surface(float x) {
	return -0.5 + 0.17 * sin(ph * TAU - 0.9) * x + 0.45 * sin(x * 0.85 + ph * TAU * 3.0);
}

// the flask's colour at pc (alpha 0: none)
vec4 flask_px(vec2 pc) {
	vec2 cl = floor(pc);
	if (cl.x < -20.0 || cl.x > 19.0 || cl.y < floor(cy) - 22.0 || cl.y > floor(cy) + 12.0) {
		return vec4(0.0);
	}
	float wx = pc.x;
	float wy = pc.y - cy;
	float fx = wx * ct + wy * st;
	float fy = -wx * st + wy * ct;
	float d = length(vec2(fx, fy));
	if (fy < LIP - 0.5 && fy >= CORK_TOP && abs(fx) <= NECK + 0.2) {
		return cork[fy < CORK_TOP + 1.0 ? 4 : fx < -0.6 ? 3 : fx > 1.0 ? 1 : 2];
	}
	if (fy >= LIP - 0.5 && fy < LIP + 1.0 && abs(fx) <= NECK + 1.4) {
		return fx < 0.0 ? lip_l : lip_r;
	}
	bool in_neck = fy >= LIP + 1.0 && fy < -RB + 2.0 && abs(fx) <= NECK + 0.6;
	if (d > RB && !in_neck) {
		return vec4(0.0);
	}
	bool wall = in_neck ? abs(fx) > NECK - 0.5 : d > RB - 1.0;
	float depth = wy - surface(wx);
	if (!wall && !in_neck && depth > 0.0) {
		float core = 1.0 - length(vec2(wx * 0.85, wy - 1.8)) / RB;
		if (depth < 0.9) {
			return (wx < -1.5 && wx > -4.5) ? vec4(1.0) : C[6];
		}
		int k = core > 0.62 ? 5 : core > 0.38 ? 4 : core > 0.18 ? 3 : 2;
		if (depth < 1.9 && k < 5) {
			k++;
		}
		if (wx > 1.5 && wy > 2.0) {
			k--;
		}
		return C[clamp(k, 2, 6)];
	}
	if (wall) {
		float lit = (-fx * 0.75 - fy * 0.66) / max(1.0, d);
		if (in_neck) {
			return fx < 0.0 ? neck_l : neck_r;
		}
		if (lit > 0.82) {
			return wall_hi;
		}
		if (lit > 0.3) {
			return wall_lit;
		}
		return depth > 0.0 ? C[3] : wall_dry;
	}
	return glass;
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	if (abs(pc.x) > 16.0 || pc.y < cy - 24.0 || pc.y > cy + 14.0) {
		discard;
	}
	vec4 c = flask_px(pc);
	if (c.a <= 0.0) {
		if (flask_px(pc + vec2(1.0, 0.0)).a > 0.0 || flask_px(pc - vec2(1.0, 0.0)).a > 0.0 || flask_px(pc + vec2(0.0, 1.0)).a > 0.0 || flask_px(pc - vec2(0.0, 1.0)).a > 0.0) {
			c = ink;
		} else {
			discard;
		}
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
