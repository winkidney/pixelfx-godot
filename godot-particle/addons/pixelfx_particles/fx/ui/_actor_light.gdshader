// level-up's warm light over the hero (src/fx/ui/_lib.js lightActor, its body light): every pixel of the stand-in's
// mask (`body`, top-left at `at`) gets c at k, stronger towards the top (1.1 - 0.5 j / h), added as the original's
// light buffer adds it. k keyed every frame. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D body : filter_nearest, repeat_disable;
uniform vec2 at = vec2(0.0);
uniform vec4 c : source_color = vec4(1.0);
uniform float k = 0.0;
uniform float strength = 1.0;
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	ivec2 q = ivec2(cell - at);
	ivec2 bs = textureSize(body, 0);
	if (k <= 0.01 || q.x < 0 || q.y < 0 || q.x >= bs.x || q.y >= bs.y || texelFetch(body, q, 0).a < 0.5) {
		discard;
	}
	float kk = k * (1.1 - (0.5 * float(q.y)) / float(bs.y)) * strength * lt_edge(cell + 0.5, canvas);
	COLOR = vec4(lt_add(c.rgb, kk), 1.0);
}
