// The hex sigil's strokes in the flare: light off every third half-pixel of the traced lines (the data box's alpha:
// how much light each pixel gathers). Light layer; shown only while the sigil is white.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform sampler2D data : filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float strength = 1.0;

void fragment() {
	ivec2 q = ivec2(floor(UV * size));
	float k = texelFetch(data, q, 0).a;
	COLOR = vec4(color.rgb * k * 2.0 * alpha * strength, 1.0);
}
