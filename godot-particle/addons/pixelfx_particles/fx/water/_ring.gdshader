// A ripple on water seen at a low angle (the original's water ring()): a train of `n` 1 px crests `gap` px apart,
// squashed by `sy`, the outer one brightest. `k` is its strength: a crisp crest stepping down the ramp as it falls,
// breaking into dashes fixed to the ring only at the very end. `side` -1 draws the far half, 1 the near half, 0 both;
// `hot` whitens the near outer crest; `glint` puts a white catch-light on the near side; `wob` px lets the crest
// wander in and out so it isn't a perfect ellipse. Key r, k, gap, hot, glint and wob from the build script.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_ring.gdshaderinc"

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 - offset;
	vec4 c;
	float lit;
	int crest;
	if (!ring_px(p, c, lit, crest)) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
