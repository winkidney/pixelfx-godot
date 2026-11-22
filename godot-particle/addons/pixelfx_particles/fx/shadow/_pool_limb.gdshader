// A tentacle or an arm with its hand, colour pass (see _pool_limb.gdshaderinc): the original's cross-sections (a
// near-black body, lighter on the half toward the light), its rims (bright toward the light, white where it faces it
// squarely, violet on the other side), a tentacle's suckers inside its hook and the pulse of light running up it, its
// white tip, the lit collar of ink where it breaks the surface; an arm's hand (palm, four two-bone fingers and a
// thumb with lit edges and pale claws, clenching with `grip`). Every cell takes the last thing the original draws
// there. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_pool_limb.gdshaderinc"

uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

bool on(vec2 cell, vec2 at) {
	return all(equal(cell, floor(at)));
}

// the cells of the original's 1 px line from a's cell to b's (Bresenham)
bool on_line(vec2 cell, vec2 a, vec2 b) {
	ivec2 s = ivec2(floor(a));
	ivec2 e = ivec2(floor(b));
	ivec2 c = ivec2(cell);
	int dx = abs(e.x - s.x);
	int dy = -abs(e.y - s.y);
	int sx = s.x < e.x ? 1 : -1;
	int sy = s.y < e.y ? 1 : -1;
	int err = dx + dy;
	for (int i = 0; i < 64; i++) {
		if (s == c) {
			return true;
		}
		if (s == e) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			s.x += sx;
		}
		if (e2 <= dx) {
			err += dx;
			s.y += sy;
		}
	}
	return false;
}

// a finger bone: dark line, lit line beside it, a white claw and a pale point past it on the last one
vec2 bone(vec2 cell, vec2 a, float ang, float l, bool last, float side, inout vec4 c) {
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 b = a + dir * l;
	vec2 o = vec2(floor(sin(ang) * side + 0.5), floor(-cos(ang) * side + 0.5));
	if (on_line(cell, a, b)) {
		c = c1;
	}
	if (on_line(cell, a + o, b + o)) {
		c = c5;
	}
	if (last) {
		if (on(cell, b)) {
			c = white;
		}
		if (on(cell, b + dir)) {
			c = c7;
		}
	}
	return b;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec2 cell = floor(p);
	vec4 c = vec4(0.0);
	int n = limb_n();
	vec2 q;
	float th;
	// the body: every cross-section's samples (v from -w to w by 0.5) that land in this cell; the last one wins
	limb_start(q, th);
	for (int i = 0; i <= 200; i++) {
		if (i > n) {
			break;
		}
		float s = float(i) * 0.5;
		float u = s / len;
		float w = limb_w(u);
		if (q.y <= surf) {
			vec2 nr = vec2(-sin(th), cos(th));
			float ks = dot(nr, LDIR) >= 0.0 ? 1.0 : -1.0;
			float lo = -1e9;
			float hi = 1e9;
			bool ok = true;
			for (int k = 0; k < 2; k++) {
				float qk = k == 0 ? q.x : q.y;
				float nk = k == 0 ? nr.x : nr.y;
				float ck = k == 0 ? cell.x : cell.y;
				if (abs(nk) < 1e-6) {
					ok = ok && qk >= ck && qk < ck + 1.0;
				} else {
					float a = (ck - qk) / nk;
					float b = (ck + 1.0 - qk) / nk;
					lo = max(lo, min(a, b));
					hi = min(hi, max(a, b));
				}
			}
			// and the sample stays above the surface
			if (abs(nr.y) > 1e-6) {
				float vs = (surf - q.y) / nr.y;
				if (nr.y > 0.0) {
					hi = min(hi, vs + 1e-5);
				} else {
					lo = max(lo, vs - 1e-5);
				}
			}
			hi = min(hi - 1e-5, w + 1e-5);
			if (ok && hi >= lo) {
				float kk = floor((hi + w) * 2.0);
				float v = -w + 0.5 * kk;
				if (kk >= 0.0 && v >= lo - 1e-5) {
					float uu = v / w * ks;
					c = uu > 0.55 ? c2 : uu > -0.45 ? c1 : c0;
				}
			}
		}
		limb_step(q, th, s, u);
	}
	// the rims, suckers and pulses, in the original's order
	float pulse = (t - t0) * 150.0;
	float slow = mod((t - t0) * 55.0, len * 1.8) - 4.0;
	vec2 base = vec2(1e9);
	float base_w = 0.0;
	vec2 tip;
	float tip_th;
	limb_start(q, th);
	for (int i = 0; i <= 200; i++) {
		if (i > n) {
			break;
		}
		float s = float(i) * 0.5;
		float u = s / len;
		float w = limb_w(u);
		tip = q;
		tip_th = th;
		if (q.y <= surf) {
			if (base.x > 1e8) {
				base = q;
				base_w = w;
			}
			vec2 nr = vec2(-sin(th), cos(th));
			float f = dot(nr, LDIR);
			float ks = f >= 0.0 ? 1.0 : -1.0;
			vec2 p0 = q + nr * ks * w;
			vec2 p1 = q - nr * ks * w;
			if (p1.y <= surf && on(cell, p1)) {
				c = c3;
			}
			if (p0.y <= surf && on(cell, p0)) {
				if (mode == 0) {
					c = abs(f) > 0.8 && u > 0.15 ? c7 : u > 0.85 ? c6 : abs(f) > 0.3 ? c6 : c5;
				} else {
					c = abs(f) > 0.8 ? c7 : c6;
				}
			}
			if (mode == 0) {
				if (u > 0.62 && u < 0.93 && mod(s, 3.0) < 0.5 && on(cell, q + nr * curl * w * 0.45)) {
					c = c4;
				}
				float dp = min(abs(s - pulse), abs(s - slow) * 1.6);
				if (dp < 2.5 && on(cell, q)) {
					c = dp < 1.0 ? c7 : c5;
				}
			}
		}
		limb_step(q, th, s, u);
	}
	if (mode == 0) {
		if (tip.y <= surf && on(cell, tip)) {
			c = white;
		}
		if (base.x < 1e8) {
			float w = base_w + 1.5;
			if (on_line(cell, vec2(base.x - w, surf), vec2(base.x + w, surf))) {
				c = c5;
			}
			if (on(cell, vec2(base.x - w - 1.0, surf + 0.5)) || on(cell, vec2(base.x + w + 1.0, surf + 0.5))) {
				c = c3;
			}
		}
	} else {
		if (base.x < 1e8 && on_line(cell, vec2(base.x - base_w - 1.5, surf), vec2(base.x + base_w + 1.5, surf))) {
			c = c5;
		}
		// the hand
		if (tip.y <= surf - 2.0) {
			vec2 dv = vec2(cos(tip_th), sin(tip_th));
			vec2 nv = vec2(-dv.y, dv.x);
			float side = curl;
			vec2 cc = tip + dv * 2.6;
			vec2 r = p - cc;
			float a = dot(r, dv);
			float b = dot(r, nv);
			float d = (a / 3.0) * (a / 3.0) + (b / 2.7) * (b / 2.7);
			if (d <= 1.25 && abs(r.x) <= 5.6 && abs(r.y) <= 5.6) {
				if (d > 1.0) {
					c = b * side < 0.0 ? c6 : c3;
				} else {
					c = b * side < -1.0 ? c2 : c1;
				}
			}
			float g = grip;
			float spread = 1.0 - 0.65 * max(0.0, g);
			float cu = g * 1.2;
			for (int i = 0; i < 4; i++) {
				float o = i == 0 ? -2.2 : i == 1 ? -0.75 : i == 2 ? 0.75 : 2.2;
				vec2 bp = cc + dv * 2.6 + nv * o * 0.9;
				float l = (i == 0 || i == 3) ? 2.6 : 3.2;
				float a0 = tip_th + o * 0.2 * spread;
				vec2 j = bone(cell, bp, a0 + cu * side * 0.6, l, false, side, c);
				bone(cell, j, a0 + cu * side * 1.5, l * 0.85, true, side, c);
			}
			vec2 j = bone(cell, cc - nv * side * 2.4, tip_th - side * (1.0 - 0.6 * g), 2.4, false, side, c);
			bone(cell, j, tip_th - side * (0.6 - 1.4 * g), 2.0, true, side, c);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
