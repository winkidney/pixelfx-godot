// Particles of explosions/small-explosion drawn as the original's particle system draws them, on a square texture.
// Mode 0, a SMOKE puff: a soft body, a denser core sitting a little low and a lit cap while it's young, in the smoke
// ramp `sm` as it ages (or its own colour, `dark` or `dust`, turning to the ramp): the particle's colour carries
// r = its age (0..1), b = whose colour (0 the ramp's, 0.5 dark, 1 dust), a = its opacity. Soft layer (translucent).
// Mode 1, a FIRE puff (a darker rim, a lit core, a tongue on top, a hot heart): r = heat 0..1 down the fire ramp
// `fr`, a = opacity; the quad is 2.7 radii across. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform float mode = 0.0;
uniform vec4 fr[9] : source_color;
uniform vec4 sm[5] : source_color;
uniform vec4 dark : source_color = vec4(0.13, 0.11, 0.15, 1.0);
uniform vec4 dust : source_color = vec4(0.42, 0.37, 0.52, 1.0);

void fragment() {
	vec4 pc = COLOR;
	vec4 c;
	if (mode < 0.5) {
		vec2 P = (UV - 0.5) * 2.0;
		if (dot(P, P) > 1.0) {
			discard;
		}
		float age = clamp(pc.r, 0.0, 1.0);
		vec3 base;
		if (pc.b < 0.25) {
			base = sm[min(4, int(floor(age * 1.05 * 5.0)))].rgb;
		} else {
			vec3 own = pc.b < 0.75 ? dark.rgb : dust.rgb;
			base = mix(own, sm[min(4, int(floor(age * 5.0)))].rgb, age);
		}
		float a = pc.a;
		// the body, then the core over it, then the cap over both (each blended as the original's discs are)
		float al = 0.45 * a;
		vec3 col = base;
		vec2 q = P - vec2(0.05, 0.06);
		if (dot(q, q) <= 0.74 * 0.74) {
			float b = 0.62 * a;
			al = b + al * (1.0 - b);
		}
		vec2 w = P - vec2(-0.22, -0.3);
		if (age < 0.5 && dot(w, w) <= 0.25) {
			float b = 0.4 * a * (1.0 - age * 2.0);
			float o = b + al * (1.0 - b);
			col = mix(col, mix(base, vec3(1.0), 0.12), b / max(o, 1e-4));
			al = o;
		}
		c = vec4(col, al);
	} else {
		vec2 P = (UV - 0.5) * 2.7;
		float r = 1.0 / max(abs(dFdx(P.x)), 1e-4);
		int idx = min(7, int(floor(clamp(pc.r, 0.0, 0.999) * 8.0)));
		if (idx >= 7) {
			if (dot(P, P) > 1.0) {
				discard;
			}
			c = vec4(fr[idx].rgb, pc.a * 0.85);
		} else {
			if (r > 1.8 && idx <= 3 && length(P - vec2(-0.28, -0.34)) <= 0.36) {
				c = fr[max(0, idx - 1)];
			} else if (length(P - vec2(-0.16, -0.22)) <= 0.78 || (r > 1.6 && length(P - vec2(0.0, -0.9)) <= 0.42)) {
				c = fr[idx];
			} else if (dot(P, P) <= 1.0) {
				c = fr[min(8, idx + 2)];
			} else {
				discard;
			}
			c.a = pc.a;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
