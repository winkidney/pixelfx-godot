// The light layer of a pixelfx particle effect (the original's `light` buffer): added onto whatever is behind it, so
// glow brightens the scene. `strength` scales it (PfxEffect.light); `steps` > 0 quantises it into bands.
shader_type canvas_item;
render_mode blend_add;

uniform float strength = 1.0;
uniform float steps = 0.0;

void fragment() {
	vec3 c = COLOR.rgb * COLOR.a * strength;
	if (steps > 0.0) {
		c = floor(c * steps + 0.5) / steps;
	}
	COLOR = vec4(c, 1.0);
}
