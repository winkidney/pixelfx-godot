// The divine shield's light (holy/divine-shield, light layer): a glow hugging the rim, a faint one filling the
// bubble, a pool along the floor and a small glow on each lit crossing of the equator. `t` runs 0..1 over the loop.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(96.0);
uniform float t = 0.0;
uniform float r = 30.0;
uniform float cy = -22.0;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

float glow(vec2 p, vec2 at, float rad) {
	float f = max(0.0, 1.0 - length(p - at) / rad);
	return f * f;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec3 l = pal[4].rgb * glow(p, vec2(0.0), r * 1.1) * 0.14;
	float f = max(0.0, 1.0 - abs(length(p) - r) / 6.0);
	l += pal[4].rgb * f * f * 0.32;
	float rf = sqrt(r * r - cy * cy);
	for (int i = -2; i <= 2; i++) {
		l += pal[4].rgb * glow(p, vec2(float(i) * rf * 0.5, -cy), 12.0) * 0.18;
	}
	float phi = t * PI / 4.0;
	for (int k = 0; k < 8; k++) {
		float lo = phi + float(k) * PI / 4.0;
		vec3 s = vec3(r * sin(lo), r * cos(lo) * sin(0.34), r * cos(lo) * cos(0.34));
		if (s.z >= r * 0.15) {
			l += pal[5].rgb * glow(p, s.xy, 4.0) * 0.3;
		}
	}
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
