// spawn/shatter-death's pieces of ice: each facet flies as one piece carrying its own pixels (`maps`: a square of
// `msize` cells a piece, its colours as they were), turned by its angle without holes, white for a moment as it
// breaks off, melting away pixel by pixel (the original's hash) as its life runs out. Colour layer.
//   head 1 (map row, ..); rows 0 (x, y, on, angle), 1 (fade, white, id, reach)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform sampler2D maps : filter_nearest;
uniform float msize = 25.0;
uniform vec4 white : source_color = vec4(1.0);

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 h1 = tk_head(1);
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 c = tk_cell(UV);
	float r = r1.w;
	if (abs(c.x) > r || abs(c.y) > r) {
		discard;
	}
	float ca = cos(r0.w);
	float sa = sin(r0.w);
	int ux = int(floor(c.x * ca + c.y * sa + 0.5));
	int uy = int(floor(-c.x * sa + c.y * ca + 0.5));
	int hm = int(msize) / 2;
	if (abs(ux) > hm || abs(uy) > hm) {
		discard;
	}
	vec4 m = texelFetch(maps, ivec2(ux + hm, int(h1.x + 0.5) * int(msize) + uy + hm), 0);
	if (m.w < 0.5 || js_rand3(ux, uy, int(r1.z + 0.5)) >= r1.x) {
		discard;
	}
	COLOR = vec4(r1.y > 0.5 ? white.rgb : m.rgb, 1.0);
}
