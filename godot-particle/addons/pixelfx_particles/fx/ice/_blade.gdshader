// The ice effects' blade(): a jagged ice blade standing on its base, tip at `tip`, `width` px wide at the base,
// shaded in the ice ramp (8 steps, dark to bright): a lit facet on the left with a pale edge and glitter, a bright
// ridge, a deep facet on the right, a white tip, a dark rim, and a notch (`jag`, 0..1, or -1) cut into one side.
// `white` flashes it, `glint` (0..1 or -1) runs a highlight across it, `dim` darkens it a step or more (back rows).
// Coordinates are px from the effect's origin (`center` is where the rect sits); `ymax` clips below the base.
// Key base, tip, width, glint, white, alpha. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 base = vec2(0.0);
uniform vec2 tip = vec2(0.0, -20.0);
uniform float width = 8.0;
uniform float jag = -1.0;
uniform float glint = -1.0;
uniform float white = 0.0;
uniform float dim = 0.0;
uniform float ymax = 0.0;
uniform float alpha = 1.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 K(float i) {
	float j = clamp(i - dim, 0.0, 7.0);
	return texture(ramp, vec2((j + 0.5) / 8.0, 0.5));
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 d = tip - base;
	float L = length(d);
	if (L < 1.5 || width < 0.5 || p.y > ymax) {
		discard;
	}
	vec2 uu = d / L;
	vec2 nn = vec2(-uu.y, uu.x);
	vec2 r0 = p - base;
	float u = dot(r0, uu) / L;
	float s = dot(r0, nn);
	if (u < 0.0) {
		discard;
	}
	float hw = width / 2.0;
	float um = min(u, 1.0);
	float l = hw * (1.0 - um) + 0.35;
	float r = hw * (1.0 - um) * ((jag >= 0.0 && um > jag) ? 0.55 : 1.0) + 0.35;
	vec4 c;
	if (u > 1.0 || s < -l || s > r) {
		float over = u > 1.0 ? (u - 1.0) * L : 0.0;
		float o = max(over, s < -l ? -l - s : s - r);
		if (o < 1.0 && u < 1.0 + 1.0 / L) {
			c = K(0.0);
		} else {
			discard;
		}
	} else if (white > 0.5) {
		c = vec4(1.0);
	} else {
		float rd = -width * 0.12 * (1.0 - u);
		bool six = false;
		if (u > 0.88) {
			c = vec4(1.0);
		} else if (abs(s - rd) < 0.55) {
			c = K(6.0);
			six = true;
		} else if (s < rd) {
			if (s + l < 1.0) {
				c = K(6.0);
				six = true;
			} else {
				c = (s + l) / max(1.0, rd + l) > 0.55 ? K(5.0) : K(4.0);
			}
		} else {
			c = r - s < 1.1 ? K(1.0) : ((s - rd) / max(1.0, r - rd) > 0.5 ? K(2.0) : K(3.0));
		}
		if (jag >= 0.0 && abs(u - jag) * L < 0.8 && s > rd) {
			c = K(6.0);
		} else if (s < rd && !six && u <= 0.88) {
			int h = (int(floor(p.x)) * 73856093) ^ (int(floor(p.y)) * 19349663);
			if (h < 0 || h % 997 < 30) {
				c = K(7.0);
			}
		}
		if (glint >= 0.0 && s <= rd + 0.6) {
			float g = abs(u - glint) * L;
			if (g < 0.8) {
				c = vec4(1.0);
			} else if (g < 1.8) {
				c = K(6.0);
			}
		}
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
