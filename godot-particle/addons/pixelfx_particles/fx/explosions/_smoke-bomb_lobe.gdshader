// A lobe of the smoke bomb's cloud (explosions/smoke-bomb, the original's cel-shaded _lib lobe()): a ball lit from
// the top left through the smoke ramp: a lit crescent on top, a mid tone, a dark underside; its rim a step more
// see-through. Put it on a GPUParticles2D: the particle colour carries the lobe's state, not a colour: alpha is its
// opacity, red how many steps darker it sits as it thins (0, 0.5, 1). `dark` shifts a whole emitter down the ramp
// (lobes behind, lobes low in the cloud's shadow). Soft layer: translucent, snapped to the palette.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

// the smoke ramp, light to dark
uniform vec4 s0 : source_color;
uniform vec4 s1 : source_color;
uniform vec4 s2 : source_color;
uniform vec4 s3 : source_color;
uniform vec4 s4 : source_color;
uniform float dark = 0.0;

varying vec4 state;

void vertex() {
	state = COLOR;
}

vec4 tone(int i) {
	return i <= 0 ? s0 : (i == 1 ? s1 : (i == 2 ? s2 : (i == 3 ? s3 : s4)));
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d2 = dot(q, q);
	if (d2 > 1.0) {
		discard;
	}
	float d = sqrt(d2);
	float nz = sqrt(1.0 - d2);
	float lam = -0.42 * q.x - 0.78 * q.y + 0.46 * nz;
	int i = lam > 0.66 && d > 0.4 ? 0 : (lam > 0.16 ? 1 : (lam > -0.3 ? 2 : (lam < -0.64 ? 4 : 3)));
	i = min(4, i + int(dark + 0.5) + int(state.r * 2.0 + 0.5));
	// the radius in px, from how fast UV changes across a pixel
	float r = 1.0 / max(1e-4, 2.0 * fwidth(UV.x));
	float rim = 1.0 - min(0.35, 1.6 / r);
	float a = state.a;
	float soft = 0.55 + 0.4 * (1.0 - min(1.0, a));
	vec4 c = vec4(tone(i).rgb, d <= rim ? a : a * soft);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
