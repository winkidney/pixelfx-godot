// The light the rune circle's runes throw (light layer): each rune's glow over it (bigger and brighter as the chasing
// light passes, dimmer behind) and a small one at its foot. `t` runs 0..1 over the loop. Coordinates: px from the
// effect's origin.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(120.0, 60.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float RR = 39.0;
uniform float SY = 0.3;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform float strength = 1.0;

float gap(float a, float b) {
	return abs(atan(sin(a - b), cos(a - b)));
}

float glow(vec2 p, vec2 at, float r) {
	float f = 1.0 - length(p - at) / r;
	return f > 0.0 ? f * f : 0.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float spin = t * TAU / 4.0;
	float chase = t * TAU * 2.0;
	vec3 sum = vec3(0.0);
	for (int k = 0; k < 12; k++) {
		float g = spin + (float(k) + 0.5) * TAU / 12.0;
		vec2 xy = vec2(cos(g) * RR, sin(g) * RR * SY);
		bool hot = min(gap(g, chase), gap(g, chase + PI)) < 0.2;
		float kk = hot ? 0.5 : (sin(g) < 0.0 ? 0.12 : 0.22);
		sum += c5.rgb * glow(p, xy - vec2(0.0, 3.0), hot ? 10.0 : 6.0) * kk;
		sum += c4.rgb * glow(p, xy, 5.0) * 0.15;
	}
	COLOR = vec4(sum * strength, 1.0);
}
