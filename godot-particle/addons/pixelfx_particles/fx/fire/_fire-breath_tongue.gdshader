// A licking flame tongue drawn inside a particle's quad (use a solid square texture such as dot4): a rounded root at
// the bottom tapering to a tip at the top that sweeps sideways by `lean`. The particle's colour (its ramp) fills the
// body; a rim round it is mixed toward `rim`, a heart low in it toward `heart`. Colour layer: dithered alpha, palette
// snap. Used by the fire breath, flamethrower and fireball for the tongues their billows tear into.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

// half-width at the root, in quad widths
uniform float width = 0.22;
// how far the tip sweeps sideways (quad widths; negative: left)
uniform float lean = -0.18;
uniform vec4 rim : source_color = vec4(0.54, 0.12, 0.09, 1.0);
uniform float rim_mix = 0.7;
uniform vec4 heart : source_color = vec4(1.0, 0.95, 0.65, 1.0);
uniform float heart_mix = 0.5;

void fragment() {
	float v = 1.0 - UV.y;
	float half_w = width * pow(max(0.0, 1.0 - v), 0.85) * min(1.0, (v + 0.06) / 0.24);
	float dx = UV.x - (0.5 + lean * v * v);
	if (abs(dx) > half_w || half_w < 0.02) {
		discard;
	}
	vec4 c = COLOR;
	float a = abs(dx) / max(half_w, 1e-4);
	if (a > 0.58 || v > 0.78) {
		c.rgb = mix(c.rgb, rim.rgb, rim_mix);
	} else if (a < 0.3 && v < 0.4) {
		c.rgb = mix(c.rgb, heart.rgb, heart_mix);
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
