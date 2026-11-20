// Shared by _shard.gdshader and _shard_light.gdshader: one shard's corners on screen (shatter-wipe.js drawShard).
uniform sampler2D data : filter_nearest, repeat_disable;
uniform sampler2D shape : filter_nearest, repeat_disable;
uniform sampler2D info : filter_nearest, repeat_disable;
uniform float quad = 9.0;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const vec2 LXY = vec2(-0.6, -0.8);
const vec3 L3 = vec3(-0.42, -0.56, 0.71);

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

struct Sh {
	int id;
	int n;
	float r;
	bool still;
	vec2 c;
	float cp;
	float sp;
	float ci;
	float si;
	float ca;
	float sa;
	float k;
	vec3 face;
	bool sliver;
	float gl;
	float sg;
};

vec2 sh_pt(Sh s, int i) {
	vec2 l = texelFetch(shape, ivec2(i, s.id), 0).xy;
	if (s.still) {
		return s.c + l;
	}
	float u = l.x * s.ci + l.y * s.si;
	float v = (-l.x * s.si + l.y * s.ci) * s.cp;
	float qx = u * s.ci - v * s.si;
	float qy = u * s.si + v * s.ci;
	return s.c + vec2(qx * s.ca - qy * s.sa, qx * s.sa + qy * s.ca) * s.k;
}

Sh sh_load() {
	int i = int(cu.x + 0.5);
	int f = int(cu.y + 0.5);
	vec4 r0 = texelFetch(data, ivec2(i, f * 4), 0);
	vec4 r1 = texelFetch(data, ivec2(i, f * 4 + 1), 0);
	vec4 r2 = texelFetch(data, ivec2(i, f * 4 + 2), 0);
	Sh s;
	s.id = int(r0.z + 0.5);
	vec4 inf = texelFetch(info, ivec2(s.id, 0), 0);
	s.n = int(inf.x + 0.5);
	s.r = inf.y;
	s.still = r0.w > 0.5;
	s.c = r2.xy;
	s.cp = cos(r1.x);
	s.sp = sin(r1.x);
	s.ci = cos(r1.y);
	s.si = sin(r1.y);
	s.ca = cos(r2.z);
	s.sa = sin(r2.z);
	s.k = 1.0 / (1.0 + r2.w);
	s.face = ink.rgb;
	s.sliver = false;
	s.gl = 0.0;
	if (!s.still) {
		// the face's normal, turned by the tumble and the spin, against the light
		float nx0 = s.si * s.sp;
		float ny0 = -s.ci * s.sp;
		float nx = nx0 * s.ca - ny0 * s.sa;
		float ny = nx0 * s.sa + ny0 * s.ca;
		float dd = abs(nx * L3.x + ny * L3.y + s.cp * L3.z);
		s.gl = pow(dd, 6.0);
		float graze = pow(clamp(1.0 - abs(s.cp) / 0.3, 0.0, 1.0), 2.0);
		s.face = js_mix(js_mix(ink.rgb, C[2].rgb, 0.12 + 0.4 * s.gl), C[3].rgb, 0.55 * graze);
		s.sliver = abs(s.cp) < 0.2;
		if (abs(s.cp) * s.r < 1.5) {
			s.face = C[5].rgb;
		}
	}
	float a2 = 0.0;
	for (int k = 0; k < 64; k++) {
		if (k >= s.n) {
			break;
		}
		vec2 p = sh_pt(s, k);
		vec2 o = sh_pt(s, k == 0 ? s.n - 1 : k - 1);
		a2 += o.x * p.y - p.x * o.y;
	}
	s.sg = a2 > 0.0 ? 1.0 : -1.0;
	return s;
}

// _lib.js fillConvex(): the row's leftmost and rightmost crossing
bool sh_fill(Sh s, vec2 q) {
	float yc = q.y + 0.5;
	float xl = 1e9;
	float xr = -1e9;
	for (int k = 0; k < 64; k++) {
		if (k >= s.n) {
			break;
		}
		vec2 a = sh_pt(s, k);
		vec2 b = sh_pt(s, k == 0 ? s.n - 1 : k - 1);
		if ((a.y > yc) == (b.y > yc)) {
			continue;
		}
		float x = a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y);
		xl = min(xl, x);
		xr = max(xr, x);
	}
	return q.x >= max(0.0, ceil(xl - 0.5)) && q.x <= min(TR_W - 1.0, floor(xr - 0.5));
}

bool sh_on_line(vec2 q, vec2 a, vec2 b) {
	vec2 ca = floor(a);
	vec2 cb = floor(b);
	if (q.x < min(ca.x, cb.x) || q.x > max(ca.x, cb.x) || q.y < min(ca.y, cb.y) || q.y > max(ca.y, cb.y)) {
		return false;
	}
	float n;
	return tr_line_step(q, ca, cb, n) >= 0;
}

// the edges: the colour index (8 white) of the last line that lands on q, or -1
int sh_edges(Sh s, vec2 q) {
	int res = -1;
	for (int k = 0; k < 64; k++) {
		if (k >= s.n) {
			break;
		}
		vec2 a = sh_pt(s, k == 0 ? s.n - 1 : k - 1);
		vec2 b = sh_pt(s, k);
		vec2 dv = b - a;
		float L = length(dv);
		if (L < 0.5) {
			continue;
		}
		vec2 m = vec2(dv.y / L, -dv.x / L) * s.sg;
		float el = dot(m, LXY);
		if (s.still) {
			if (sh_on_line(q, a, b)) {
				res = el > 0.0 ? 5 : 4;
			}
			continue;
		}
		if (el > 0.2 || s.sliver) {
			if (sh_on_line(q, a - m, b - m)) {
				res = 4;
			}
			if (sh_on_line(q, a, b)) {
				res = (s.gl > 0.5 || s.sliver) ? 8 : 6;
			}
		} else if (sh_on_line(q, a, b)) {
			res = el > -0.3 ? 4 : 2;
		}
	}
	return res;
}

vec3 sh_light(Sh s, vec2 pc) {
	vec3 l = vec3(0.0);
	if (s.still) {
		return l;
	}
	for (int k = 0; k < 64; k++) {
		if (k >= s.n) {
			break;
		}
		vec2 a = sh_pt(s, k == 0 ? s.n - 1 : k - 1);
		vec2 b = sh_pt(s, k);
		vec2 dv = b - a;
		float L = length(dv);
		if (L < 0.5) {
			continue;
		}
		vec2 m = vec2(dv.y / L, -dv.x / L) * s.sg;
		if (dot(m, LXY) > 0.2 || s.sliver) {
			l += lt_glow(pc, (a + b) / 2.0, min(12.0, 4.0 + L * 0.3), C[5].rgb, 0.12 + 0.3 * s.gl);
		}
	}
	return l;
}
