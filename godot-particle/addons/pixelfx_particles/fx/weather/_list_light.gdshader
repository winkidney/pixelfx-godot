// A draw list's glows (_list.gdshaderinc kind 6: painter.js glow()), added on the light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_list.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 c = floor((UV - 0.5) * size) + center + 0.5;
	ivec2 sp = list_span();
	int n = sp.y;
	vec3 l = vec3(0.0);
	for (int e = 0; e < n; e++) {
		vec4 g = entry(sp.x + e, 0);
		vec4 h = entry(sp.x + e, 1);
		if (int(h.x + 0.5) != 6) continue;
		l += PAL[int(h.y + 0.5)].rgb * glow_(c, g.xy, h.w, h.z);
	}
	COLOR = vec4(l * strength, 1.0);
}
