// The dome's glitter (shield-block): every sixteenth pixel of its face gives off a little light, more where the
// ripples pass. The light-layer half of _dome.gdshader.
shader_type canvas_item;
render_mode blend_add;

#include "_dome.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float fade = 1.0 - smoothstep(gone + 0.35, gone + 0.55, t);
	float q;
	float z;
	float lon;
	float lat;
	bool line;
	float cgone;
	float hit;
	if (fade <= 0.0 || !dome_at(cell, 0.0, q, z, lon, lat, line, cgone, hit)) {
		discard;
	}
	if (((int(cell.x) * 7 + int(cell.y) * 3) & 15) != 0) {
		discard;
	}
	COLOR = vec4(color.rgb * (0.15 + 0.5 * hit) * strength * COLOR.a, 1.0);
}
