// A floating sphere of water (water/water-orb), bobbing `bob` px about y0 once a loop; its skin wobbles and its
// belly sags into a drip every `drip` s. mode 0: the see-through body, a lens dark on the lit side with the light
// gathering low on the far side (soft layer); mode 1: the skin's lit rim, the current circling inside on three tilted
// planes (dashed, bright where it passes in front), the shine, the refracted glints, the swelling drip and the lens'
// bright focus (colour layer). Key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(56.0, 60.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float dur = 3.0;
uniform float R = 19.0;
uniform float y0 = -52.0;
uniform float bob = 2.0;
uniform float drip = 1.5;
uniform float let_go = 0.5;
uniform float mode = 1.0;

const float O_TAU = 6.28318530718;
const float O_PI = 3.14159265359;

float skin(float a, float ph) {
	float dt = mod(ph * dur, drip) / drip;
	float sag = pow(max(0.0, sin(a)), 6.0) * 2.2 * smoothstep(0.1, let_go, dt) * (dt < let_go ? 1.0 : 0.0);
	return R + sin(a * 3.0 + ph * O_TAU * 2.0) * 0.6 + sin(a * 5.0 - ph * O_TAU * 3.0) * 0.35 + sag;
}

bool same_cell(vec2 a, vec2 p) {
	return all(equal(floor(a), floor(p)));
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float ph = t;
	float T = ph * O_TAU;
	vec2 c0 = vec2(0.0, y0 + sin(T) * bob);
	vec2 q = p - c0;
	float d = length(q);
	float a = atan(q.y, q.x);
	float r = skin(a, ph);
	bool inside = d <= r && all(lessThanEqual(abs(q - vec2(0.0, 1.0)), vec2(R + 4.0, R + 5.0)));
	float qd = d / r;
	vec4 c = vec4(0.0);
	if (mode < 0.5) {
		if (!inside || qd > 0.9) {
			discard;
		}
		float gather = max(0.0, (q.x + q.y) / sqrt(2.0) / r) * qd;
		c = gather > 0.45 ? pal[4] : gather > 0.25 ? pal[3] : qd > 0.7 ? pal[2] : pal[1];
		c.a = gather > 0.25 ? 0.7 : 0.35 + 0.3 * qd;
	} else {
		if (inside && qd > 0.9) {
			float lit = (-q.x - q.y) / sqrt(2.0) / max(0.5, d);
			c = lit > 0.35 ? pal[7] : lit > -0.2 ? pal[5] : pal[3];
		}
		// the current: three streaks circling on tilted planes, sampled as the original samples them
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float rr = R * (0.38 + 0.2 * fk);
			float tilt = -0.5 + fk * 0.35;
			float spin = T * (k == 1 ? -2.0 : 3.0) + fk * 2.0;
			float vx = q.x / (rr * cos(tilt));
			float vy = (q.y - vx * rr * sin(tilt) * 0.6) / (rr * 0.62);
			float s0 = fract((atan(vy, vx) - spin) / O_TAU);
			int j0 = int(round(s0 / 0.012));
			for (int dj = -3; dj <= 3; dj++) {
				int j = j0 + dj;
				j = j < 0 ? j + 84 : j >= 84 ? j - 84 : j;
				float s = float(j) * 0.012;
				float an = spin + s * O_TAU;
				float x = cos(an) * rr;
				float z = sin(an);
				vec2 P = c0 + vec2(x * cos(tilt), x * sin(tilt) * 0.6 + z * rr * 0.62);
				float dash = fract(s * 3.0 + fk * 0.3);
				if (dash > 0.62 || !same_cell(P, p)) {
					continue;
				}
				c = z > 0.0 ? (dash < 0.1 ? pal[7] : dash < 0.4 ? pal[6] : pal[5]) : pal[3];
			}
		}
		// the shine: a bright crescent up on the left, a small refracted glint low on the right
		float sr = R * 0.74;
		if (d <= sr && d >= sr - 1.8) {
			float an = a - O_PI * 1.12;
			an -= floor(an / O_TAU) * O_TAU;
			float span = O_PI * 0.28;
			if (an <= span) {
				float u = an / span;
				float v = (d - (sr - 1.8)) / 1.8;
				c = (u > 0.25 && u < 0.75 && v > 0.4) ? pal[7] : pal[6];
			}
		}
		if (same_cell(c0 + vec2(-R * 0.45, -R * 0.62), p)) {
			c = pal[7];
		}
		if (same_cell(c0 + vec2(R * 0.48, R * 0.5), p)) {
			c = pal[6];
		}
		if (same_cell(c0 + vec2(R * 0.48 + 1.0, R * 0.5), p)) {
			c = pal[5];
		}
		// the drip swelling on its belly before it lets go
		float dt = mod(ph * dur, drip) / drip;
		float fall = mod(ph * dur, drip) - drip * let_go;
		if (fall < 0.0 && dt > 0.2) {
			float sw = smoothstep(0.2, let_go, dt);
			if (distance(p, c0 + vec2(0.0, R + 1.0 + sw * 1.5)) <= 0.8 + sw * 1.2) {
				c = pal[5];
			}
			if (same_cell(c0 + vec2(-0.5, R + sw * 1.5), p)) {
				c = pal[6];
			}
		}
		// where the lens brings the light to a point
		vec2 f = c0 + vec2(R * 0.36, R * 0.4);
		if (distance(p, f) <= 1.6) {
			c = pal[6];
		}
		if (same_cell(f, p)) {
			c = pal[7];
		}
		if (c.a <= 0.0) {
			discard;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
