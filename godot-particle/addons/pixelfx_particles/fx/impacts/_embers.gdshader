// Embers caught in the cracks (src/fx/impacts/ground-slam.js): pts[i] = (x, y, life, phase); each a pixel flickering
// hi / mid / lo as k f falls, k = 1 - (t - 0.1) / life, f = 0.6 + 0.4 sin(23 t + phase). t is the effect's time.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 pts[64];
uniform float count = 0.0;
uniform float t = 0.0;
uniform vec4 hi : source_color = vec4(1.0);
uniform vec4 mid : source_color = vec4(1.0);
uniform vec4 lo : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor(center + (UV - 0.5) * size);
	int n = int(count + 0.5);
	vec4 c = vec4(0.0);
	for (int i = 0; i < 64; i++) {
		if (i >= n) {
			break;
		}
		vec4 s = pts[i];
		float k = 1.0 - (t - 0.1) / s.z;
		if (t < 0.1 || k <= 0.0 || any(notEqual(floor(s.xy), cell))) {
			continue;
		}
		float kf = k * (0.6 + 0.4 * sin(t * 23.0 + s.w));
		c = kf > 0.55 ? hi : kf > 0.25 ? mid : lo;
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
