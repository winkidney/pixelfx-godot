// The seam racing along the floor ahead of the thorns (nature/thorns): a dark split, glowing green near its running
// head (`run` px from the origin; `cool` 0..1 dims the glow away), pale crumbs on its lip; fades with `alpha`.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 soil_dark : source_color = vec4(0.07, 0.05, 0.05, 1.0);
uniform vec4 soil_shade : source_color = vec4(0.15, 0.1, 0.09, 1.0);
uniform vec4 soil_lip : source_color = vec4(0.44, 0.33, 0.25, 1.0);
uniform vec4 glow_mid : source_color = vec4(0.42, 0.72, 0.23, 1.0);
uniform vec4 glow_hot : source_color = vec4(0.78, 0.94, 0.44, 1.0);
uniform float run = 0.0;
uniform float cool = 1.0;
uniform float alpha = 1.0;

float rnd(float a, float b) {
	return fract(sin(a * 12.9898 + b * 78.233) * 43758.5453);
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size + center);
	if (q.x < -2.0 || q.x > run) {
		discard;
	}
	float hot = clamp(1.0 - (run - q.x) / 18.0, 0.0, 1.0) * cool;
	float hh = rnd(q.x, 31.0);
	vec4 c = vec4(0.0);
	if (q.y == 0.0) {
		c = hot > 0.4 ? glow_hot : hot > 0.1 ? glow_mid : soil_dark;
	} else if (q.y == 1.0 && hh < 0.5) {
		c = vec4(soil_shade.rgb, 0.8);
	} else if (q.y == -1.0 && hh < 0.15) {
		c = soil_lip;
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
