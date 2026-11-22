// A particle's glow (melee/_kinds.gdshader part 2), light layer: the original's p.glow() over the particle's quad (2 r
// across): colour * alpha * (1 - d / r)^2, added.
shader_type canvas_item;
render_mode blend_add;

uniform float strength = 1.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float f = max(0.0, 1.0 - d);
	COLOR = vec4(COLOR.rgb * COLOR.a * f * f * strength, 1.0);
}
