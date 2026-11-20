// fish-school's caustics: the light that comes down through rippling water as bright crossing lines, the original's
// per-pixel formula (p.light on each cell of a 132 x 76 box, brighter up top, falling off to its edges). Light layer;
// key t (0..1 over the loop).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(132.0, 76.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float x = cell.x;
	float y = cell.y;
	if (y < -38.0 || y >= 38.0 || x < -66.0 || x >= 66.0) {
		discard;
	}
	float a = t * TAU;
	float fall = clamp(1.0 - (pow(x / 64.0, 2.0) + pow(y / 40.0, 2.0)), 0.0, 1.0) * (0.6 + 0.4 * clamp(-y / 40.0 + 0.6, 0.0, 1.0));
	if (fall <= 0.0) {
		discard;
	}
	float u = x * 0.16 + 1.9 * sin(y * 0.12 + a);
	float v = y * 0.19 + 1.9 * sin(x * 0.1 - a);
	float n1 = sin(u) + sin(v);
	float sh = 0.75 + 0.25 * sin(x * 0.05 - y * 0.04 + 2.0 * a);
	float f = max(0.0, 1.0 - abs(n1) * 5.0) * fall * sh;
	vec3 l = f > 0.55 ? c4.rgb * 0.3 : (f > 0.25 ? c3.rgb * 0.14 : vec3(0.0));
	COLOR = vec4(l * strength, 1.0);
}
