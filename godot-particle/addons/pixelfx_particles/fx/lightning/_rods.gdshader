// Heat along the spark-arc's rods: `data` holds, per rod pixel, its height (r * 64 px) and whether it's the rod's
// lit core (g 0) or its shaded side (g 1). The arc climbs past each height on the original's curve and leaves it
// white-hot, cooling down the fire ramp; cold pixels are left to the prop's steel. Key `t` 0 -> period.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform sampler2D data : filter_nearest;
uniform float t = 0.0;
uniform float period = 2.0;
uniform float snap = 1.42;
uniform float climb = 58.0;
uniform vec4 fire[9];
uniform vec4 steel : source_color;

vec4 heat(float T) {
	return fire[clamp(int(floor((1.0 - min(1.0, T)) * 8.0)), 0, 8)];
}

void fragment() {
	vec4 d = texelFetch(data, ivec2(floor(UV * size)), 0);
	if (d.a < 0.5) {
		discard;
	}
	float hh = d.r * 64.0;
	float tp = snap * pow(clamp((hh - 1.5) / climb, 0.0, 1.0), 1.0 / 1.35);
	float age = t >= tp ? t - tp : t - tp + period;
	float hot = hh > climb + 2.0 ? 0.0 : exp(-age / 0.26);
	float T = hot * 1.05 - 0.12;
	if (T <= 0.06) {
		discard;
	}
	vec4 c = heat(T);
	if (d.g > 0.5) {
		if (hot <= 0.35) {
			discard;
		}
		c = hot * 0.6 > 0.06 ? heat(hot * 0.6) : steel;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
