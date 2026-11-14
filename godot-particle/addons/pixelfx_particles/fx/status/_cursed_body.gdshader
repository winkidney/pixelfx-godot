// status/cursed's stain on the stand-in (the Actor): everything below the creeping line drowned in violet (c1 to c3
// by the pixel's own brightness), the line itself burning (c6 over c4). `levels` holds how high the stain has crept
// at each column (x) on each frame (y), 0 at the feet, 1 at the head; `frame` picks the row (keyed). Exact colours.
shader_type canvas_item;

uniform sampler2D levels : filter_nearest;
uniform float frame = 0.0;
uniform vec4 c1 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c6 : source_color;

void fragment() {
	vec4 c = COLOR;
	if (c.a < 0.5) {
		discard;
	}
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 P = ivec2(floor(UV * vec2(sz)));
	float up = 1.0 - (float(P.y) + 0.5) / float(sz.y);
	float lv = texelFetch(levels, ivec2(P.x, int(frame + 0.5)), 0).r;
	vec3 o = c.rgb;
	if (up <= lv + 0.035) {
		if (up > lv - 0.02) {
			o = c6.rgb;
		} else if (up > lv - 0.06) {
			o = c4.rgb;
		} else {
			o = mix(c1.rgb, c3.rgb, clamp(dot(c.rgb, vec3(0.299, 0.587, 0.114)) * 1.6, 0.0, 1.0));
		}
	}
	COLOR = vec4(o, 1.0);
}
