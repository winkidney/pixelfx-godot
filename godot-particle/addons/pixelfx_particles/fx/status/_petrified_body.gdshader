// status/petrified's statue over the stand-in (the Actor): a pixel turns to its stone colour (`stone`, the original's
// shading walked down a grey ramp, grained, lit top-left) once the creeping front (`level` plus a little noise per
// column, `wobble`) has passed it; while it creeps (`creeping`) the edge crackles c7 / c6 (re-rolled with `flick`)
// with a c5 band under it. `white` paints the whole statue white (the frame before it bursts). Above the front the
// stand-in shows as itself. Keyed: level, creeping, flick, white. Exact colours.
shader_type canvas_item;

uniform sampler2D stone : filter_nearest;
uniform float wobble[24];
uniform float level = 0.0;
uniform bool creeping = true;
uniform float flick = 0.0;
uniform bool white = false;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 c7 : source_color;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec4 c = COLOR;
	if (c.a < 0.5) {
		discard;
	}
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 P = ivec2(floor(UV * vec2(sz)));
	float up = 1.0 - (float(P.y) + 0.5) / float(sz.y);
	float d = level + wobble[clamp(P.x, 0, 23)] - up;
	vec3 o = c.rgb;
	if (d >= 0.0) {
		if (creeping && d < 0.035) {
			o = hash(vec3(vec2(P), flick)) < 0.5 ? c7.rgb : c6.rgb;
		} else if (creeping && d < 0.07) {
			o = c5.rgb;
		} else {
			o = white ? vec3(1.0) : texelFetch(stone, P, 0).rgb;
		}
	}
	COLOR = vec4(o, 1.0);
}
