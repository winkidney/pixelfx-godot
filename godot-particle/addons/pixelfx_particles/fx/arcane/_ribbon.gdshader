// A missile's ribbon (after arcane-missiles.js ribbon()), on a Line2D from the head (UV.x 0) down its trail (UV.x 1)
// whose width_curve is the ribbon's own taper plus room for its strands: a capsule tapering down the tail, white along
// its middle near the head and cooling outward, fading down the tail; two strands twisting round it, bright where they
// come round the front. `t` is the effect's time in s (keyed); `tw` the missile's own twist; `fade` 1 -> 0 after it
// lands. Colour layer (the Line2D needs a texture for its UVs; it isn't read).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform float t = 0.0;
uniform float tw = 0.0;
uniform float fade = 1.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	float u = clamp(UV.x, 0.0, 1.0);
	float w = 2.6 * pow(1.0 - u, 0.8) + 0.3;
	float q = (UV.y - 0.5) * 2.0 * (w + 1.6);
	float a = min(1.0, (1.0 - u) * 1.7 * fade);
	vec4 c = vec4(0.0);
	if (abs(q) <= w) {
		float v = abs(q) / w;
		c = v < 0.35 ? (u < 0.25 ? white : c6) : v < 0.7 ? (u < 0.4 ? c6 : c5) : u < 0.5 ? c5 : c4;
		c.a = a * (v < 0.7 ? 1.0 : 0.75);
	}
	for (int k = 0; k < 2; k++) {
		float ph = u * 10.0 - t * 26.0 + tw + float(k) * PI;
		float off = sin(ph) * (w + 1.4);
		if (cos(ph) > -0.2 && abs(q - off) < 0.6) {
			c = cos(ph) > 0.4 ? (u < 0.35 ? white : c6) : c4;
			c.a = a;
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
