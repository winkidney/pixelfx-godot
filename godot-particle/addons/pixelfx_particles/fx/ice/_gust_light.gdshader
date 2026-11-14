// The light of ice/frost-breath's gust (_gust.gdshader, same uniforms): where the cold air is dense it glows,
// brighter where denser. Light layer (additive).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform float reach = 170.0;
uniform float spread = 0.23;
uniform float sag = 7.0;
uniform vec2 period = vec2(182.0, 68.0);
uniform float contrast = 1.0;
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

float density(vec2 p) {
	float u = p.x / reach;
	float hw = 2.5 + p.x * spread;
	float yc = sag * u * u;
	float v = (p.y - yc) / hw;
	if (v * v >= 1.0 || u >= 1.0 || p.x < 2.0) {
		return 0.0;
	}
	vec2 q = vec2(p.x / period.x - t, (p.y - yc) / period.y + 0.37);
	float n = (texture(noise, q).r * 0.65 + texture(noise, q * 2.0 + vec2(0.31, 0.17)).r * 0.35 - 0.5) * 2.0 * contrast;
	float edge = (1.0 - v * v) * (u < 0.08 ? u / 0.08 : 1.0) * pow(1.0 - u, 0.8);
	return clamp(0.5 + n * 1.3 + (1.0 - abs(v)) * 0.35 * pow(1.0 - u, 1.5), 0.0, 1.0) * edge;
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = density(p);
	vec3 c = vec3(0.0);
	if (d > 0.3) {
		c = (d > 0.6 ? c6.rgb : c5.rgb) * 0.2 * d;
	}
	COLOR = vec4((c * alpha * strength) * tint.rgb * tint.a, 1.0);
}
