// A gunsmoke puff (projectiles/muzzle-*, cannonball), lit as the original's cloud() lights its puffs (_lib.js): its
// density is a ball's thickness (flat in the middle, steep at the rim) and opacity comes from it in sixths; it is
// lit where its density climbs downward (its crown) with cloud()'s own slope, atan(gradient / (0.16 density + 0.03)),
// and leans to the fire-lit ramp on its right side while the pop lights it. Soft layer. The particle colour is its
// state: red its brightness b, green the fire's light w, alpha its density (build/fx/projectiles/_muzzle.gd).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

// the smoke ramp dark to bright, and the same smoke lit by fire
uniform vec4 ramp_cols[8];
uniform vec4 warm_cols[8];
uniform int n = 7;
uniform float lit = 1.0;
uniform float dens = 1.4;
uniform float max_a = 0.86;

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
	float s = sqrt(1.0 - d2);
	float D = s * state.a;
	if (D < 0.05) {
		discard;
	}
	float a = min(max_a, ceil((1.0 - exp(-D * dens)) * 6.0) / 6.0);
	if (a < 0.15) {
		discard;
	}
	// the radius in px, from how fast UV runs across a pixel
	float r = 1.0 / max(1e-4, 2.0 * fwidth(UV.x));
	// cloud()'s light: the density's slope (two px apart, softened as its blur would) over the density
	float ss = max(s, 0.45);
	float slope = 2.0 * state.a * (-q.y * 0.9 - q.x * 0.35) / (r * ss);
	float up = clamp(0.5 + atan(slope / (0.16 * state.a * ss + 0.03)) * 0.42 * lit, 0.0, 1.0);
	float w = state.g * (0.5 + 0.5 * clamp(0.5 + q.x, 0.0, 1.0));
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
