// The holy pillar's sun (holy/holy-pillar, colour layer): a white heart, a cream ring, an outer ring whose white
// beads tick round, and sixteen short rays turning with it, long and short by turns. `r` is its radius (keyed, it
// opens like an iris), `spin` its turn in radians.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float r = 0.0;
uniform float spin = 0.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (r <= 0.5) {
		discard;
	}
	float d = length(p);
	float g = atan(p.y, p.x);
	vec4 c = vec4(0.0);
	if (d <= r * 0.45) {
		c = vec4(1.0);
	} else if (abs(d - r * 0.62) < 0.5) {
		c = c6;
	} else if (abs(d - r) < 0.5) {
		c = sin(g * 6.0 + spin * 4.0) > 0.5 ? vec4(1.0) : c5;
	} else if (d >= r + 2.0) {
		for (int j = 0; j < 16; j++) {
			float a = spin + float(j) * TAU / 16.0;
			vec2 dir = vec2(cos(a), sin(a));
			float l = j % 2 == 1 ? 3.0 : 6.0;
			float u = (dot(p, dir) - (r + 2.0)) / l;
			float across = abs(-p.x * dir.y + p.y * dir.x) / max(abs(dir.x), abs(dir.y));
			if (u >= 0.0 && u <= 1.0 && across < 0.5) {
				c = vec4((u < 0.4 ? c6 : c4).rgb, 1.1 - u);
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
