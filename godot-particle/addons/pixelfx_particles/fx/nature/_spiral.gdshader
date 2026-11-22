// A particle process shader for things carried round a whirl seen from the side (leaf storm, tornado): each particle
// rides a squashed spiral the original lays out (its angle turning, its height rising, its radius following the
// whirl), tumbling and flipping, and only shows while it is on this emitter's side (two emitters with the same
// settings, one behind and one in front, split every particle between them). Particle i's numbers come from its
// index, so each slot repeats exactly every lifetime (= the loop). Its own life (life_min..life_max) can be shorter;
// it's hidden after. Its age is counted in CUSTOM.y from DELTA (no clock). The draw material is the usual dither.
//   mode 0: leaf storm leaves      1: leaf storm litter swirled at the feet (soft discs)
//   mode 2: tornado debris          3: tornado dust at its foot (soft discs)      4: tornado grit hopping
shader_type particles;
render_mode disable_velocity, disable_force;

uniform int mode = 0;
// 1: shown while sin(angle) > 0 (the near side, in front), -1: the far side, 0: always
uniform float side = 1.0;
uniform float seed = 0.0;
uniform float life_min = 1.0;
uniform float life_max = 1.0;
// the texture's own size: leaves (length, width), discs (radius)
uniform vec2 tex_size = vec2(8.0, 2.8);
uniform vec2 len_range = vec2(6.5, 9.0);
uniform vec2 wid_range = vec2(2.4, 3.3);
// the tornado's phase over its loop (keyed 0 -> 1), for its snaking axis
uniform float t = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
// > 0: this emitter draws only the glint of a leaf turning face on to the light (|cos flip| > 0.97), at this scale
uniform float glint = 0.0;
// 0: no flipping and an even scale len / tex_size.x (twigs, pebbles)
uniform float flip = 1.0;
// a second disc of a puff: offset (x, y, in units of its size), scale and alpha against the first
uniform vec4 sub = vec4(0.0, 0.0, 1.0, 1.0);


float rnd(float i, float k) {
	return fract(sin(i * 12.9898 + k * 78.233 + seed * 37.719) * 43758.5453);
}

float rr_(float i, float k, float a, float b) {
	return a + (b - a) * rnd(i, k);
}

float smooth_(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float ax(float u) {
	float ph = TAU * t;
	return 8.5 * sin(ph - 2.6 * u) * (0.2 + 0.8 * u) + 3.0 * sin(2.0 * ph + 1.3 - 4.5 * u) * u;
}

float rad(float u) {
	float f = smooth_(0.78, 1.0, u);
	return 3.0 + 20.0 * pow(u, 1.5) + 17.0 * f * f;
}

void place(inout mat4 tr, inout vec4 col, float age, float i) {
	float life = rr_(i, 1.0, life_min, life_max);
	float k = age / life;
	vec2 pos = vec2(0.0);
	float ang = 0.0;
	vec2 sc = vec2(1.0);
	float a = 1.0;
	float sn = 0.0;
	if (mode == 0) {
		float turns = rr_(i, 2.0, 1.4, 2.2);
		float th = rr_(i, 3.0, 0.0, TAU) + turns * TAU * k;
		sn = sin(th);
		float y = -mix(1.0, 64.0, pow(clamp(k, 0.0, 1.0), 0.9)) - rr_(i, 4.0, 0.0, 6.0);
		float fling = smooth_(0.75, 1.0, k);
		float r = (15.0 + 9.0 * clamp(-y / 64.0, 0.0, 1.0)) * rr_(i, 5.0, 0.85, 1.15) + fling * 22.0;
		pos = vec2(cos(th) * r, y + sn * r * 0.3);
		a = min(1.0, k * 7.0) * (1.0 - smooth_(0.85, 1.0, k));
		ang = rr_(i, 6.0, -9.0, 9.0) * age + th;
		float fl = age * rr_(i, 7.0, 5.0, 11.0);
		float cf = cos(fl);
		sc = vec2(rr_(i, 8.0, len_range.x, len_range.y) / tex_size.x,
			sign(cf) * max(0.2, abs(cf)) * rr_(i, 9.0, wid_range.x, wid_range.y) / tex_size.y);
		if (glint > 0.0) {
			sc = abs(cf) > 0.97 ? vec2(glint) : vec2(0.0);
			ang = 0.0;
		}
	} else if (mode == 1) {
		float th = rr_(i, 2.0, 0.0, TAU) + rr_(i, 3.0, 6.0, 9.0) * age;
		sn = sin(th);
		float r = rr_(i, 4.0, 10.0, 22.0) + k * 8.0;
		pos = vec2(cos(th) * r, -1.0 - k * rr_(i, 5.0, 2.0, 8.0) + sn * r * 0.25);
		float s = rr_(i, 6.0, 2.0, 3.5) * (0.6 + k);
		sc = vec2(s / tex_size.x);
		a = (1.0 - k) * min(1.0, k * 6.0) * 0.3;
	} else if (mode == 2) {
		float sk = rr_(i, 2.0, 0.15, 0.3);
		float q = clamp((k - sk) / (1.0 - sk), 0.0, 1.0);
		float u = mix(0.03, 0.98, pow(q, 0.85));
		float th = rr_(i, 3.0, 0.0, TAU) + rr_(i, 4.0, 2.0, 3.2) * TAU * k;
		sn = sin(th);
		float fling = smooth_(0.78, 1.0, q);
		float inward = 1.0 - smooth_(0.0, sk, k);
		float far = rr_(i, 5.0, 26.0, 44.0);
		float r = mix(min(68.0, rad(u) * (1.12 + fling * 1.1) + rr_(i, 6.0, 2.0, 7.0)), far, inward);
		pos = vec2(ax(u) + r * cos(th), min(-1.0, -u * 112.0 + r * 0.28 * sn - fling * 8.0));
		a = min(1.0, k * 8.0) * (1.0 - smooth_(0.85, 1.0, k));
		ang = rr_(i, 7.0, -14.0, 14.0) * age;
		float fl = age * rr_(i, 8.0, 5.0, 10.0);
		float cf = cos(fl);
		sc = vec2(rr_(i, 9.0, len_range.x, len_range.y) / tex_size.x,
			sign(cf) * max(0.2, abs(cf)) * rr_(i, 10.0, wid_range.x, wid_range.y) / tex_size.y);
		if (flip < 0.5) {
			sc = vec2(sc.x);
		}
	} else if (mode == 3) {
		float th = rr_(i, 2.0, 0.0, TAU) + rr_(i, 3.0, 5.0, 9.0) * age;
		sn = sin(th);
		float r = 4.0 + k * rr_(i, 4.0, 14.0, 28.0);
		float s = rr_(i, 5.0, 3.0, 6.0) * (0.6 + 0.8 * k);
		pos = vec2(ax(0.0) + r * cos(th), -1.5 - k * rr_(i, 6.0, 4.0, 16.0) + r * 0.3 * sn + s * 0.2) + sub.xy * s;
		sc = vec2(s * sub.z / tex_size.x);
		a = min(1.0, k * 6.0) * (1.0 - k) * 0.6 * sub.w;
	} else {
		float th = rr_(i, 2.0, 0.0, TAU);
		float v = rr_(i, 3.0, 25.0, 55.0);
		float y = sin(th) * 2.0 - rr_(i, 4.0, 40.0, 80.0) * age + 260.0 * age * age;
		pos = vec2(ax(0.0) + cos(th) * (4.0 + v * age), min(0.0, y));
		a = y < 0.5 ? 1.0 - k : 0.0;
		sn = side;
	}
	bool shown = k < 1.0 && a > 0.004 && (side == 0.0 || (side > 0.0 ? sn > 0.0 : sn <= 0.0));
	if (!shown) {
		sc = vec2(0.0);
		a = 0.0;
	}
	float ca = cos(ang);
	float sa = sin(ang);
	tr = mat4(vec4(ca * sc.x, sa * sc.x, 0.0, 0.0), vec4(-sa * sc.y, ca * sc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0),
		vec4(pos, 0.0, 1.0));
	col = vec4(tint.rgb, tint.a * clamp(a, 0.0, 1.0));
}

void start() {
	CUSTOM = vec4(0.0);
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, 0.0, float(INDEX));
}

void process() {
	CUSTOM.y += DELTA;
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, CUSTOM.y, float(INDEX));
}
