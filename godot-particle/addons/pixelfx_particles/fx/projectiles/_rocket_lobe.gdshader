// The rocket's (and the homing missile's) smoke puffs: projectiles/_lobe.gdshader with the light's direction as a
// uniform (`light_dir`): along a trail the original's merged cloud is lit from straight above (its density barely
// changes along the trail), so a chain of puffs mustn't each catch the light on its own side.
// A puff of the projectiles' smoke, lit as the original's cloud() lights its merged puffs (_lib.js): a ball whose
// thickness gives its density (flat in the middle, steep at the rim), lit on its crown and shaded beneath, tone and
// density in clean steps. For a GPUParticles2D on the soft layer (projectiles/_projectiles.gd lobes()): the particle
// colour carries the puff's state, not a colour: alpha its density, red its brightness b (how far up the smoke ramp
// it sits), green the fire's light on it (toward the warm ramp).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

// the smoke ramp dark to bright, and the same smoke lit by fire
uniform vec4 ramp_cols[8];
uniform vec4 warm_cols[8];
uniform int n = 7;
// how strongly the crown is lit against the underside
uniform float lit = 1.0;
// density to opacity: 1 - exp(-d * dens), in sixths, capped at max_a
uniform float dens = 1.4;
uniform float max_a = 0.86;
// where the light comes from (toward it), x right, y down
uniform vec2 light_dir = vec2(-0.35, -0.9);

varying vec4 state;

void vertex() {
	state = COLOR;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d2 = dot(q, q);
	if (d2 >= 1.0) {
		discard;
	}
	float thick = sqrt(1.0 - d2) * state.a;
	float a = min(max_a, ceil((1.0 - exp(-thick * dens * 1.6)) * 6.0) / 6.0);
	if (a < 0.15) {
		discard;
	}
	// facing up (and a little left): the crown catches the light
	float up = clamp(0.5 + atan(dot(q, light_dir) * 1.6) * 0.42 * lit, 0.0, 1.0);
	float w = state.g;
	int j = clamp(int(round(state.r * (0.3 + 0.7 * up) * float(n - 1) + 0.25 + w * 1.5)), 0, n - 1);
	vec3 c = ramp_cols[j].rgb;
	if (w > 0.03) {
		c = mix(c, warm_cols[j].rgb, min(0.9, ceil(w * 10.0) / 10.0));
	}
	vec4 col = vec4(c, a);
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
