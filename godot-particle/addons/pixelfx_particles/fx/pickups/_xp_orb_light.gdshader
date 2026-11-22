// xp-orb's light along the tail: a glow on every sixth of the tail's discs, shrinking and fading toward its end (the
// orb's own light, the pool and the flecks' are elsewhere). Light layer, `t` keyed to the reference's clock.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_xp_orb.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 glow_c : source_color = vec4(1.0);
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	float e = lt_edge(pc, canvas) * strength;
	vec3 l = vec3(0.0);
	for (int i = 6; i <= 60; i += 6) {
		float u = float(i) / 60.0;
		l += lt_glow(pc, orb_at(t - u * 0.48), 7.0 * (1.0 - u) + 2.0, glow_c.rgb, 0.24 * (1.0 - u) * e);
	}
	COLOR = vec4(min(l, vec3(1.0)), 1.0);
}
