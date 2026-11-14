// The smoke bomb's canister (explosions/smoke-bomb, the original's drawCanister): a round canister turned by its
// roll: dark metal lit from the top left, a red band, an outline, and a fuse on top while it's live (spent, its cap
// is blown off). Key `angle` (radians), `live` and `alpha`. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(16.0);
// the canister's centre inside the rect, px (it moves by keying the rect's position)
uniform vec2 sub = vec2(0.0);
uniform float radius = 4.0;
uniform float angle = 0.0;
uniform float live = 1.0;
uniform float alpha = 1.0;
uniform vec4 outline : source_color;
uniform vec4 k0 : source_color;
uniform vec4 k1 : source_color;
uniform vec4 k2 : source_color;
uniform vec4 k3 : source_color;
uniform vec4 k4 : source_color;
uniform vec4 band0 : source_color;
uniform vec4 band1 : source_color;
uniform vec4 band2 : source_color;
uniform vec4 fuse : source_color;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(1e-4, dot(ab, ab)), 0.0, 1.0);
	return length(p - a - ab * u);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 - sub;
	float ca = cos(angle);
	float sa = sin(angle);
	float d = length(p);
	vec2 cap = vec2(sa, -ca) * radius;
	vec4 c;
	if (d <= radius + 1.0) {
		if (d > radius) {
			c = outline;
		} else {
			float v = -p.x * sa + p.y * ca;
			float lit = -(p.x * 0.6 + p.y * 0.8) / radius;
			if (abs(v) < 0.9) {
				c = lit > 0.3 ? band2 : (lit > -0.4 ? band1 : band0);
			} else if (d < radius * 0.5 && lit > 0.45) {
				c = k4;
			} else {
				c = lit > 0.5 ? k3 : (lit > 0.0 ? k2 : (lit > -0.5 ? k1 : k0));
			}
		}
		if (live < 0.5 && length(p - cap) < 0.71) {
			c = k0;
		}
	} else if (live > 0.5 && seg(p, cap, cap + vec2(sa, -ca) * 2.5) < 0.6) {
		c = fuse;
	} else {
		discard;
	}
	c.a = alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
