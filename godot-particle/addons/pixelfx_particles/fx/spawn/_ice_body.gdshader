// spawn/shatter-death's ice, before it bursts, as the original draws it: the body grown by a pixel and cut into
// facets (`grid`: each cell's colour under the ice, its flags: ice, solid seam or rim, which glass tint), climbing
// from the feet behind a white rime line, a flash as it locks, a glint running across it, a dark outline holding it
// together, rime spikes growing out of it (the original's crystal()), cracks running from the chest, the whole thing
// shaking before it goes; then the white burst. Colour layer; the body's cold mixes kept as they are.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(56.0, 50.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D grid : filter_nearest;
uniform sampler2D cracks : filter_nearest;
uniform vec2 origin = vec2(-13.0, -39.0);
uniform float t = 0.0;
uniform float lock_t = 0.5;
uniform float crack_t = 1.05;
uniform float lv = 40.0;
uniform float shake = 0.0;
uniform float glint = -1.0;
uniform float show_ice = 1.0;
uniform float crack_k = -1.0;
uniform float crack_count = 0.0;
uniform vec3 burst = vec3(0.0, 0.0, -1.0);
// spikes: (x, base, h, w), (lean, at, .., ..)
uniform vec4 spike_a[12];
uniform vec4 spike_b[12];
uniform float spike_count = 0.0;
uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);

ivec2 gsz() {
	return textureSize(grid, 0);
}

vec4 cell_at(int x, int y) {
	ivec2 s = gsz();
	if (x < 0 || y < 0 || x >= s.x || y >= s.y) {
		return vec4(0.0);
	}
	return texelFetch(grid, ivec2(x, y), 0);
}

bool at(int x, int y) {
	return mod(cell_at(x, y).w, 2.0) > 0.5;
}

vec3 mix8(vec3 a, vec3 b, float k) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * k) / 255.0;
}

bool same(vec3 a, vec3 b) {
	return all(lessThan(abs(a - b), vec3(0.002)));
}

float out_back(float x, float s) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x >= 1.0) {
		return 1.0;
	}
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

bool c_inside(vec2 q, float x, float base, float h, float w, float lean) {
	float u = (base - (q.y + 0.5)) / h;
	return u >= 0.0 && u <= 1.0 && abs(q.x + 0.5 - (x + lean * u)) <= (w / 2.0) * (1.0 - u) + 0.35;
}

// the original's crystal() at this cell: colour, or a = 0
vec4 crystal(vec2 q, float x, float base, float h, float w, float lean, bool wh) {
	if (h < 1.5) {
		return vec4(0.0);
	}
	float top = base - h;
	if (q.y < floor(top) - 1.0 || q.y > ceil(base) - 1.0 || q.x < floor(x - w / 2.0 - abs(lean) - 2.0) || q.x > ceil(x + w / 2.0 + abs(lean) + 2.0)) {
		return vec4(0.0);
	}
	if (!c_inside(q, x, base, h, w, lean)) {
		if (c_inside(q - vec2(1.0, 0.0), x, base, h, w, lean) || c_inside(q + vec2(1.0, 0.0), x, base, h, w, lean)
				|| c_inside(q + vec2(0.0, 1.0), x, base, h, w, lean) || (c_inside(q - vec2(0.0, 1.0), x, base, h, w, lean) && q.y < base - 1.0)) {
			return pal[0];
		}
		return vec4(0.0);
	}
	if (wh) {
		return white;
	}
	float u = (base - (q.y + 0.5)) / h;
	float ridge0 = x - w * 0.14;
	float rx = ridge0 + (x + lean - ridge0) * u;
	float c = x + lean * u;
	float hw = (w / 2.0) * (1.0 - u) + 0.35;
	float fx = q.x + 0.5;
	if (u > 0.9) {
		return white;
	}
	if (abs(fx - rx) < 0.55) {
		return pal[6];
	}
	if (fx < rx) {
		return fx - (c - hw) < 1.0 ? pal[6] : (fx - (c - hw)) / max(1.0, rx - (c - hw)) > 0.55 ? pal[5] : pal[4];
	}
	return c + hw - fx < 1.2 ? pal[1] : (fx - rx) / max(1.0, c + hw - rx) > 0.5 ? pal[2] : pal[3];
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	ivec2 gs = gsz();
	int W = gs.x;
	int H = gs.y;
	vec4 o = vec4(0.0);
	if (show_ice > 0.5) {
		// which grid cell lands here (the shake moves everything by a fraction of a pixel)
		int gy = int(cell.y - origin.y);
		int gx = int(cell.x - origin.x - floor(shake));
		int flv = int(floor(lv));
		vec4 g = cell_at(gx, gy);
		bool ice = mod(g.w, 2.0) > 0.5;
		if (ice && gy >= flv) {
			bool solid = mod(floor(g.w / 2.0), 2.0) > 0.5;
			int gi = int(floor(g.w / 4.0) + 0.5);
			vec3 col = g.rgb;
			vec3 c = gy == flv && t < lock_t ? (js_rand2(gx, 5) < 0.6 ? white.rgb : pal[6].rgb) : t >= lock_t && t < lock_t + 0.05 ? white.rgb : col;
			float gg = abs((float(gx) + float(H - gy) * 0.6) / (float(W) + float(H) * 0.6) - glint);
			bool on = glint >= 0.0 && glint <= 1.0;
			if (on && gg < 0.035) {
				c = white.rgb;
			} else if (on && gg < 0.07 && !same(c, pal[3].rgb)) {
				c = pal[6].rgb;
			}
			if (!solid && same(c, col)) {
				c = mix8(c, pal[3 + gi].rgb, 0.3);
			}
			o = vec4(c, 1.0);
		} else if (!ice && gy >= max(0, flv - 1) && gy < H) {
			if (at(gx - 1, gy) || at(gx + 1, gy) || (at(gx, gy + 1) && float(gy + 1) >= lv) || at(gx, gy - 1)) {
				o = pal[0];
			}
		}
		for (int i = 0; i < 12; i++) {
			if (float(i) >= spike_count) {
				break;
			}
			vec4 a = spike_a[i];
			vec4 b = spike_b[i];
			float gr = out_back(clamp((t - b.y) / 0.12, 0.0, 1.0), 2.4);
			if (gr > 0.0) {
				vec4 s = crystal(cell, a.x + shake, a.y, a.z * gr, a.w, b.x * gr, t < b.y + 0.04);
				if (s.a > 0.0) {
					o = s;
				}
			}
		}
		if (crack_k >= 0.0) {
			int n = int(crack_count + 0.5);
			for (int j = 0; j < 512; j++) {
				if (j >= n) {
					break;
				}
				vec4 p = texelFetch(cracks, ivec2(j, 0), 0);
				float shown = floor(p.w * crack_k);
				if (p.z >= shown) {
					continue;
				}
				bool fresh = p.z > shown - 3.0 && t - crack_t < 0.3;
				vec2 m = floor(origin + p.xy + vec2(shake, 0.0));
				if (all(equal(cell, m))) {
					o = fresh ? white : pal[7];
				}
				if (!fresh && all(equal(cell, m + vec2(0.0, 1.0)))) {
					o = pal[1];
				}
			}
		}
	}
	if (burst.z >= 0.0) {
		vec2 d = cell + 0.5 - burst.xy;
		if (dot(d, d) <= burst.z * burst.z) {
			o = white;
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
