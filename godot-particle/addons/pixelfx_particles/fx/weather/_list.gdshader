// A draw list (_list.gdshaderinc) on the colour layer: the last entry that covers a pixel (and survives the dither)
// paints it.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_list.gdshaderinc"

void fragment() {
	vec2 q = floor((UV - 0.5) * size) + center;
	float thr = pfx_threshold(FRAGCOORD.xy);
	ivec2 sp = list_span();
	int n = sp.y;
	vec4 c = vec4(0.0);
	for (int e = n - 1; e >= 0; e--) {
		vec4 g = entry(sp.x + e, 0);
		vec4 h = entry(sp.x + e, 1);
		int kind = int(h.x + 0.5);
		if (kind >= 5) continue;
		float a = h.z;
		if (a <= 0.0 || (a < 1.0 && a <= thr)) continue;
		float r = h.w;
		vec2 lo = min(g.xy, g.zw) - r - 2.0;
		vec2 hi = max(g.xy, g.zw) + r + 2.0;
		if (q.x < lo.x || q.y < lo.y || q.x > hi.x || q.y > hi.y) continue;
		bool hit = false;
		float u;
		if (kind == 0) hit = on_line(q, floor(g.xy), floor(g.zw), u);
		else if (kind == 1) hit = floor(g.xy) == q;
		else hit = stamps(q, g.xy, g.zw, r, kind >= 3, kind == 4);
		if (hit) {
			c = PAL[int(h.y + 0.5)];
			break;
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
