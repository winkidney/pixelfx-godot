// The light-layer counterpart of ring.gdshader: an additive glow shaped as a disc or ring, soft at its edges.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform float radius = 10.0;
// 0: a soft disc fading out to `radius`; > 0: a band this wide centred on `radius`
uniform float thickness = 0.0;
uniform float squash = 1.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(vec2(p.x, p.y / max(squash, 0.001)));
	float k;
	if (thickness > 0.0) {
		k = 1.0 - clamp(abs(d - radius) / thickness, 0.0, 1.0);
	} else {
		k = 1.0 - clamp(d / max(radius, 0.001), 0.0, 1.0);
	}
	k = k * k;
	COLOR = vec4(color.rgb * color.a * k * alpha * strength, 1.0);
}
