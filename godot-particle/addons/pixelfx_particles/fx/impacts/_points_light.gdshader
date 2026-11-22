// Many small glows at once (the light along hot cracks, embers caught in them): pts[i] = (x, y, a, b) in the effect's
// coordinates. mode 0, crack segments: a = distance along the crack; each glows (4 + 4h) px wide, 0.22 h strong, with
// h = heat * clamp(1.2 - a / 40), if h > 0.12. mode 1, embers: a = life, b = phase; k = 1 - (t - 0.1) / life, flicker
// f = 0.6 + 0.4 sin(23 t + b), a 4 px glow 0.35 k f strong. Key heat / t / fade.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 pts[200];
uniform float count = 0.0;
uniform float mode = 0.0;
uniform float heat = 0.0;
uniform float t = 0.0;
uniform float fade = 1.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = center + (UV - 0.5) * size;
	int n = int(count + 0.5);
	float sum = 0.0;
	for (int i = 0; i < 200; i++) {
		if (i >= n) {
			break;
		}
		vec4 s = pts[i];
		float r;
		float k;
		if (mode < 0.5) {
			float h = heat * clamp(1.2 - s.z / 40.0, 0.0, 1.0);
			if (h <= 0.12) {
				continue;
			}
			r = 4.0 + h * 4.0;
			k = 0.22 * h * fade;
		} else {
			float kk = 1.0 - (t - 0.1) / s.z;
			if (t < 0.1 || kk <= 0.0) {
				continue;
			}
			r = 4.0;
			k = 0.35 * kk * (0.6 + 0.4 * sin(t * 23.0 + s.w));
		}
		float f = 1.0 - length(p - s.xy) / r;
		if (f > 0.0) {
			sum += f * f * k;
		}
	}
	COLOR = vec4(color.rgb * sum * strength * COLOR.a, 1.0);
}
