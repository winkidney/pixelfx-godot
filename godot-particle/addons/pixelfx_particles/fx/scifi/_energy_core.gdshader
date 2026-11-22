// The energy core (src/fx/scifi/energy-core.js), from the keyed clock `t` and the frame's data:
//   mode 0: the machine in the original's draw order: the cage's far hoops, back bars and the orbit rings' far
//           halves; the plinth and its chasing status lights; the core (plasma bands churning round a white-hot
//           heart, tileFbm noise as the original's), its filaments (re-rolled every other frame: `data` rows 0..71,
//           one a frame), the heart, a glassy highlight; the rings' near halves, the front bars, the near hoops, the
//           steel cap and its emitter
//   mode 1: the arcs jumping to the bars (`data` rows 72..95, one per 0.1 s slot: the original's bolt paths, stroked
//           as _lib.js strokeArc: a dark halo, a bright body, a white-hot core while fresh; `slot`, `k` keyed) and
//           the shock ring each thump throws
// Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(112.0, 100.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform float frame = 0.0;
uniform float slot = 0.0;
uniform float k = 1.0;
uniform int seed = 35;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;
uniform vec4 metal[6] : source_color;
// the cage's bars: x, depth, 1 if drawn in front
uniform vec4 bars[6];

const float D = 2.4;
const float CY = -36.0;
const float R0 = 11.0;
const float RC = 24.0;
const float TOPY = -64.0;
const float BOTY = -9.0;

float env(float a) {
	return a < 0.03 ? a / 0.03 : exp(-(a - 0.03) / 0.12);
}

float pulse_at(float tt) {
	float m = env(mod(tt - 0.05, D));
	m = max(m, 0.5 * env(mod(tt - 0.25, D)));
	m = max(m, env(mod(tt - 1.25, D)));
	m = max(m, 0.5 * env(mod(tt - 1.45, D)));
	return m;
}

float jrand3(int a, int b, int c) {
	return float(js_hash3(a, b, c)) / 4294967296.0;
}

int wrapi(int i, int p) {
	return p > 0 ? imod(i, p) : i;
}

float tile_noise(float x, float y, int px, int py, int sd) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int x0 = wrapi(int(ix), px);
	int x1 = wrapi(int(ix) + 1, px);
	int y0 = wrapi(int(iy), py);
	int y1 = wrapi(int(iy) + 1, py);
	float a = jrand3(x0, y0, sd);
	float b = jrand3(x1, y0, sd);
	float c = jrand3(x0, y1, sd);
	float d = jrand3(x1, y1, sd);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

float tile_fbm2(float x, float y, int px, int py, int sd) {
	float s = tile_noise(x, y, px, py, sd) * 0.5;
	s += tile_noise(x * 2.0, y * 2.0, px * 2, py * 2, sd + 101) * 0.25;
	return s / 0.75;
}

vec3 ring_pt(float r, float tilt, float spin, float a) {
	float x = r * cos(a);
	float z0 = r * sin(a);
	float y = -z0 * sin(tilt);
	float z = z0 * cos(tilt);
	return vec3(x * cos(spin) + z * sin(spin), CY - y, -x * sin(spin) + z * cos(spin));
}

// an orbit ring's near (front) or far half at cell P, its bead white
void ring(inout vec4 c, ivec2 P, int which, bool front, float pulse) {
	float r = which == 0 ? 17.0 : 19.0;
	float tilt = which == 0 ? 1.15 : -0.9;
	float spin = which == 0 ? TAU * (t / D) : -TAU * 2.0 * (t / D) + 1.0;
	float bead = (t / D) * TAU * 3.0;
	int n = int(ceil(r * 9.0));
	for (int i = 0; i < 200; i++) {
		if (i >= n) {
			break;
		}
		float a = float(i) / float(n) * TAU;
		vec3 p = ring_pt(r, tilt, spin, a);
		if ((p.z >= 0.0) != front) {
			continue;
		}
		if (all(equal(floor(p.xy), vec2(P)))) {
			bool head = fract((a - bead) / TAU) > 0.9;
			c = head ? vec4(1.0) : !front ? pal[3] : (p.z > 0.5 * r || pulse > 0.6) ? pal[6] : pal[5];
		}
	}
}

void hoop(inout vec4 c, ivec2 P, float y, bool near, float pulse) {
	if (abs(float(P.y) - y) > 6.0) {
		return;
	}
	float rx = RC;
	int n = int(ceil(rx * 8.0));
	for (int i = 0; i < 200; i++) {
		if (i >= n) {
			break;
		}
		float g = float(i) / float(n) * TAU;
		float s = sin(g);
		if ((s >= 0.0) != near) {
			continue;
		}
		vec2 p = floor(vec2(cos(g) * rx, y + s * 4.0));
		if (int(p.x) != P.x) {
			continue;
		}
		int dy = P.y - int(p.y);
		if (dy == 0) {
			c = near ? (s > 0.6 ? metal[4] : metal[3]) : metal[1];
		} else if (dy == 1) {
			c = near ? metal[1] : metal[0];
		} else if (dy == -1 && near && s < 0.3) {
			c = pulse > 0.5 ? pal[5] : pal[3];
		}
	}
}

void bar(inout vec4 c, ivec2 P, vec4 b, bool back, float pulse) {
	if (float(P.y) < TOPY + 2.0 || float(P.y) >= BOTY) {
		return;
	}
	vec4 lit = back ? pal[3] : pulse > 0.5 ? pal[6] : pal[5];
	int inward = b.x > 0.0 ? -1 : 1;
	for (int i = -1; i <= 1; i++) {
		if (int(floor(b.x + float(i))) == P.x) {
			bool face = i == inward;
			c = back ? (face ? lit : metal[1]) : face ? lit : i == 0 ? metal[3] : metal[1];
		}
	}
}

// the 1 px lines of a filament: the first 40% of each of its segments white, the rest C6
void filament(inout vec4 c, vec2 cell, int f, int j) {
	for (int s = 1; s < 9; s++) {
		vec2 a = floor(texelFetch(data, ivec2(j * 9 + s - 1, f), 0).xy);
		vec2 b = floor(texelFetch(data, ivec2(j * 9 + s, f), 0).xy);
		if (cell_on_line(cell, a, b)) {
			vec2 e = abs(b - a);
			float n = max(1.0, max(e.x, e.y));
			float u = (e.x >= e.y ? abs(cell.x - a.x) : abs(cell.y - a.y)) / n;
			c = u < 0.4 ? vec4(1.0) : pal[6];
		}
	}
	vec2 end = floor(texelFetch(data, ivec2(j * 9 + 8, f), 0).xy);
	if (all(equal(end, cell))) {
		c = vec4(1.0);
	}
}

vec4 machine(ivec2 P, vec2 pc) {
	vec2 cell = vec2(P);
	float pulse = pulse_at(t);
	float R = R0 * (1.0 + 0.14 * pulse);
	vec4 c = vec4(0.0);
	hoop(c, P, BOTY, false, pulse);
	hoop(c, P, TOPY, false, pulse);
	for (int i = 0; i < 6; i++) {
		if (bars[i].z < 0.5) {
			bar(c, P, bars[i], true, pulse);
		}
	}
	ring(c, P, 0, false, pulse);
	ring(c, P, 1, false, pulse);
	// the plinth: a steel drum with a lit top, its status lights chasing
	if (pc.x >= -29.5 && pc.x <= 30.5 && pc.y >= -9.5 && pc.y <= 2.5) {
		float tp = pow(pc.x / 29.0, 2.0) + pow((pc.y + 7.0) / 4.0, 2.0);
		if (tp <= 1.0) {
			c = tp > 0.82 ? metal[0] : pc.y < -8.0 ? metal[5] : pc.x < 0.0 ? metal[4] : metal[3];
		} else if (abs(pc.x) <= 29.0 && pc.y > -7.0 && pc.y <= 0.0) {
			c = abs(pc.x) > 28.0 ? metal[0] : pc.x < -14.0 ? metal[3] : pc.x > 14.0 ? metal[1] : metal[2];
		}
	}
	if (P.y == -3) {
		for (int i = 0; i < 7; i++) {
			if (P.x == -18 + i * 6) {
				float kk = 0.5 + 0.5 * cos(TAU * (2.0 * (t / D) - float(i) / 7.0));
				c = kk > 0.75 ? vec4(1.0) : kk > 0.4 ? pal[5] : pal[2];
			}
		}
	}
	// the core: dark plasma held in a hard rim, bands churning round a white-hot heart
	{
		float dx = pc.x;
		float dy = pc.y - CY;
		float d = sqrt(dx * dx + dy * dy) / R;
		if (d <= 1.1) {
			if (d > 1.0) {
				c = pal[2];
			} else if (d > 0.9) {
				c = dy < -R * 0.3 && dx < R * 0.3 ? pal[6] : pal[4];
			} else {
				float ph = t / D;
				float a = atan(dy, dx);
				float n = 0.5 + 0.5 * tile_fbm2((a / TAU) * 6.0 + ph * 6.0 + d * 1.5, d * 2.2 - ph * 4.0, 6, 4, seed);
				bool band = abs(n - 0.5) < 0.05 + 0.05 * pulse;
				float heat = pow(1.0 - d, 2.0) + pulse * 0.45;
				if (band) {
					c = heat > 0.5 ? vec4(1.0) : heat > 0.2 ? pal[6] : pal[5];
				} else {
					c = heat > 0.7 ? pal[6] : heat > 0.42 ? pal[5] : heat > 0.2 ? pal[3] : n > 0.5 ? pal[2] : pal[1];
				}
			}
		}
	}
	int f = clamp(int(frame + 0.5), 0, 71);
	if (abs(pc.x) < 16.0 && abs(pc.y - CY) < 16.0) {
		for (int j = 0; j < 3; j++) {
			filament(c, cell, f, j);
		}
	}
	float hr = 1.8 + pulse * 2.0;
	if (length(pc - vec2(0.0, CY)) <= hr) {
		c = vec4(1.0);
	}
	if (all(equal(cell, floor(vec2(-R * 0.45, CY - R * 0.55))))) {
		c = vec4(1.0);
	}
	if (all(equal(cell, floor(vec2(-R * 0.45 + 1.0, CY - R * 0.55))))) {
		c = pal[6];
	}
	ring(c, P, 0, true, pulse);
	ring(c, P, 1, true, pulse);
	for (int i = 0; i < 6; i++) {
		if (bars[i].z > 0.5) {
			bar(c, P, bars[i], false, pulse);
		}
	}
	hoop(c, P, BOTY, true, pulse);
	hoop(c, P, TOPY, true, pulse);
	// the cap: a steel dome, its emitter on top
	if (pc.x >= -14.5 && pc.x <= 15.5 && pc.y >= TOPY - 6.5 && pc.y <= TOPY + 0.5) {
		float d = pow(pc.x / 14.5, 2.0) + pow((pc.y - TOPY) / 6.5, 2.0);
		if (d <= 1.0) {
			float l = -pc.x * 0.05 - (pc.y - TOPY) * 0.12;
			c = d > 0.8 ? metal[0] : l > 0.55 ? metal[5] : l > 0.3 ? metal[4] : metal[3];
		}
	}
	if (P == ivec2(0, int(TOPY) - 7)) {
		c = pulse > 0.4 ? vec4(1.0) : pal[5];
	}
	return c;
}

// the arcs of this slot (strokeArc, stroke by stroke: halo, body, a white core while fresh), then the shock rings
vec4 sparks_of(ivec2 P, vec2 pc, float thr) {
	vec4 c = vec4(0.0);
	int row = 72 + clamp(int(slot + 0.5), 0, 23);
	if (k > 0.0) {
		int cur = -1;
		float dmin = 1e9;
		float cheb = 1e9;
		float w = 1.0;
		for (int j = 0; j < 64; j++) {
			vec4 q = texelFetch(data, ivec2(j, row), 0);
			int sid = int(q.z + 0.5);
			bool last = q.z < -0.5;
			if (last || (cur >= 0 && sid != cur)) {
				if (cur >= 0) {
					float rh = (k > 0.6 ? 1.6 : 1.1) * w;
					float rb = (k > 0.6 ? 0.9 : 0.6) * w;
					if (cheb <= 0.45 && k > 0.3) {
						c = vec4(1.0);
					} else if ((rb < 0.6 && cheb <= 0.45) || dmin <= rb) {
						c = pal[5];
					} else if ((rh < 0.6 && cheb <= 0.45) || dmin <= rh) {
						c = pal[2];
					}
				}
				dmin = 1e9;
				cheb = 1e9;
				if (last) {
					break;
				}
			}
			if (sid == cur && j > 0) {
				vec2 a = texelFetch(data, ivec2(j - 1, row), 0).xy;
				vec2 b = q.xy;
				vec2 e = b - a;
				float u = clamp(dot(pc - a, e) / max(dot(e, e), 1e-9), 0.0, 1.0);
				vec2 foot = a + e * u;
				dmin = min(dmin, length(foot - pc));
				vec2 fd = abs(foot - pc);
				cheb = min(cheb, max(fd.x, fd.y));
			}
			cur = sid;
			w = q.w;
		}
	}
	// each thump: a shock ring rolls out from the core
	for (int i = 0; i < 2; i++) {
		float b = i == 0 ? 0.05 : 1.25;
		float a = mod(t - b, D);
		if (a > 0.45) {
			continue;
		}
		float q = a / 0.45;
		float r = R0 + 34.0 * e_out_cubic(q);
		float wd = max(1.0, 3.0 * (1.0 - q));
		float d = length(pc - vec2(0.0, CY));
		if (d <= r && d >= max(0.0, r - wd) && 1.1 - q >= thr) {
			c = q < 0.25 ? vec4(1.0) : q < 0.5 ? pal[6] : pal[5];
		}
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = mode == 0 ? machine(P, pc) : sparks_of(P, pc, thr);
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, false)) {
		discard;
	}
	COLOR = c;
}
