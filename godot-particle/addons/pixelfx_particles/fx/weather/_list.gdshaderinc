// A draw list replayed: the original's line / dot / circle / pixel calls for one frame, worked out at build time
// (build/fx/weather/storm.gd: the bolt's channel, the spider lightning, the arcs and sparks where it strikes, their
// steam), packed in `data` two texels an entry: (ax, ay, bx, by), (kind, colour, alpha, radius). Kinds: 0 a 1 px line a -> b, 1 a dot at a, 2 circles of radius r stamped every 0.5 px from a to
// b, 3 pixels stamped likewise (4: and the pixel right of each), 5 a translucent disc at a (soft layer), 6 a glow
// at a (radius r, strength alpha; light layer).
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_line.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D data : filter_nearest, repeat_disable;
// frame f's entries: texel f of `index` = (first entry, how many)
uniform sampler2D index : filter_nearest, repeat_disable;
uniform float frames = 300.0;
uniform vec4 PAL[16] : source_color;

// this frame's entries: the first and how many
ivec2 list_span() {
	int f = clamp(int(floor(t * 30.0 + 0.5)), 0, int(frames) - 1);
	vec4 r = texelFetch(index, ivec2(f, 0), 0);
	return ivec2(int(r.x + 0.5), int(r.y + 0.5));
}

// texel k (0: the shape, 1: what it is) of entry e
vec4 entry(int e, int k) {
	int w = textureSize(data, 0).x;
	int i = e * 2 + k;
	return texelFetch(data, ivec2(i % w, i / w), 0);
}

// whether a stamped run a -> b (every 0.5 px, as the original's loops step) covers cell q: circles of radius r
// (r < 0.6: the stamp's own cell), or with px the stamps' cells (dbl: and the cell right of each)
bool stamps(vec2 q, vec2 a, vec2 b, float r, bool px, bool dbl) {
	vec2 e = b - a;
	float l = max(1.0, length(e));
	vec2 c = q + 0.5;
	float pr = dot(c - a, e) / max(1e-6, length(e));
	if (length(e) < 1e-6) pr = 0.0;
	float reach = max(r, 1.5) + 1.0;
	int lo = max(0, int(floor((pr - reach) * 2.0)));
	int hi = min(int(floor(l * 2.0 + 1e-6)), int(ceil((pr + reach) * 2.0)));
	for (int s = lo; s <= hi; s++) {
		vec2 p = a + e * (float(s) * 0.5) / l;
		if (px || r < 0.6) {
			if (floor(p) == q || (dbl && floor(p + vec2(1.0, 0.0)) == q)) return true;
		} else {
			vec2 dd = c - p;
			if (dot(dd, dd) <= r * r) return true;
		}
	}
	return false;
}
