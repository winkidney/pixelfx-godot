// The sprouting plus signs' light (holy/heal-aoe, light layer): a glow on each as it floats up, and the white glow of
// the sparkle it pops out of. Same sites as _heal_sprouts.gdshader. `time` is the effect's clock in seconds.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(220.0, 96.0);
uniform vec2 center = vec2(0.0);
uniform float time = 0.0;
uniform vec4 pal[8] : source_color;
uniform vec4 sa[26];
uniform vec4 sb[26];
uniform float strength = 1.0;

const float SY = 0.2;

vec3 glow(vec2 p, vec2 at, float r, vec3 c, float k) {
	float f = 1.0 - length(p - at) / r;
	return f > 0.0 ? c * f * f * k : vec3(0.0);
}

float out_back(float x, float s) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x >= 1.0) {
		return 1.0;
	}
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float t = time;
	vec3 l = vec3(0.0);
	for (int s = 0; s < 26; s++) {
		float a = t - sa[s].z;
		float life = sb[s].x;
		if (a < 0.0 || a > life) {
			continue;
		}
		bool back = sa[s].y < 0.0;
		float u = a / life;
		float h = sa[s].w * (1.0 - pow(1.0 - u, 3.0));
		vec2 at = vec2(sa[s].x + sin(a * 4.0 + sb[s].y) * 1.5 * u, sa[s].y * SY - 2.0 - h);
		float L = max(1.0, round(sb[s].z * out_back(clamp(a / 0.12, 0.0, 1.0), 2.6) - (back ? 1.0 : 0.0)));
		float end = life - 0.15;
		if (a < 0.04) {
			l += glow(p, at, 10.0, vec3(1.0), 0.5);
		}
		l += glow(p, at, 7.0 + L * 2.0, pal[5].rgb, (back ? 0.2 : 0.34) * (a < end ? 1.0 : 1.0 - (a - end) / 0.15));
	}
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
