// The time-stop clock (after time-stop.js face() and drawMote()): a glass face opening to scale `s`, rims, minute dots
// and hour ticks, an inner ring, the hour hand (a short beam), the second hand with its tail, the hub, cracks walking
// out across it (`cracked` 0..1 of each walk drawn, the last two pixels fresh white); motes circling it with tails
// while they move. `pass` 0 draws only the motes behind it; 1 the face and the motes in front. `pal` picks the ramp:
// 0 the colours, 1 drained grey, 2 all white. The rect is centred on the clock. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/arcane/_clock.gdshaderinc"

uniform vec2 size = vec2(100.0);
uniform float pass = 1.0;
uniform float pal = 0.0;
uniform float s = 1.0;
uniform float rc = 26.0;
uniform float sa = 0.0;
uniform float ha = 0.0;
uniform float cracked = 0.0;
uniform float moving = 1.0;
uniform float cold = 0.0;
uniform vec4 cols[8];
uniform vec4 greys[8];
// crack pixels: x, y (from the centre), index along its walk, the walk's length
uniform vec4 cracks[160];
uniform int crack_count = 0;

vec4 K(int i) {
	return pal > 1.5 ? vec4(1.0) : pal > 0.5 ? greys[i] : cols[i];
}

bool on_line(vec2 cell, vec2 a, vec2 b, out float u) {
	vec2 fa = floor(a);
	vec2 fb = floor(b);
	vec2 d = fb - fa;
	u = 0.0;
	if (abs(d.x) >= abs(d.y)) {
		if (cell.x < min(fa.x, fb.x) || cell.x > max(fa.x, fb.x)) {
			return false;
		}
		u = abs(d.x) < 0.5 ? 0.0 : (cell.x - fa.x) / d.x;
		return cell.y == floor(fa.y + d.y * u + 0.5);
	}
	if (cell.y < min(fa.y, fb.y) || cell.y > max(fa.y, fb.y)) {
		return false;
	}
	u = (cell.y - fa.y) / d.y;
	return cell.x == floor(fa.x + d.x * u + 0.5);
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + 0.001);
	vec2 p = cell + 0.5;
	vec4 c = vec4(0.0);
	vec4 glass = vec4(0.0);
	bool back = pass < 0.5;
	float r = rc * s;
	if (!back && r >= 1.0) {
		float d = length(p);
		if (d <= r) {
			glass = vec4(K(1).rgb, 0.3 + 0.35 * (d / r) * (d / r));
		}
		if (d <= r + 0.5 && d >= r - 0.5) {
			c = K(6);
		}
		if (d <= r - 1.5 && d >= r - 2.5) {
			c = K(4);
		}
		if (d <= r + 2.0 && d >= r + 1.0) {
			c = vec4(K(3).rgb, 0.6);
		}
		float u;
		for (int i = 0; i < 60; i++) {
			float a = float(i) / 60.0 * TAU;
			vec2 dir = vec2(cos(a), sin(a));
			if (i % 5 != 0) {
				if (cell == floor(dir * (r - 3.5))) {
					c = vec4(K(4).rgb, 0.8);
				}
			} else {
				bool q = i % 15 == 0;
				if (on_line(cell, dir * (r - (q ? 8.0 : 6.5)), dir * (r - 3.0), u)) {
					c = q ? K(7) : K(6);
				}
			}
		}
		if (d <= r * 0.3 && d >= r * 0.3 - 1.0) {
			c = vec4(K(4).rgb, 0.8);
		}
		// the hour hand: a short beam
		vec2 hd = vec2(cos(ha), sin(ha));
		float along = dot(p, hd);
		float across = dot(p, vec2(-hd.y, hd.x));
		if (along >= 0.0 && along <= r * 0.48 && abs(across) <= 1.3) {
			c = (across + 1.3) / 2.6 < 0.5 ? K(6) : K(4);
		}
		// the second hand and its tail
		vec2 sd = vec2(cos(sa), sin(sa));
		if (on_line(cell, -sd * 5.0, sd * (r - 4.0), u)) {
			c = u > 0.75 ? K(7) : K(6);
		}
		if (on_line(cell, -sd * 5.0 + vec2(0.5, 0.0), -sd * 2.0, u)) {
			c = K(5);
		}
		if (d <= 2.2) {
			c = d <= 1.2 ? K(7) : K(5);
		}
		// cracks
		if (cracked > 0.0) {
			for (int i = 0; i < 160; i++) {
				if (i >= crack_count) {
					break;
				}
				vec4 k = cracks[i];
				float n = floor(k.w * cracked);
				if (k.z >= n) {
					continue;
				}
				bool fresh = k.z > n - 3.0 && cracked < 1.0;
				vec2 f = floor(k.xy);
				if (cell == f) {
					c = fresh ? vec4(1.0) : K(7);
				} else if (!fresh && cell == f - vec2(0.0, 1.0) && c != K(7)) {
					c = K(2);
				}
			}
		}
	}
	// the motes (behind or in front), with a tail while they still move
	for (int i = 0; i < 14; i++) {
		vec4 m = motes[i];
		float a = m.x + m.z * tc;
		if ((sin(a) < 0.0) != back) {
			continue;
		}
		if (cell == floor(mote_pos(m, a))) {
			c = vec4((cold > 0.5 ? greys[6] : mote_cols[i]).rgb, back ? 0.6 : 1.0);
		}
		float v = moving * m.z;
		if (abs(v) > 0.2) {
			for (int k = 1; k <= 3; k++) {
				float b = a - sign(m.z) * float(k) * 0.05 * min(1.0, abs(v));
				if (cell == floor(mote_pos(m, b))) {
					c = vec4((k < 2 ? cols[5] : cols[4]).rgb, (back ? 0.5 : 0.9) * (1.0 - float(k) / 4.0));
				}
			}
		}
	}
	if (c.a > 0.0 && !pfx_pixel(c, FRAGCOORD.xy)) {
		COLOR = c;
	} else if (glass.a > 0.0) {
		COLOR = vec4(pfx_snap(glass.rgb), floor(glass.a * 8.0 + 0.5) / 8.0);
	} else {
		discard;
	}
}
