// Shared by the force field's shaders (src/fx/scifi/force-field.js): the dome's shell, worked out once per pixel at
// build time from the original's own shell() (where each pixel sits on the sphere and on the hex plates, whether
// it's a seam or a plate's lit edge, when its plate glints: `near` / `far`, three blocks of rows), and per frame from
// the keyed clock `t`: the ripples racing out from each hit, the struck plates' heat, the glints, the scan band.
// Declare `t`, `near`, `far` and `pal` first.

const float D = 2.4;
const float RAD = 44.0;
const float SA = 0.13;
const int SN = 45;
const int SH = 53;

struct Shell {
	vec4 col;
	float a;
	bool opaque;
	float lk;
};

vec3 shot_n(int i) {
	float lon = i == 0 ? 0.66 : 0.95;
	float lat = i == 0 ? 0.62 : 0.26;
	return vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon));
}

float shot_t(int i) {
	return i == 0 ? 0.42 : 1.5;
}

// the shell at cell P (near or far side): its colour and alpha, whether opaque, and the light it adds
Shell shell_at(ivec2 P, bool nearside) {
	Shell o;
	o.col = vec4(0.0);
	o.a = 0.0;
	o.opaque = false;
	o.lk = 0.0;
	ivec2 q = P + ivec2(SN, SN);
	if (q.x < 0 || q.y < 0 || q.x > 2 * SN || q.y >= SH) {
		return o;
	}
	vec4 b0 = nearside ? texelFetch(near, q, 0) : texelFetch(far, q, 0);
	vec4 b1 = nearside ? texelFetch(near, q + ivec2(0, SH), 0) : texelFetch(far, q + ivec2(0, SH), 0);
	vec4 b2 = nearside ? texelFetch(near, q + ivec2(0, 2 * SH), 0) : texelFetch(far, q + ivec2(0, 2 * SH), 0);
	if (b2.x < 0.0) {
		return o;
	}
	vec3 X = b0.xyz;
	float lat = b0.w;
	float lon = b1.x;
	float e = b1.y;
	float corner = b1.z;
	float rim = b1.w;
	float sil = b2.x;
	bool seam = b2.y > 0.5;
	bool bevel = b2.z > 0.5;
	float glint_at = b2.w;
	float ph = t / D;
	float ff = rim * rim;
	float rp = 0.0;
	float hot = 0.0;
	for (int i = 0; i < 2; i++) {
		float age = mod(t - shot_t(i), D);
		if (age >= 1.0) {
			continue;
		}
		bool big = i == 0;
		float d = acos(clamp(dot(X, shot_n(i)), -1.0, 1.0));
		float f = 0.06 + 3.1 * age;
		float k = (1.0 - age) * (big ? 1.0 : 0.7);
		rp = max(rp, max(exp(-pow((d - f) / 0.15, 2.0)) * k, d < f ? 0.22 * k * k * (1.0 - d / f) : 0.0));
		float hr = big ? 0.3 : 0.17;
		if (age < 0.55 && d < hr) {
			hot = max(hot, age < 0.07 && d < hr * 0.75 ? 2.0 : pow(1.0 - age / 0.55, 1.5) * (1.1 - (0.6 * d) / hr));
		}
	}
	float gl = 0.0;
	if (glint_at >= 0.0) {
		float a = mod(t - glint_at, D);
		if (a < 0.45) {
			gl = 1.0 - a / 0.45;
		}
	}
	float sk = clamp((ph - 0.72) / 0.26, 0.0, 1.0);
	float scan_lat = -0.2 + sk * 2.0;
	float sc = sin(PI * sk) * exp(-pow((lat - scan_lat) / 0.09, 2.0));
	if (!nearside) {
		if (seam) {
			o.col = rp > 0.3 ? pal[5] : pal[3];
			o.a = clamp(0.18 + 0.25 * ff + 0.6 * rp + 0.3 * sc, 0.0, 1.0);
		} else {
			o.col = pal[2];
			o.a = 0.04 + 0.06 * ff + 0.15 * rp;
		}
		return o;
	}
	if (sil < 1.15) {
		float lit = -X.x * 0.55 + X.y * 0.85;
		o.col = rp > 0.4 || lit > 0.8 ? vec4(1.0) : lit > 0.3 ? pal[6] : pal[5];
		o.a = 1.0;
		o.opaque = true;
		o.lk = 0.3;
		return o;
	}
	if (hot >= 2.0) {
		o.col = seam ? pal[6] : vec4(1.0);
		o.a = 1.0;
		o.opaque = true;
		return o;
	}
	if (seam) {
		float I = 0.12 + 0.5 * ff + 0.08 * sin(lon * 2.3 + lat * 3.0 - ph * TAU) + (corner < 0.32 ? 0.18 : 0.0) + 0.9 * gl + 0.7 * sc + 1.3 * rp + hot;
		o.col = gl > 0.6 || rp > 0.55 || hot > 0.5 ? vec4(1.0) : I > 0.8 ? pal[6] : I > 0.55 ? pal[5] : pal[4];
		if (I > 0.36) {
			o.a = 1.0;
			o.opaque = true;
		} else {
			o.a = 0.3 + I;
		}
		o.lk = 0.04 + 0.08 * I;
	} else {
		float a = 0.05 + 0.34 * ff * rim + 0.1 * pow(e, 4.0) + (bevel ? 0.12 + 0.2 * ff : 0.0) + 0.35 * gl + 0.1 * sc + 0.3 * rp + 0.6 * hot;
		o.col = hot > 0.6 ? vec4(1.0) : hot > 0.3 || gl > 0.5 ? pal[6] : rp > 0.4 || bevel ? pal[5] : ff > 0.5 ? pal[4] : pal[3];
		o.a = clamp(a, 0.0, 1.0);
		if (rp > 0.1 || hot > 0.0 || gl > 0.0) {
			o.lk = 0.06 * (rp + hot + gl);
		}
	}
	return o;
}

vec2 project(float lon, float lat) {
	float X = cos(lat) * sin(lon);
	float Y = sin(lat);
	float Z = cos(lat) * cos(lon);
	return vec2(RAD * X, -RAD * (Y * sqrt(1.0 - SA * SA) - Z * SA));
}
