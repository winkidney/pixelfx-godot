// weather/shooting-stars' milky band's light (_milky.gdshader).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 K[5] : source_color;
uniform float strength = 1.0;
uniform float t = 0.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = abs((p.y + 110.0) - (p.x * -0.32)) / 36.0;
	float k = d < 1.0 && p.y < 0.0 ? (1.0 - d) * (1.0 - d) : 0.0;
	COLOR = vec4(K[2].rgb * 0.1 * k * strength, 1.0);
}
