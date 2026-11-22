// The original's sliver() (melee/_lib.js) flying out from the rect's centre, colour layer: up to 4 thin arcs, each
// sl[i] = (angle, radius at the start, speed px/s, arc length in radians), `q` s after they set off (keyed): radius
// r0 + v q, arc shrinking to 60% and colour stepping c0 -> c1 -> c2 as k = q / dur runs 0 -> 1, dithered out by 1 - k.
// Each arc is 1.4 px thick in the middle, pinched to nothing at its ends.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec4 sl[4];
uniform float count = 4.0;
uniform float q = -1.0;
uniform float dur = 0.12;
uniform float squash = 1.0;
// where the true centre sits inside its pixel (the rect is odd-sized round that pixel)
uniform vec2 frac_ = vec2(0.5);
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	if (q < 0.0 || q > dur) {
		discard;
	}
	float k = q / dur;
	vec2 p = floor((UV - 0.5) * size) + 0.5 - frac_;
	p.y /= squash;
	float d = length(p);
	float ang = atan(p.y, p.x);
	bool hit = false;
	for (int i = 0; i < 4; i++) {
		if (float(i) >= count) {
			break;
		}
		vec4 s = sl[i];
		float r = s.y + s.z * q;
		float arc = s.w * (1.0 - 0.4 * k);
		float da = mod(ang - s.x + 3.14159265, 6.2831853) - 3.14159265;
		float u = da / max(arc, 1e-3);
		if (abs(u) > 0.5) {
			continue;
		}
		float w = 1.4 * (1.0 - abs(u) * 2.0);
		if (abs(d - r) <= w * 0.5 + 0.35) {
			hit = true;
		}
	}
	if (!hit) {
		discard;
	}
	vec4 c = k < 0.4 ? c0 : k < 0.7 ? c1 : c2;
	c.a = 1.0 - k;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
