// The light of _funnel.gdshader: a small glow on the head of each of the brightest wind bands while it's on the
// near side. Same band uniforms; key `t` 0 -> 1 over the loop. Light layer (additive).
shader_type canvas_item;
render_mode blend_add;

const int NB = 58;
const float FH = 112.0;
const float SY = 0.28;
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 band_a[NB];
uniform vec4 band_b[NB];
uniform float radius = 5.0;
uniform float strength = 1.0;
uniform float alpha = 0.3;
uniform vec4 color : source_color = vec4(1.0);

float smooth_(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float ax(float u) {
	float ph = TAU * t;
	return 8.5 * sin(ph - 2.6 * u) * (0.2 + 0.8 * u) + 3.0 * sin(2.0 * ph + 1.3 - 4.5 * u) * u;
}

float rad(float u) {
	float f = smooth_(0.78, 1.0, u);
	return 3.0 + 20.0 * pow(u, 1.5) + 17.0 * f * f;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float k = 0.0;
	for (int j = 0; j < NB; j++) {
		vec4 a = band_a[j];
		vec4 b = band_b[j];
		if (a.x > 0.97 || b.y <= 0.6) {
			continue;
		}
		float head = a.z + TAU * b.x * t;
		if (sin(head) <= 0.0) {
			continue;
		}
		float r = rad(a.x) * a.y;
		vec2 h = vec2(ax(a.x) + r * cos(head), -a.x * FH + r * SY * sin(head));
		float d = length(p - h) / radius;
		if (d < 1.0) {
			k += (1.0 - d) * (1.0 - d);
		}
	}
	COLOR = vec4(color.rgb * k * alpha * strength, 1.0);
}
