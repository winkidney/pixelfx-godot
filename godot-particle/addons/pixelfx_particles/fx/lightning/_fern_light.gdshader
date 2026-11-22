// The light the burning fern gives off (light layer): every burning pixel of _fern.gdshader's data within `reach`
// px adds a little, falling off as (1 - d)^2, as the original lights every fourth point of a branch.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform sampler2D data : filter_nearest;
uniform float t = 0.0;
uniform float snap = 0.05;
uniform float speed = 260.0;
uniform float reach = 5.0;
uniform float strength = 1.0;
uniform float gain = 0.0625;
uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	ivec2 p = ivec2(floor(UV * size));
	ivec2 n = ivec2(size);
	float cool = smoothstep(0.45, 0.85, t);
	float fade = 1.0 - smoothstep(0.78, 0.88, t);
	float sum = 0.0;
	int r = int(reach);
	for (int dy = -r; dy <= r; dy++) {
		for (int dx = -r; dx <= r; dx++) {
			ivec2 q = p + ivec2(dx, dy);
			if (q.x < 0 || q.y < 0 || q.x >= n.x || q.y >= n.y) {
				continue;
			}
			vec4 d = texelFetch(data, q, 0);
			if (d.a < 0.5 || d.g > 0.5) {
				continue;
			}
			float age = t - snap - d.r * 64.0 / speed;
			if (age < 0.0) {
				continue;
			}
			float k = exp(-age / 0.22) - cool * 0.3;
			float f = 1.0 - length(vec2(float(dx), float(dy))) / reach;
			if (k > 0.0 && f > 0.0) {
				sum += f * f * k;
			}
		}
	}
	COLOR = vec4(color.rgb * sum * gain * fade * strength, 1.0);
}
