// holy/resurrection: the halo as the original dots it (96 points round a flat ellipse over the head): it forms from
// the front round both ways (`form` 0..1), white for a beat when it closes (`white`), a glint running round it
// (`gl`, radians), the near half doubled with a gold underside. `k` fades it. Colour layer; px from the origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(28.0, 12.0);
uniform vec2 center = vec2(0.0);
uniform float form = 0.0;
uniform float k = 0.0;
uniform float white = 0.0;
uniform float gl = 0.0;
uniform vec4 pal[8] : source_color;

const float HX = 0.0;
const float HY = -47.0;
const float HRX = 9.5;
const float HRY = 2.6;

float wrap_pi(float a) {
	return abs(mod(a + PI, TAU) - PI);
}

void fragment() {
	vec2 cell = floor(floor((UV - 0.5) * size) + 0.5 + center);
	if (form <= 0.0 || k <= 0.0) {
		discard;
	}
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	for (int j = 0; j < 96; j++) {
		float g = float(j) / 96.0 * TAU;
		float ff = wrap_pi(g - PI / 2.0);
		if (ff > form * PI + 0.02) {
			continue;
		}
		vec2 q = vec2(HX + cos(g) * HRX * (0.9 + 0.1 * form), HY + sin(g) * HRY);
		bool near = sin(g) >= 0.0;
		bool hot = white > 0.5 || wrap_pi(g - gl) < 0.22 || ff > form * PI - 0.3;
		if (near) {
			if (floor(q) == cell && (k >= 1.0 || k > th)) {
				c = hot ? vec4(1.0) : pal[6];
			}
			if (floor(q + vec2(0.0, 1.0)) == cell && (k >= 1.0 || k > th)) {
				c = hot ? pal[6] : pal[4];
			}
		} else if (floor(q) == cell && k * 0.9 > th) {
			c = hot ? pal[6] : pal[5];
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
