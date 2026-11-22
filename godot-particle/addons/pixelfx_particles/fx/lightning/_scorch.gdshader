// Heat left on the floor where a bolt landed (the lightning originals' scorch): a flat half-ellipse below the floor
// line, white-hot in the middle cooling down the fire ramp as `heat` falls, and soot where it's cold; `fade` takes
// the soot away. Draw it on a rect centred on the strike point at the floor.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform float rx = 7.0;
uniform float ry = 2.5;
uniform float heat = 0.0;
uniform float fade = 0.0;
uniform vec4 fire[9];
uniform vec4 soot : source_color;
uniform vec4 soot2 : source_color;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + 41.0) * 43758.5453);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (p.y < 0.0 || fade <= 0.0) {
		discard;
	}
	float d = length(vec2(p.x / rx, p.y / ry));
	if (d > 1.0) {
		discard;
	}
	float n = rnd(floor(p + center));
	float T = heat * (1.25 - d) - n * 0.35;
	vec4 c;
	if (T > 0.06) {
		c = fire[clamp(int(floor((1.0 - min(1.0, T)) * 8.0)), 0, 8)];
		c.a = fade;
	} else {
		c = d < 0.5 ? soot : soot2;
		c.a = (d < 0.95 - n * 0.3 ? 1.0 : 1.0 - d) * fade;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
