// The teleporter pad (src/fx/scifi/teleporter-pad.js), from the keyed clock `t`:
//   mode 0: the pad: a steel drum with a lit far rim and a seam, a recessed well of light whose rings roll outward
//           and a hot middle, ten emitters round the rim chasing (colour layer)
//   mode 1: the column: a soft tube of light standing on the well, brighter at its walls, fading as it rises
//           (translucent)
//   mode 2: the rings of light lifting off the pad, their far halves then their near halves: crisp dots stepping down
//           the ramp as they climb, a glint running round each (colour layer)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform vec2 size = vec2(96.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform vec4 pal[8] : source_color;
uniform vec4 metal[6] : source_color;
// each lifting ring's progress and its colour step this frame (worked out at build time on the original's clock:
// a ring born on a frame's very time shows or not as the original's does)
uniform vec4 ring_k = vec4(2.0);
uniform vec4 ring_c = vec4(0.0);

const float D = 2.4;
const float RX = 31.0;
const float RY = 7.0;
const float PY = -3.0;
const float IN = 0.78;
const float HIGH = -84.0;

vec4 pad(vec2 pc, ivec2 P) {
	float ph = t / D;
	float x = pc.x;
	float y = pc.y;
	vec4 c = vec4(0.0);
	if (x >= -RX - 1.5 && x <= RX + 1.5 && y >= PY - RY - 1.5 && y <= 2.5) {
		float u = x / RX;
		float v = (y - PY) / RY;
		float d = sqrt(u * u + v * v);
		if (d > 1.0) {
			float v2 = (y - 3.0 - PY) / RY;
			if (abs(x) <= RX && y > PY && y <= 1.0 && sqrt(u * u + v2 * v2) <= 1.0) {
				c = abs(x) > RX - 1.0 ? metal[0] : x < -RX * 0.4 ? metal[3] : x > RX * 0.4 ? metal[1] : metal[2];
			}
		} else if (d > 0.97) {
			c = metal[0];
		} else if (d > IN) {
			c = abs(d - (IN + 0.1)) < 0.03 ? metal[1] : d < IN + 0.03 ? pal[3] : v < -0.3 ? metal[5] : v < 0.2 ? metal[4] : metal[3];
		} else {
			float r = d / IN;
			bool ring = mod(r * 3.0 - ph * 3.0, 1.0) < 0.16;
			float heat = pow(1.0 - r, 1.5);
			c = r > 0.94 ? pal[3] : ring ? (heat > 0.3 ? vec4(1.0) : pal[6]) : heat > 0.55 ? pal[6] : heat > 0.25 ? pal[5] : r > 0.8 ? pal[3] : pal[4];
		}
	}
	for (int i = 0; i < 10; i++) {
		float a = float(i) / 10.0 * TAU + 0.15;
		vec2 e = floor(vec2(cos(a) * RX * 0.885, PY + sin(a) * RY * 0.885));
		if (all(equal(e, vec2(P)))) {
			float k = 0.5 + 0.5 * cos(TAU * (2.0 * ph - float(i) / 10.0));
			c = k > 0.7 ? vec4(1.0) : k > 0.4 ? pal[5] : pal[2];
		}
	}
	return c;
}

vec4 column(vec2 pc, ivec2 P) {
	float W = RX * IN;
	float y = float(P.y);
	if (y < HIGH || y >= PY || float(P.x) < floor(-W) || float(P.x) > ceil(W)) {
		return vec4(0.0);
	}
	float v = (y - PY) / (HIGH - PY);
	float fd = pow(1.0 - v, 1.6);
	float q = abs(float(P.x) + 0.5) / W;
	if (q > 1.0) {
		return vec4(0.0);
	}
	return vec4(q > 0.9 ? pal[6].rgb : pal[5].rgb, fd * (0.07 + 0.26 * pow(q, 4.0) + 0.12 * pow(1.0 - v, 4.0)));
}

vec4 rings(ivec2 P) {
	vec4 c = vec4(0.0);
	for (int side = 0; side < 2; side++) {
		bool near = side == 1;
		for (int i = 0; i < 4; i++) {
			float k = ring_k[i];
			if (k >= 1.0) {
				continue;
			}
			float y = mix(PY, HIGH + 12.0, pow(k, 0.85));
			float rx = RX * IN * (1.0 + 0.08 * k);
			float ry = rx * (RY / RX);
			if (float(P.y) < floor(y - ry) - 1.0 || float(P.y) > floor(y + ry) + 2.0) {
				continue;
			}
			int ci = int(ring_c[i] + 0.5);
			vec4 rc = ci == 0 ? vec4(1.0) : ci == 1 ? pal[6] : ci == 2 ? pal[5] : ci == 3 ? pal[4] : pal[3];
			float glint = mod(float(i) * 0.37 + k * 1.5, 1.0) * TAU;
			int n = int(ceil(rx * 7.0));
			for (int j = 0; j < 400; j++) {
				if (j >= n) {
					break;
				}
				float g = float(j) / float(n) * TAU;
				float sg = sin(g);
				if ((sg >= 0.0) != near) {
					continue;
				}
				if (ci == 4 && (j & 1) == 1) {
					continue;
				}
				vec2 p = floor(vec2(cos(g) * rx, y + sg * ry));
				bool hot = abs(mod(g - glint + PI * 3.0, TAU) - PI) < 0.25;
				if (all(equal(p, vec2(P)))) {
					c = hot && k < 0.8 ? vec4(1.0) : near ? rc : ci <= 1 ? pal[5] : pal[3];
				} else if (k < 0.3 && all(equal(p + vec2(0.0, 1.0), vec2(P)))) {
					c = near ? pal[5] : pal[3];
				}
			}
		}
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	vec4 c = mode == 0 ? pad(pc, P) : mode == 1 ? column(pc, P) : rings(P);
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, mode == 1)) {
		discard;
	}
	COLOR = c;
}
