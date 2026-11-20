// shatter-wipe.js draw() before the burst: the dark glass pane dropping in (its bottom row r1), its reflections (shine,
// y0: the pane's top), its lit bevel and the glint running along its edge (gx), and the cracks racing out from the
// impact. Every crack pixel's writes (the original's crack list, sorted by when they're reached) are listed per pixel
// at build time: `cpix` holds each pixel's first entry and count in `clist`, an entry its time (negative: the
// crack's shadow, one pixel down-right). wbeat > 0: the beat before the burst when every crack flares white.
uniform float t = 0.0;
uniform float r1 = 0.0;
uniform float shine = 0.0;
uniform float gx = 0.0;
uniform float y0 = 0.0;
uniform float wbeat = 0.0;
uniform float cracks_on = 0.0;
uniform float pass = 0.0;
uniform sampler2D cpix : filter_nearest, repeat_disable;
uniform sampler2D clist : filter_nearest, repeat_disable;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

float pn_entry(int i) {
	return texelFetch(clist, ivec2(i % 4096, i / 4096), 0).r;
}
