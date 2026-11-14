// The black hole's particles (a process shader, after src/fx/shadow/black-hole.js): every slot is one of the
// original's cycle() particles, placed from the keyed loop clock `t` (0..1 over 4 s) with the original's own random
// numbers (_jsrand.gdshaderinc), so they fall exactly where and when the original's do. Several emitters run it with
// the same numbers, each drawing one part (`part`) in one colour:
//   mode 0 motes streaking in:  part 0 the whole line (tail colour), 1 its head (u > 0.6, `pick`ed colour), 2 light
//   mode 1 debris spiralling in: 0 small lump (2x2 texture), 1 big lump (3x3), 2 its lit face, 3..5 its wake,
//                                6..8 hot streak (whole, u > 0.35, u > 0.7), 9 the flash at the photon ring, 10 light
//   mode 2 pebbles torn up:      0 the pebble, 1 a puff of dust where it left the floor (soft disc)
// Colours come in `col` (and `pick` for the motes' heads); the canvas material does the rest.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/shadow/_jsrand.gdshaderinc"

uniform float t = 0.0;
uniform int mode = 0;
uniform int part = 0;
uniform int seed = 4;
uniform vec4 col : source_color = vec4(1.0);
uniform vec4 col2 : source_color = vec4(1.0);
uniform vec4 pick[4] : source_color;
// the texture's width in px (glows and discs are scaled to their radius)
uniform float tex = 1.0;

const float D = 4.0;
const float Y = -70.0;
const float RS = 13.5;
const float SI = 0.25;
const float TILT = -0.14;

mat4 quad(vec2 c, float ang, vec2 sc) {
	float ca = cos(ang);
	float sa = sin(ang);
	return mat4(vec4(ca * sc.x, sa * sc.x, 0.0, 0.0), vec4(-sa * sc.y, ca * sc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(c, 0.0, 1.0));
}

// a 1 px line over the cells from a to b, from u0 of the way along to u1
mat4 seg_line(vec2 a, vec2 b, float u0, float u1) {
	vec2 ca = floor(a) + 0.5;
	vec2 cb = floor(b) + 0.5;
	vec2 d = cb - ca;
	vec2 p0 = ca + d * u0;
	vec2 p1 = ca + d * u1;
	vec2 e = p1 - p0;
	float L = length(e);
	float ang = L > 0.01 ? atan(e.y, e.x) : 0.0;
	return quad((p0 + p1) * 0.5, ang, vec2(L + 1.0, 1.0));
}

mat4 cell(vec2 p, float n) {
	return quad(floor(p) + (n > 1.5 && mod(n, 2.0) < 0.5 ? 1.0 : 0.5), 0.0, vec2(1.0));
}

mat4 glow_at(vec2 p, float r) {
	return quad(floor(p) + 0.5, 0.0, vec2(2.0 * r / tex));
}

// debris: its place `aa` seconds into a life L
vec4 deb_at(float aa, float L, float ph0, float rho0, float hgt) {
	float q = clamp(aa / L, 0.0, 1.0);
	float rho = RS + 1.0 + (rho0 - RS - 1.0) * (1.0 - pow(q, 1.5));
	float ph = ph0 + 2.4 * pow(q, 1.6) * (1.0 + 1.5 * q);
	float X = cos(ph) * rho;
	float Z = sin(ph) * rho;
	float sx = X;
	float sy = -Z * SI + hgt * (1.0 - q);
	float ct = cos(TILT);
	float st = sin(TILT);
	return vec4(sx * ct - sy * st, Y + sx * st + sy * ct, Z, rho);
}

void place(inout mat4 tr, inout vec4 c, int i) {
	float T = t * D;
	float L;
	bool shown = false;
	vec4 cc = col;
	if (mode == 0) {
		float age = js_cycle(seed, i, T, D, 0.5, 0.9, L);
		if (age >= 0.0) {
			uint r = js_hash2(seed, i);
			float a0 = js_range(r, 0.0, TAU);
			float d0 = js_range(r, 48.0, 76.0);
			int k = int(floor(js_next(r) * 4.0));
			float q = pow(age / L, 1.6);
			float d = RS + 2.0 + (d0 - RS - 2.0) * (1.0 - q);
			float a = a0 + 0.9 * q;
			vec2 h = vec2(cos(a) * d * 1.15, Y + sin(a) * d * 0.75);
			float q2 = pow(max(0.0, age - 0.09) / L, 1.6);
			float d2 = RS + 2.0 + (d0 - RS - 2.0) * (1.0 - q2);
			float a2 = a0 + 0.9 * q2;
			vec2 tl = vec2(cos(a2) * d2 * 1.15, Y + sin(a2) * d2 * 0.75);
			if (!(d < RS + 3.0 || h.y > -3.0 || h.y < -120.0 || tl.y < -120.0 || abs(h.x) > 90.0)) {
				shown = true;
				float al = min(1.0, age * 6.0);
				if (part == 0) {
					tr = seg_line(tl, h, 0.0, 1.0);
					cc = vec4(col.rgb, al);
				} else if (part == 1) {
					tr = seg_line(tl, h, 0.65, 1.0);
					cc = vec4(pick[k].rgb, al);
				} else {
					tr = glow_at(h, 3.0);
					cc = vec4(pick[k].rgb, 0.3);
				}
			}
		}
	} else if (mode == 1) {
		float age = js_cycle(seed, i, T, D, 1.4, 2.4, L);
		if (age >= 0.0) {
			uint r = js_hash2(seed, i);
			float ph0 = js_range(r, 0.0, TAU);
			float rho0 = js_range(r, 58.0, 80.0);
			float hgt = js_range(r, -8.0, 8.0);
			float size = js_range(r, 1.6, 2.8);
			vec4 a = deb_at(age, L, ph0, rho0, hgt);
			vec4 b = deb_at(age - 0.04, L, ph0, rho0, hgt);
			bool hidden = a.z > 0.0 && length(vec2(a.x, a.y - Y)) < RS + 1.0;
			if (!hidden) {
				bool flash = a.w < RS + 3.0;
				float heat = 1.0 - smoothstep(16.0, 34.0, a.w);
				bool s2 = size > 2.2;
				if (flash) {
					if (part == 9) { shown = true; tr = cell(a.xy, 1.0); }
					if (part == 10) { shown = true; tr = glow_at(a.xy, 6.0); cc = vec4(col2.rgb, 0.6); }
				} else if (heat > 0.05) {
					float len = 1.0 + heat * 7.0;
					vec2 dv = a.xy - b.xy;
					float l = max(length(dv), 1e-4);
					vec2 st = a.xy - dv / l * len;
					if (part == 6) { shown = true; tr = seg_line(st, a.xy, 0.0, 1.0); }
					if (part == 7) { shown = true; tr = seg_line(st, a.xy, 0.4, 1.0); }
					if (part == 8) { shown = true; tr = seg_line(st, a.xy, 0.75, 1.0); }
					if (part == 10) { shown = true; tr = glow_at(a.xy, 4.0); cc = vec4(col2.rgb, 0.4 * heat); }
				} else {
					float dh = max(length(vec2(a.x, a.y - Y)), 1.0);
					vec2 lv = -vec2(a.x, a.y - Y) / dh;
					if (part == 0 && !s2) { shown = true; tr = cell(a.xy, 2.0); }
					if (part == 1 && s2) { shown = true; tr = cell(a.xy, 3.0); }
					if (part == 2) { shown = true; tr = cell(a.xy + round(lv * 1.4), 1.0); cc = s2 ? col2 : col; }
					if (part == 3) { shown = true; tr = cell(b.xy, 1.0); }
					if (part == 4) { shown = true; tr = cell(deb_at(age - 0.09, L, ph0, rho0, hgt).xy, 1.0); cc = vec4(col.rgb, 0.7); }
					if (part == 5) { shown = true; tr = cell(deb_at(age - 0.15, L, ph0, rho0, hgt).xy, 1.0); cc = vec4(col.rgb, 0.5); }
					if (part == 10) { shown = true; tr = glow_at(a.xy, 4.0); cc = vec4(col.rgb, 0.15); }
				}
			}
		}
	} else {
		float age = js_cycle(seed, i, T, D, 1.6, 2.6, L);
		if (age >= 0.0) {
			uint r = js_hash2(seed, i);
			float x0 = js_range(r, -60.0, 60.0);
			float u = pow(age / L, 1.5);
			float tx = (x0 < 0.0 ? -1.0 : 1.0) * js_range(r, 40.0, 56.0);
			float ty = Y + js_range(r, 4.0, 9.0);
			vec2 p = vec2(x0 + (tx - x0) * u, -1.0 + (ty + 1.0) * u - sin(PI * u) * 10.0);
			if (part == 0) {
				shown = true;
				tr = cell(p, 1.0);
				cc = u > 0.6 ? col2 : col;
			} else if (age < 0.25) {
				shown = true;
				tr = quad(vec2(x0, -1.5), 0.0, vec2(2.0 * (2.0 + age * 8.0) / tex));
				cc = vec4(col.rgb, 0.4 * (1.0 - age / 0.25));
			}
		}
	}
	if (!shown) {
		tr = quad(vec2(0.0, 0.0), 0.0, vec2(0.0));
		cc = vec4(0.0);
	}
	c = cc;
}

void start() {
	CUSTOM = vec4(0.0);
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, int(INDEX));
}

void process() {
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, int(INDEX));
}
