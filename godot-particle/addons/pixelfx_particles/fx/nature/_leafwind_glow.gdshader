// The light of _leafwind.gdshader: a small glow on the head of every wind band while it's on the near side.
// Same band uniforms; key `t` 0 -> 1 over the loop. Light layer (additive).
shader_type canvas_item;
render_mode blend_add;

const int NB = 22;
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 band_a[NB];
uniform vec4 band_b[NB];
uniform float count = 0.0;
uniform float radius = 5.0;
uniform float strength = 1.0;
uniform float alpha = 0.25;
uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float k = 0.0;
	for (int j = 0; j < NB; j++) {
		if (float(j) >= count) {
			break;
		}
		vec4 a = band_a[j];
		vec4 b = band_b[j];
		if (b.w > 0.5) {
			continue;
		}
		float head = a.z + TAU * b.x * t;
		if (sin(head) <= 0.0) {
			continue;
		}
		vec2 h = vec2(cos(head) * a.y, a.x + sin(head) * a.y * b.z);
		float d = length(p - h) / radius;
		if (d < 1.0) {
			k += (1.0 - d) * (1.0 - d);
		}
	}
	COLOR = vec4(color.rgb * k * alpha * strength, 1.0);
}
