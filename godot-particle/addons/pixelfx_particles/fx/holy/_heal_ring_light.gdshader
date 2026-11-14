// The healing ring's light (holy/heal-aoe, light layer): the floor glowing behind the front and fading after it,
// eight glows round the rolling ring and the riders' sparkles' glows. `time` is the effect's clock in seconds.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(220.0, 64.0);
uniform float time = 0.0;
uniform float reach = 104.0;
uniform vec4 pal[8] : source_color;
uniform vec4 riders[14];
uniform float strength = 1.0;

const float SY = 0.2;
const float SEED = 0.3;
const float ROLL = 1.0;

vec3 glow(vec2 p, vec2 at, float r, vec3 c, float k) {
	float f = 1.0 - length(p - at) / r;
	return f > 0.0 ? c * f * f * k : vec3(0.0);
}

float sstep(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float t = time;
	if (t < SEED) {
		discard;
	}
	float fr = reach * (1.0 - pow(1.0 - clamp((t - SEED) / ROLL, 0.0, 1.0), 3.0));
	vec3 l = vec3(0.0);
	// the wash
	if (fr >= 2.0 && t <= 2.6) {
		float d = length(vec2(p.x, p.y / SY));
		if (d <= fr) {
			float passed = SEED + ROLL * (1.0 - pow(1.0 - min(0.999, d / reach), 1.0 / 3.0));
			float kw = exp(-(t - passed) / 0.35) * sstep(fr, fr - 6.0, d) * (1.0 - sstep(1.4, 1.9, t));
			if (kw >= 0.04) {
				l += pal[4].rgb * 0.32 * kw;
			}
		}
	}
	float u = clamp((t - SEED) / (ROLL + 0.25), 0.0, 1.0);
	float k = u < 0.7 ? 1.0 : (1.0 - u) / 0.3;
	if (k > 0.0) {
		for (int i = 0; i < 8; i++) {
			float g = float(i) / 8.0 * TAU;
			l += glow(p, vec2(cos(g) * fr, sin(g) * fr * SY - 2.0), 16.0, pal[4].rgb, 0.22 * k);
		}
		for (int r = 0; r < 14; r++) {
			float g = riders[r].x + riders[r].y * (t - SEED) * 2.2;
			if (sin(g) >= 0.0) {
				float arm = 2.0 + (sin(t * 9.0 + riders[r].x * 5.0) > 0.3 ? 1.0 : 0.0);
				l += glow(p, vec2(cos(g) * fr, sin(g) * fr * SY - 1.0), 4.0 + arm * 2.0, vec3(1.0), 0.35 * k);
			}
		}
	}
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
