// holy/resurrection: the wings light the character from behind (light layer): the 1 px ring just outside its
// silhouette (`tex`, feet at the origin, centred), above y = -8, gets `color` at `k`.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(28.0, 42.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.0;
uniform float strength = 1.0;

float at(ivec2 q) {
	ivec2 ts = textureSize(tex, 0);
	if (q.x < 0 || q.y < 0 || q.x >= ts.x || q.y >= ts.y) {
		return 0.0;
	}
	return texelFetch(tex, q, 0).a;
}

void fragment() {
	vec2 cell = floor(floor((UV - 0.5) * size) + 0.5 + center);
	ivec2 ts = textureSize(tex, 0);
	ivec2 q = ivec2(cell) + ivec2(ts.x / 2, ts.y);
	bool rim = at(q) < 0.5 && (at(q + ivec2(1, 0)) >= 0.5 || at(q - ivec2(1, 0)) >= 0.5 || at(q + ivec2(0, 1)) >= 0.5 || at(q - ivec2(0, 1)) >= 0.5);
	if (!rim || cell.y >= -8.0 || k <= 0.0) {
		discard;
	}
	COLOR = vec4(color.rgb * k * strength, 1.0);
}
