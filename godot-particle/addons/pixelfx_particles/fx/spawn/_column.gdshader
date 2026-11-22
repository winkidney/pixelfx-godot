// spawn/spawn-portal's burst: a column of light shooting up out of the rift, white down its middle, thinning and
// lifting away as the original shades it (top, bot, w0 keyed); the original's pow() of a negative number leaves a
// pale line along its top row now and then, and so does this. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(40.0, 90.0);
uniform vec2 center = vec2(0.0);
uniform float top = -1.0;
uniform float bot = -1.0;
uniform float w0 = 0.0;
uniform float t = 0.0;
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	if (w0 <= 0.0 || cell.x < floor(-w0 - 1.0) || cell.x > ceil(w0 + 1.0) || cell.y < floor(top) || cell.y > ceil(bot)) {
		discard;
	}
	vec2 p = cell + 0.5;
	float u = (p.y - bot) / (top - bot);
	vec4 c;
	if (1.0 - u < 0.0) {
		c = c5;
	} else {
		float half_w = w0 * pow(1.0 - u, 0.8) * (0.85 + 0.15 * sin(p.y * 0.7 + t * 40.0));
		float d = abs(p.x) / max(0.5, half_w);
		if (d > 1.0) {
			discard;
		}
		c = d < 0.35 ? white : d < 0.7 ? c6 : c5;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
