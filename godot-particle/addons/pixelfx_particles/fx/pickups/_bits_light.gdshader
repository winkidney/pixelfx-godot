// The light the pickups' particles give off (the original's p.glow round each glint, mote, spark and fleck), on the
// light layer: the light twin of an emitter drawn by _bits.gdshader (same data, placed by _ftp.gdshader). Row 2 of
// a frame holds where the glow is (effect px), its radius and strength; row 1 its colour's index in `pal`.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float quad = 9.0;
uniform vec4 pal[16] : source_color;
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	int i = int(cu.x + 0.5);
	int f = int(cu.y + 0.5);
	vec4 r1 = texelFetch(data, ivec2(i, f * 4 + 1), 0);
	vec4 r2 = texelFetch(data, ivec2(i, f * 4 + 2), 0);
	// this pixel's centre in the effect's px: the particle's cell centre plus a whole number of pixels
	vec2 pc = cu.zw + 0.5 + floor((UV - 0.5) * quad + 0.5);
	vec3 l = lt_glow(pc, r2.xy, r2.z, pal[int(r1.z + 0.5)].rgb, r2.w * strength * lt_edge(pc, canvas));
	COLOR = vec4(l * COLOR.a, 1.0);
}
