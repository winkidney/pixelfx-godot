// A draw list's translucent discs (_list.gdshaderinc kind 5: painter.js disc()), blended in order, soft layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_list.gdshaderinc"

void fragment() {
	vec2 q = floor((UV - 0.5) * size) + center;
	vec2 c = q + 0.5;
	ivec2 sp = list_span();
	int n = sp.y;
	vec4 acc = vec4(0.0);
	for (int e = 0; e < n; e++) {
		vec4 g = entry(sp.x + e, 0);
		vec4 h = entry(sp.x + e, 1);
		if (int(h.x + 0.5) != 5) continue;
		float r = h.w;
		float a = h.z;
		bool in_ = r < 0.5 ? floor(g.xy) == q : dot(c - g.xy, c - g.xy) <= r * r;
		if (!in_ || a <= 0.004) continue;
		vec3 col = PAL[int(h.y + 0.5)].rgb;
		float oa = a + acc.a * (1.0 - a);
		float k = a / oa;
		acc = vec4(col * k + acc.rgb * (1.0 - k), oa);
	}
	if (acc.a <= 0.0 || pfx_pixel(acc, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = acc;
}
