// The hex sigil's traced strokes and glyphs (after the original's draw()): `data` holds, per pixel of a 64 x 64 box
// round the sigil, when the pen first passed (r), passed again (g) and when a glyph stroke popped in (b), in 1/60 s
// (255: never). A stroke pixel is white where the pen just passed, cooling to violet, pulsing as the sigil holds and
// white in the flare; a glyph pops in white and settles. `t` is the effect's time in seconds. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform sampler2D data : filter_nearest;
uniform float t = 0.0;
uniform float s_end = 2.0;
uniform float flare = 2.6;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);

void fragment() {
	ivec2 q = ivec2(floor(UV * size));
	vec4 d = texelFetch(data, q, 0) * 255.0;
	float hold = t > s_end ? 0.5 + 0.5 * sin((t - s_end) * 9.0) : 0.0;
	bool wh = t >= flare;
	float t1 = d.r / 60.0;
	float t2 = d.g / 60.0;
	float tg = d.b / 60.0;
	vec4 c = vec4(0.0);
	if (d.r < 254.5 && t1 <= t + 0.0005) {
		float age = t - ((d.g < 254.5 && t2 <= t + 0.0005) ? t2 : t1);
		c = wh ? white : age < 0.05 ? white : age < 0.15 ? c7 : age < 0.35 ? c6 : hold > 0.75 ? c6 : c5;
	}
	if (d.b < 254.5 && tg <= t + 0.0005) {
		float age = t - tg;
		c = (wh || age < 0.06) ? white : age < 0.2 ? c7 : hold > 0.75 ? c7 : c6;
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
