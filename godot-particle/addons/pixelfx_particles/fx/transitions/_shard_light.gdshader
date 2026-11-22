// shatter-wipe's shards' light: a glow on each lit edge of a falling shard.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_shard.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec2 q = cu.zw + d;
	Sh s = sh_load();
	COLOR = vec4(sh_light(s, q + 0.5) * strength, 1.0);
}
