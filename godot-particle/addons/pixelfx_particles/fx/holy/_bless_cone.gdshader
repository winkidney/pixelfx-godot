// The blessing's cone of light (holy/blessing): four soft rays inside a cone widening to the floor, each shimmering
// a whole number of times a loop. mode 0: the faint gold haze (soft layer, translucent); mode 1: two rays showing as
// fine dithered lines with light running down them. `t` runs 0..1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/holy/_bless.gdshaderinc"

uniform vec2 size = vec2(52.0, 110.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform vec4 c6 : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	if (p.y < TOP || p.y > 0.5) {
		discard;
	}
	vec4 c = vec4(0.0);
	if (mode == 0) {
		float I = bless_ray(p.x / bless_half(p.y), t) * (0.6 + 0.4 * smoothstep(TOP, 0.0, p.y));
		if (I < 0.02) {
			discard;
		}
		c = vec4(c6.rgb, I * 0.13);
	} else {
		if (p.y > -1.0) {
			discard;
		}
		float y = floor(p.y);
		for (int i = 1; i <= 2; i++) {
			vec4 r = BLESS_RAYS[i];
			if (floor(p.x) == floor(r.x * bless_half(y))) {
				float pulse = 0.5 + 0.5 * sin(y * 0.11 - t * TAU * 3.0 + r.w);
				c = pulse > 0.85 ? vec4(1.0) : c6;
				c.a = (0.1 + 0.45 * pulse) * (0.5 + 0.5 * sin(t * TAU * r.z + r.w)) * smoothstep(TOP, TOP + 20.0, y);
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
