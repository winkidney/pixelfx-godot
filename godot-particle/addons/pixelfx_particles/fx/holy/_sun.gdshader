// The sunburst's body (holy/sunburst, colour layer): fine threads between the rays, long and short tapered rays
// turning and breathing, a glint running out along each long ray and winking at its tip, the flickering corona and
// the white core. `t` runs 0..1 over the loop (keyed); the rect is centred on the sun.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(128.0);
uniform float t = 0.0;
uniform int rays = 8;
uniform vec4 pal[8] : source_color;

const float CORE = 4.5;
const float RING = 7.5;
const float R0 = 9.0;

// a 1 px line from the centre outwards at angle a, r0..r1: true when this pixel is on it (the DDA's pixels)
bool on_line(vec2 p, float a, float r0, float r1, out float u) {
	vec2 d = vec2(cos(a), sin(a));
	float along = dot(p, d);
	u = (along - r0) / max(r1 - r0, 0.001);
	if (u < -0.02 || u > 1.02) {
		return false;
	}
	float across = abs(-p.x * d.y + p.y * d.x);
	return across / max(abs(d.x), abs(d.y)) < 0.5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec2 cell = floor(p);
	int N = rays * 2;
	float rot = t * (2.0 * TAU / float(N));
	vec4 c = vec4(0.0);
	float r = length(p);
	// the corona and the core, on top of everything
	if (r <= RING) {
		float flick = 0.5 + 0.5 * sin(atan(p.y, p.x) * 5.0 + t * TAU * 3.0);
		c = r < CORE ? vec4(1.0) : r < CORE + 1.5 ? (flick > 0.6 ? vec4(1.0) : pal[6]) : flick > 0.5 ? pal[5] : pal[4];
	} else {
		// threads between the rays
		for (int i = 0; i < N; i++) {
			float a = rot + (float(i) + 0.5) * TAU / float(N);
			float L = 14.0 + 6.0 * sin(a * 3.0 + t * TAU);
			float u;
			if (on_line(p, a, R0 + 1.0, R0 + L, u)) {
				c = vec4((u < 0.3 ? pal[6] : pal[5]).rgb, 0.7 - clamp(u, 0.0, 1.0) * 0.8);
			}
		}
		// the rays, long and short by turns
		for (int i = 0; i < N; i++) {
			float a = rot + float(i) * TAU / float(N);
			bool long_ray = i % 2 == 0;
			float breathe = 0.86 + 0.14 * sin(a * 3.0 - t * TAU * 2.0);
			float L = (long_ray ? 36.0 : 21.0) * breathe;
			float w0 = long_ray ? 4.0 : 2.6;
			vec2 d = vec2(cos(a), sin(a));
			float along = dot(p, d) - R0;
			float u = along / L;
			if (u >= 0.0 && u <= 1.0) {
				float across = abs(-p.x * d.y + p.y * d.x);
				float w = (w0 / 2.0) * (1.0 - u * 0.85) + 0.25;
				if (across <= w) {
					bool spine = across < 0.5;
					bool rim = across > w - 0.6 && w > 0.9;
					vec4 cc = spine ? (u < 0.4 ? vec4(1.0) : u < 0.75 ? pal[6] : pal[5]) : (rim && u > 0.15) ? pal[3] : u < 0.3 ? pal[6] : u < 0.62 ? pal[5] : pal[4];
					cc.a = u < 0.72 ? 1.0 : (1.0 - (u - 0.72) / 0.28) * 1.2;
					// a dithered-out pixel leaves what's under it
					if (cc.a >= pfx_threshold(FRAGCOORD.xy)) {
						c = vec4(cc.rgb, 1.0);
					}
				}
			}
			// the glint running out along a long ray, winking at its tip
			if (long_ray) {
				float g = fract(t * 2.0 + a * 3.0 / TAU);
				if (g < 0.9) {
					vec2 q = floor(d * (R0 + g * L));
					if (cell == q) {
						c = vec4(1.0);
					}
				} else {
					int n = int(round(1.0 + 3.0 * sin((g - 0.9) / 0.1 * PI)));
					vec2 q = floor(d * (R0 + L));
					ivec2 o = ivec2(cell - q);
					int ax = abs(o.x);
					int ay = abs(o.y);
					if (o == ivec2(0)) {
						c = vec4(1.0);
					} else if ((o.x == 0 && ay <= n) || (o.y == 0 && ax <= n)) {
						c = float(max(ax, ay)) > float(n) * 0.6 ? pal[6] : vec4(1.0);
					} else if (n >= 3 && ax == 1 && ay == 1) {
						c = vec4(1.0);
					}
				}
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
