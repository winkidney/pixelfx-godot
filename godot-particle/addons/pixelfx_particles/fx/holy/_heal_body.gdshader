// The stand-in while it is healed (holy/heal): drained of colour above the hoop's line `line_y` (px from the feet),
// white then cream on the line, restored below it with a warm glow that falls off; once `done`, a warm wash `wash`
// that fades. Rows come from the sprite's own vertices.
shader_type canvas_item;

uniform float line_y = 1.0;
uniform float drain = 0.0;
uniform bool done = false;
uniform float wash = 0.0;
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	if (c.a < 0.5) {
		discard;
	}
	float d = floor(lp.y) - line_y;
	vec3 o = c.rgb;
	if (!done && d < -0.5) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * 0.88;
		o = mix(c.rgb, vec3(l * 236.0, l * 226.0, l * 222.0) / 255.0, 0.68 * drain);
	} else if (!done && d < 1.0) {
		o = vec3(1.0);
	} else if (!done && d < 2.5) {
		o = c6.rgb;
	} else {
		float k = done ? wash : 0.5 * exp(-(d - 2.5) / 5.0);
		if (k > 0.05) {
			o = mix(c.rgb, c5.rgb, k);
		}
	}
	COLOR = vec4(o, 1.0);
}
