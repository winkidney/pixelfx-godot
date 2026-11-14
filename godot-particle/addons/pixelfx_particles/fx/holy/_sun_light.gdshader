// The sunburst's light (holy/sunburst, light layer): the breathing gold glow, a soft beam down each ray, the glints'
// glows and the white glow of the core, summed as the original adds them. `t` runs 0..1 over the loop.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(128.0);
uniform float t = 0.0;
uniform int rays = 8;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float R0 = 9.0;

vec3 glow(vec2 p, vec2 at, float r, vec3 c, float k) {
	float f = 1.0 - length(p - at) / r;
	return f > 0.0 ? c * f * f * k : vec3(0.0);
}

vec3 glow_line(vec2 p, vec2 a, vec2 b, float r, vec3 c, float k) {
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float f = 1.0 - length(a + ab * u - p) / r;
	return f > 0.0 ? c * f * f * k : vec3(0.0);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	int N = rays * 2;
	float rot = t * (2.0 * TAU / float(N));
	vec3 l = glow(p, vec2(0.0), 62.0, pal[4].rgb, 0.3 + 0.06 * sin(t * TAU * 2.0));
	for (int i = 0; i < N; i++) {
		float a = rot + float(i) * TAU / float(N);
		bool long_ray = i % 2 == 0;
		float breathe = 0.86 + 0.14 * sin(a * 3.0 - t * TAU * 2.0);
		float L = (long_ray ? 36.0 : 21.0) * breathe;
		vec2 d = vec2(cos(a), sin(a));
		l += glow_line(p, d * R0, d * (R0 + L * 0.8), 5.0, pal[5].rgb, 0.16);
		if (long_ray) {
			float g = fract(t * 2.0 + a * 3.0 / TAU);
			if (g < 0.9) {
				l += glow(p, d * (R0 + g * L), 5.0, pal[6].rgb, 0.45 * (1.0 - g));
			} else {
				float n = round(1.0 + 3.0 * sin((g - 0.9) / 0.1 * PI));
				l += glow(p, d * (R0 + L), 4.0 + n * 2.0, vec3(1.0), 0.5);
			}
		}
	}
	l += glow(p, vec2(0.0), 16.0, vec3(1.0), 0.28);
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
