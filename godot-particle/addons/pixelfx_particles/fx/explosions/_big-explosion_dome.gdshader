// Light hugging the upper half of a circle (explosions/big-explosion: the original's _lib.js glowDome, a ground blast's
// shock): a band `width` px either side of `radius`, falling off squared, nothing below the floor. Light layer.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 10.0;
uniform float width = 6.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (p.y + center.y > 0.5) {
		discard;
	}
	float d = abs(length(p) - radius) / width;
	float k = 1.0 - clamp(d, 0.0, 1.0);
	COLOR = vec4(color.rgb * k * k * alpha * strength, 1.0);
}
