// Streaks of light drawn up a beam (the original's cycle() lines in teleporter-pad.js and tractor-beam.js): each
// slot one of the original's, born and living as its rng(seed, i, 911) says (`bits`: born, life, x share), a short
// vertical line from (x, y) down to (x, y + len) climbing as it ages. Placed from the keyed clock `t` (s) as a
// 1 px wide quad one cell per row (dot1 texture, scaled); _vline.gdshader colours it along its length.
//   y = mix(y0, y1, k^pw), len = l0 + l1 k, alpha min(1, (1 - k) * fade); cone > 0: x = share * the beam's half
//   width at y (tractor-beam's half(): bot at the floor, top at `lens`), else x = share * width
shader_type particles;
render_mode disable_velocity, disable_force;

uniform float t = 0.0;
uniform float period = 1.0;
uniform sampler2D bits : filter_nearest, repeat_disable;
uniform float y0 = 0.0;
uniform float y1 = -80.0;
uniform float pw = 1.0;
uniform float l0 = 3.0;
uniform float l1 = 7.0;
uniform float fade = 1.2;
uniform float width = 1.0;
uniform float cone = 0.0;
uniform float bot = 32.0;
uniform float top = 5.5;
uniform float lens = -84.0;

void place(int i, inout mat4 tr, inout vec4 col, inout vec4 cu) {
	vec4 b = texelFetch(bits, ivec2(i, 0), 0);
	float age = mod(t - b.x, period);
	tr = mat4(vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	if (age >= b.y) {
		return;
	}
	float k = age / b.y;
	float y = mix(y0, y1, pow(k, pw));
	float x = b.z * (cone > 0.5 ? mix(bot, top, clamp(y / lens, 0.0, 1.0)) : width);
	float L = l0 + l1 * k;
	float c0 = floor(y);
	float c1 = floor(y + L);
	float n = c1 - c0 + 1.0;
	tr = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, n, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(x) + 0.5, c0 + n * 0.5, 0.0, 1.0));
	col = vec4(1.0, 1.0, 1.0, min(1.0, (1.0 - k) * fade));
	cu = vec4(n, 0.0, 0.0, 0.0);
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}
