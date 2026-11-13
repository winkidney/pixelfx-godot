// The stand-in character, as an effect sees it: its own pixels, flashed toward `flash_color` by `flash` (a hit, a
// flare) and washed toward `tint_color` by `tint` (frozen blue, poisoned green, petrified grey), keeping its shading.
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (c.a < 0.5) {
		discard;
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(c.rgb, tint_color.rgb * (0.45 + lum), tint);
	COLOR = vec4(mix(tinted, flash_color.rgb, flash), 1.0);
}
