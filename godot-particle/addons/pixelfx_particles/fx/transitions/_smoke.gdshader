// burn-away's smoke (translucent): frame-table particles (fx/pickups/_ftp.gdshader), each one of the original's smoke
// puffs as its drawSmoke() draws it: three soft discs (a body, a denser core sitting low, a lit cap while young),
// shaded by the firelight at that moment. `data`, 4 rows a frame: row 0 (cell x, cell y, -, -), row 1 (colour rgb,
// present), row 2 (x, y in the cell, r, a), row 3 (cap colour rgb, cap alpha).
shader_type canvas_item;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float quad = 9.0;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

vec4 over(vec4 dst, vec3 c, float a) {
	if (a <= 0.004) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	float k = a / oa;
	return vec4(c * k + dst.rgb * (1.0 - k), oa);
}

bool in_disc(vec2 o, vec2 c, float r) {
	if (r < 0.5) {
		return all(equal(floor(o), floor(c)));
	}
	vec2 v = o + 0.5 - c;
	return dot(v, v) <= r * r;
}

void fragment() {
	int i = int(cu.x + 0.5);
	int f = int(cu.y + 0.5);
	vec4 r1 = texelFetch(data, ivec2(i, f * 4 + 1), 0);
	vec4 r2 = texelFetch(data, ivec2(i, f * 4 + 2), 0);
	vec4 r3 = texelFetch(data, ivec2(i, f * 4 + 3), 0);
	// this pixel's cell from the puff's cell; the puff's centre within it
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec2 p = r2.xy;
	float r = r2.z;
	float a = r2.w;
	vec4 c = vec4(0.0);
	if (in_disc(d, p, r)) {
		c = over(c, r1.rgb, a * 0.45);
	}
	if (in_disc(d, p + vec2(r * 0.05, r * 0.06), r * 0.74)) {
		c = over(c, r1.rgb, a * 0.62);
	}
	if (r3.w > 0.0 && in_disc(d, p + vec2(-r * 0.22, -r * 0.3), r * 0.5)) {
		c = over(c, r3.rgb, r3.w);
	}
	if (c.a <= 0.004) {
		discard;
	}
	COLOR = c;
}
