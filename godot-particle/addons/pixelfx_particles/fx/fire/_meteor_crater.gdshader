// The meteor's crater (fire/meteor): molten rock pooled in the dent, hottest in the middle, cooling down the fire
// ramp over `cool_time` seconds to soot, and a lip of broken floor heaped round its edge, lit while it's hot.
// Key `age` (seconds since the impact) and `alpha` (its fade at the end). Pixels are the original's integer cells
// relative to the origin. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(84.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float age = 0.0;
uniform float alpha = 1.0;
uniform float seed = 104.0;
uniform float cool_time = 2.6;
uniform sampler2D hot : filter_nearest, repeat_disable;
uniform vec4 soot : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform vec4 soot2 : source_color = vec4(0.09, 0.07, 0.11, 1.0);
uniform vec4 shade : source_color = vec4(0.18, 0.16, 0.26, 1.0);
uniform vec4 lip_hot : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform vec4 lip_cool : source_color = vec4(0.4, 0.36, 0.55, 1.0);
uniform vec4 outline : source_color = vec4(0.1, 0.08, 0.13, 1.0);

float h1(float x, float s) {
	return fract(sin(x * 12.9898 + s * 78.233) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * size) + center - size * 0.5;
	float x = p.x;
	float y = p.y;
	vec4 c = vec4(0.0);
	// the lip: broken floor heaped up near the rim's ends
	float e = abs(x) / 40.0;
	float hh = 0.0;
	if (e >= 0.7 && e <= 1.0) {
		hh = floor(2.4 * sin((e - 0.7) / 0.3 * 3.14159265) * (0.6 + 0.4 * h1(x, seed + 7.0)) + 0.5);
	}
	if (hh > 0.0 && y <= -1.0 && y >= -hh) {
		c = (y == -hh) ? (age < 1.0 ? lip_hot : lip_cool) : shade;
	} else if (hh > 0.0 && y == 0.0) {
		c = outline;
	} else {
		float rx = 36.0 * min(1.0, age / 0.08);
		if (y < -1.0 || y > 3.0 || rx < 0.5) {
			discard;
		}
		float dx = (x + 0.5) / rx;
		float dy = (y + 0.5) / 6.0;
		float d = sqrt(dx * dx + dy * dy);
		if (d > 1.0) {
			discard;
		}
		float k = h1(x * 31.0 + y, seed + 5.0);
		float T = pow(clamp(1.0 - age / cool_time, 0.0, 1.0), 1.3) * (1.25 - d) - k * 0.35;
		if (T > 0.06) {
			float i = min(8.0, floor((1.0 - min(1.0, T)) * 8.0));
			c = texture(hot, vec2((i + 0.5) / 9.0, 0.5));
		} else {
			c = d < 0.55 ? soot : soot2;
			c.a = d < 0.95 - k * 0.3 ? 1.0 : 1.0 - d;
		}
	}
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
