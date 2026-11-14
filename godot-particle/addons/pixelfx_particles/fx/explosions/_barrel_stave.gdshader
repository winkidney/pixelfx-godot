// A stave torn off the drum (explosions/barrel-explosion; the original's stave()): a curved plate L px long at `pos`
// turned by `a`, drawn dot by dot along its bow as the original does: an outline on one side, the painted face (or
// the dark inside, as it turns) down the middle, hot ends glowing while `heat` > 0.3. `fade` dithers it out. Colour
// layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform vec2 pos = vec2(0.0);
uniform float a = 0.0;
uniform float len = 10.0;
uniform float heat = 0.0;
uniform float fade = 1.0;
uniform vec4 face_lit : source_color;
uniform vec4 face_dark : source_color;
uniform vec4 inside : source_color;
uniform vec4 outline : source_color;
uniform vec4 hot1 : source_color;
uniform vec4 hot2 : source_color;

void fragment() {
	vec2 cell = floor((UV - 0.5) * size) + center;
	float ca = cos(a);
	float sa = sin(a);
	bool face = cos(a * 1.7) > 0.0;
	vec4 c = vec4(0.0);
	bool hit = false;
	for (float d = -len / 2.0; d <= len / 2.0 + 1e-4; d += 0.5) {
		float u = 2.0 * d / len;
		float bow = (1.0 - u * u) * 1.2;
		vec2 q = pos + vec2(ca * d - sa * bow, sa * d + ca * bow);
		bool hot = heat > 0.3 && abs(d) > len / 2.0 - 1.0;
		if (floor(q + vec2(sa, -ca)) == cell) {
			c = outline;
			hit = true;
		}
		if (floor(q) == cell) {
			c = hot ? (heat > 0.6 ? hot1 : hot2) : (face ? face_lit : inside);
			hit = true;
		}
		if (floor(q - vec2(sa, -ca)) == cell) {
			c = face ? face_dark : outline;
			hit = true;
		}
	}
	if (!hit) {
		discard;
	}
	c.a = fade;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
