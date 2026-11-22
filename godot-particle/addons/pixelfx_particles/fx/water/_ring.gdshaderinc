// The uniforms of the ripple ring (the original's water ring()), shared by _ring.gdshader (the crests, colour layer) and
// _ring_light.gdshader (the light the outer crest adds, light layer). See _ring.gdshader for the uniforms.
#include "res://addons/pixelfx_particles/fx/water/_ringfn.gdshaderinc"

uniform vec2 size = vec2(64.0);
// the ring's middle inside the rect (px from the rect's centre)
uniform vec2 offset = vec2(0.0);
uniform float r = 10.0;
uniform float sy = 0.26;
uniform float k = 1.0;
uniform float n = 2.0;
uniform float gap = 3.0;
uniform float side = 0.0;
uniform float hot = 0.0;
uniform float glint = 0.0;
uniform float seed = 1.0;
uniform float wob = 0.0;

// true when pixel p (px from the ring's middle) is on a crest: its colour, how lit it is, which crest (j)
bool ring_px(vec2 p, out vec4 c, out float lit, out int crest) {
	return ring_hit(p, r, sy, k, n, gap, side, hot > 0.5, glint, seed, wob, c, lit, crest);
}
