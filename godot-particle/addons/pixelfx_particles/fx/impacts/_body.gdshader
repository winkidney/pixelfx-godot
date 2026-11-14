// The stand-in's own pixels recoloured by a hit (src/fx/impacts/hit-flash.js), drawn over it: look 0 nothing, 1 all
// white, 2 each pixel's light and shade carried into the red ramp (reds[2 + luma * 5]), 3 its own colour washed
// toward `wash` by 0.55 * cool. An outline round the silhouette in outline_c, dithered by outline_a. `tex` is the
// stand-in; the rect is its size plus a 1 px margin. Key look, cool, outline_c, outline_a on the original's beats.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(26.0, 40.0);
uniform sampler2D tex : filter_nearest, repeat_disable;
uniform float look = 0.0;
uniform float cool = 0.0;
uniform vec4 reds[7];
uniform vec4 wash : source_color = vec4(1.0);
uniform vec4 outline_c : source_color = vec4(1.0);
uniform float outline_a = 0.0;

bool solid(ivec2 p, ivec2 ts) {
	return p.x >= 0 && p.y >= 0 && p.x < ts.x && p.y < ts.y && texelFetch(tex, p, 0).a > 0.5;
}

void fragment() {
	ivec2 ts = textureSize(tex, 0);
	ivec2 p = ivec2(floor(UV * size)) - ivec2(1);
	int lk = int(look + 0.5);
	vec4 c;
	if (solid(p, ts)) {
		vec3 px = texelFetch(tex, p, 0).rgb;
		if (lk == 0) {
			discard;
		} else if (lk == 1) {
			c = vec4(1.0);
		} else if (lk == 2) {
			float l = dot(px, vec3(0.299, 0.587, 0.114));
			c = vec4(reds[int(clamp(floor(2.0 + l * 5.0 + 0.5), 2.0, 6.0))].rgb, 1.0);
		} else {
			c = vec4(mix(px, mix(px, wash.rgb, 0.55), cool), 1.0);
		}
	} else if (outline_a > 0.0 && (solid(p + ivec2(1, 0), ts) || solid(p - ivec2(1, 0), ts) || solid(p + ivec2(0, 1), ts) || solid(p - ivec2(0, 1), ts))) {
		if (outline_a < pfx_threshold(FRAGCOORD.xy)) {
			discard;
		}
		c = vec4(outline_c.rgb, 1.0);
	} else {
		discard;
	}
	COLOR = c * vec4(1.0, 1.0, 1.0, COLOR.a);
}
