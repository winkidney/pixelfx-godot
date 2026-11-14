// status/frozen's chilled body, on the stand-in pixel for pixel (the Actor's own Sprite2D): each pixel pulled toward
// the ice ramp by its own brightness, the dark rim frosted and lit (pale on the upper half and the left, deeper
// below), and frost ferns creeping in from the outline (`ferns`: r = when the pixel grows, 0..1, 1 for none; g = 1
// for the paler of its two colours), shown where that is under `grow`, white at the growing front.
// Keyed: grow. The colours are the original's mixes, exact (no palette snap), as the stand-in's own are.
shader_type canvas_item;

uniform vec4 ramp[8] : source_color;
uniform sampler2D ferns : filter_nearest;
uniform float grow = 0.2;

void fragment() {
	// COLOR already holds the texture (Godot 4); sampling TEXTURE again for it would square the colours
	vec4 c = COLOR;
	if (c.a < 0.5) {
		discard;
	}
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 P = ivec2(floor(UV * vec2(sz)));
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// neighbours off the texture are empty (texelFetch out of range is undefined)
	bool open_left = P.x == 0 || texelFetch(TEXTURE, P + ivec2(-1, 0), 0).a < 0.5;
	bool open_up = P.y == 0 || texelFetch(TEXTURE, P + ivec2(0, -1), 0).a < 0.5;
	bool open_right = P.x == sz.x - 1 || texelFetch(TEXTURE, P + ivec2(1, 0), 0).a < 0.5;
	bool rim = open_left || open_up || open_right;
	vec3 o;
	if (rim && l < 0.3) {
		o = (float(P.y) < float(sz.y) * 0.5 || open_left) ? ramp[5].rgb : ramp[3].rgb;
	} else {
		int i = clamp(1 + int(floor(l * 5.6 + 0.5)), 1, 7);
		o = mix(c.rgb, ramp[i].rgb, 0.38);
	}
	vec4 f = texelFetch(ferns, P, 0);
	if (f.r < grow) {
		o = f.r > grow - 0.1 ? vec3(1.0) : (f.g > 0.5 ? ramp[6].rgb : ramp[5].rgb);
	}
	COLOR = vec4(o, 1.0);
}
