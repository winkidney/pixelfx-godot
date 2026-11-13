// A ring of light orbiting the arcane orb (after the original's ring()): a dotted circle of radius r tilted in depth
// (squash sy) and rolled `rot` radians in the picture (rocking 0.12 rad over the loop), with `beads` bright beads
// running round it `turn` times a loop, each trailing six dots. `near` 1 draws only the half in front (z > 0), 0 the
// half behind. Centred on the rect. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(70.0);
uniform float t = 0.0;
uniform float r = 31.0;
uniform float sy = 0.24;
uniform float rot = 0.36;
uniform float phase = 0.0;
uniform float beads = 3.0;
uniform float turn = 2.0;
uniform float near = 1.0;
uniform vec4 dot_near : source_color = vec4(0.78, 0.52, 1.0, 1.0);
uniform vec4 dot_far : source_color = vec4(0.6, 0.28, 0.93, 1.0);
uniform vec4 c5 : source_color = vec4(0.78, 0.52, 1.0, 1.0);
uniform vec4 c6 : source_color = vec4(0.93, 0.78, 1.0, 1.0);
uniform vec4 white : source_color = vec4(1.0);

vec2 pos(float g, float cr, float sr) {
	float lx = cos(g) * r;
	float ly = sin(g) * r * sy;
	return vec2(lx * cr - ly * sr, lx * sr + ly * cr);
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size);
	vec2 p = cell + 0.5;
	float ro = rot + 0.12 * sin(t * TAU + phase);
	float cr = cos(ro);
	float sr = sin(ro);
	// back into the ring's own plane
	vec2 l = vec2(p.x * cr + p.y * sr, -p.x * sr + p.y * cr);
	float g0 = atan(l.y / sy, l.x);
	float n = ceil(r * TAU * 1.5);
	bool hit = false;
	float g = 0.0;
	for (int k = -6; k <= 6; k++) {
		// the original's dots sit at j / n of a turn: snap to them
		float gk = (round(g0 / TAU * n) + float(k)) / n * TAU;
		if (floor(pos(gk, cr, sr)) == cell) {
			hit = true;
			g = gk;
			break;
		}
	}
	if (!hit || ((sin(g) > 0.0) != (near > 0.5))) {
		discard;
	}
	vec4 c = near > 0.5 ? vec4(dot_near.rgb, 0.7) : vec4(dot_far.rgb, 0.4);
	// beads and their trails
	float dir = sign(turn);
	for (int b = 0; b < 4; b++) {
		if (float(b) >= beads) {
			break;
		}
		float gb = t * TAU * turn + float(b) * TAU / beads;
		float dd = mod((gb - g) * dir + PI * 0.5, TAU) - PI * 0.5;
		float kk = round(dd / 0.07);
		if (kk >= 0.0 && kk <= 6.0 && abs(dd - kk * 0.07) < 0.6 / r + 0.02) {
			c = vec4((kk == 0.0 ? white : kk < 3.0 ? c6 : c5).rgb, kk < 4.0 ? 1.0 : 1.0 - (kk - 3.0) / 4.0);
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
