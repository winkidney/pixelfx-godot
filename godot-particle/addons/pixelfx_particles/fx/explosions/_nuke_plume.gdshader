// The rolling fireball of explosions/nuke (the original's _lib.js Plume): lobes ride a vortex ring that
// climbs, swells and rolls, each lobe a ball lit from the sky that burns in its heart and cools into smoke glowing
// from below, then thins away. The lobes (their place on the ring, size, heat offset...) are a data texture made by
// the build script; everything else follows from the plume's own clock `pt`, keyed by the animation. Each pixel
// takes the two nearest lobes covering it, the front one over the one behind. Soft colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(256.0);
uniform vec2 center = vec2(0.0);
uniform float pt = 0.0;
// per lobe, 3 texels: (th, ph, j, s), (h, dx, dy, f), (gv, 0, 0, 0)
uniform sampler2D lobes : filter_nearest, repeat_disable;
uniform int count = 42;
uniform vec2 at = vec2(0.0, -34.0);
uniform float rise = 118.0;
uniform float tau = 1.25;
uniform float drift = 4.0;
uniform vec2 tube = vec2(9.0, 21.0);
uniform vec2 ring = vec2(2.0, 19.0);
uniform float grow = 1.0;
uniform float swell = 0.9;
uniform float spin = 2.6;
uniform float spin_tau = 1.7;
uniform float heat = 1.2;
uniform float cool = 0.42;
uniform float under = 0.5;
uniform float tilt = 0.22;
uniform float squash = 0.72;
uniform vec2 fade = vec2(4.4, 6.4);
uniform float spread = 22.0;
uniform float glow_k = 1.0;
uniform float style = 0.0;
uniform bool inner = false;
uniform bool hollow = false;
uniform vec4 fr[9] : source_color;
uniform vec4 sm[5] : source_color;
uniform float alpha = 1.0;

struct Lobe {
	vec2 p;
	float r;
	float z;
	float up;
	float heat;
	float fade;
	float d;
	float c;
	float gv;
};

float smooth_(float e0, float e1, float x) {
	float u = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

vec4 S_() {
	float u = max(0.0, pt);
	float g = 1.0 - exp(-u / grow);
	return vec4(at.y - rise * (1.0 - exp(-u / tau)) - drift * u, tube.x + (tube.y - tube.x) * g, ring.x + (ring.y - ring.x) * g, g);
}

Lobe lobe_at(int i, vec4 S) {
	vec4 a = texelFetch(lobes, ivec2(i, 0), 0);
	vec4 b = texelFetch(lobes, ivec2(i, 1), 0);
	vec4 e = texelFetch(lobes, ivec2(i, 2), 0);
	Lobe L;
	float t = pt;
	float roll = spin * (0.12 * t + 0.88 * spin_tau * (1.0 - exp(-t / spin_tau)));
	float base = heat - cool * t;
	float span = max(S.z + S.y, 0.001);
	L.fade = 1.0 - smooth_(fade.x + b.w, fade.y + b.w * 0.5, t);
	float loose = pow(smooth_(fade.x - 1.8 + b.w, fade.y, t), 1.5) * spread;
	float th = a.x - roll;
	float rt = S.y * (1.0 + a.z);
	float rho = S.z + rt * cos(th);
	L.up = sin(th);
	float X = rho * cos(a.y);
	float Z = rho * sin(a.y);
	L.heat = base + b.x - 0.18 * max(0.0, cos(th)) * clamp(t * 2.0, 0.0, 1.0) + under * max(0.0, -L.up) * clamp(base + 0.6, 0.0, 1.0);
	L.r = a.w * (0.5 + 0.5 * S.w) * (1.0 + swell * clamp(1.0 - L.heat, 0.0, 1.0)) * (1.0 + 0.35 * (1.0 - L.fade));
	L.p = vec2(at.x + X + b.y * loose, S.x - rt * L.up * squash + Z * tilt + b.z * loose);
	L.z = Z / span;
	L.d = length(vec2(X, Z)) / span;
	L.c = 1.0 - min(1.0, abs(X) / span);
	L.gv = e.x;
	return L;
}

vec4 D(int i, int back, int dark) {
	return sm[min(4, i + back + dark)];
}

// one lobe's colour and opacity at q (the original's lobe())
vec4 shade(Lobe L, vec2 q, vec4 S) {
	float t = pt;
	float base = heat - cool * t;
	float Em = clamp((heat - cool * t + 1.0) / 1.1, 0.0, 1.0);
	float reach = 0.3 + 1.15 * Em;
	float age = clamp(t / fade.y, 0.0, 1.0);
	float fire = clamp((L.heat - 0.2) / 0.75, 0.0, 1.0);
	float glow = inner
		? Em * clamp((reach - L.d) / 0.45, 0.0, 1.0) * (0.45 + 0.55 * max(0.0, -L.up)) * L.gv * glow_k
		: clamp((base + 0.45) / 0.85, 0.0, 1.0) * glow_k * (0.4 + 0.35 * max(0.0, -L.up) + 0.4 * L.c) * L.gv;
	float a = L.fade * (0.82 + 0.18 * fire);
	int dark = (age > 0.72 ? 1 : 0) + ((hollow && L.up < -0.35) ? 1 : 0);
	int back = L.z < -0.35 ? 1 : 0;
	float r = L.r;
	float rim = 1.0 - min(0.35, 1.6 / r);
	float seam = 1.0 - min(0.3, 1.3 / r);
	float soft = 0.55 + 0.4 * (1.0 - min(1.0, a));
	float dx = (q.x - L.p.x) / r;
	float dy = (q.y - L.p.y) / r;
	float d2 = dx * dx + dy * dy;
	float d = sqrt(d2);
	float nz = sqrt(max(0.0, 1.0 - d2));
	float sky = -0.5 * dx - 0.66 * dy + 0.56 * nz;
	float v = fire * (1.32 - 0.78 * d) + 0.14 * sky * fire;
	vec4 c;
	bool solid = false;
	if (v > 0.44) {
		int i = clamp(int(floor((1.3 - v) * 8.0 * 0.78)), 0, 6);
		if (d > seam) {
			i = clamp(i + 2, 4, 6);
		} else if (d > seam - 0.22) {
			i = min(6, i + 1);
		}
		c = fr[i];
		solid = true;
	} else if (style > 0.5) {
		float lam = -0.42 * dx - 0.78 * dy + 0.46 * nz;
		if (lam > 0.66 && d > 0.4) {
			c = D(0, back, dark);
		} else if (lam > 0.16) {
			c = D(1, back, dark);
		} else if (lam > -0.3) {
			c = D(2, back, dark);
		} else {
			c = D(lam < -0.64 ? 4 : 3, back, dark);
			float g = glow * (0.6 + 0.4 * dy);
			if (g > 0.55) {
				c = fr[g > 0.8 ? 5 : 6];
			} else if (g > 0.34) {
				c = mix(c, fr[6], 0.6);
			} else if (g > 0.16) {
				c = mix(c, fr[7], 0.45);
			}
		}
	} else {
		float g = glow * (0.82 * dy + 0.3 * nz);
		if (g > 0.45) {
			c = fr[g > 0.66 ? 4 : 5];
		} else if (g > 0.3) {
			c = fr[6];
		} else if (g > 0.2) {
			c = fr[7];
		} else {
			float s = sky * 0.5 + 0.5;
			c = D(s > 0.8 ? 0 : (s > 0.62 ? 1 : (s > 0.42 ? 2 : (s > 0.22 ? 3 : 4))), back, dark);
		}
	}
	return vec4(c.rgb, (solid || d <= rim) ? a : a * soft);
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 S = S_();
	int i1 = -1;
	int i2 = -1;
	float z1 = -1e9;
	float z2 = -1e9;
	for (int i = 0; i < count; i++) {
		Lobe L = lobe_at(i, S);
		if (L.fade <= 0.0 || L.r < 0.7) {
			continue;
		}
		vec2 dd = q - L.p;
		if (dot(dd, dd) > L.r * L.r) {
			continue;
		}
		if (L.z >= z1) {
			z2 = z1;
			i2 = i1;
			z1 = L.z;
			i1 = i;
		} else if (L.z >= z2) {
			z2 = L.z;
			i2 = i;
		}
	}
	if (i1 < 0) {
		discard;
	}
	vec4 f = shade(lobe_at(i1, S), q, S);
	vec4 c = f;
	if (i2 >= 0 && f.a < 0.999) {
		vec4 b = shade(lobe_at(i2, S), q, S);
		float a = f.a + b.a * (1.0 - f.a);
		c = vec4((f.rgb * f.a + b.rgb * b.a * (1.0 - f.a)) / max(a, 0.001), a);
	}
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
