// Shared by the tractor beam's shaders (src/fx/scifi/tractor-beam.js): the cone's half width at a height, the haul
// (where something hauled up the beam is at progress k: quickening, winding round the axis and in toward it), the
// rocks' lives (popping out of the floor, wobbling a beat, spiralling up into the lens). Declare `t` first.

const float D = 3.0;
const float LENS = -84.0;
const float TOPW = 5.5;
const float BOTW = 32.0;
const float POP = 0.1;
const float HOVER = 0.32;
const float RISE = 1.4;

float half_w(float y) {
	return mix(BOTW, TOPW, clamp(y / LENS, 0.0, 1.0));
}

vec3 haul(float r0, float th0, float dir, float turns, float k) {
	float s = pow(clamp(k, 0.0, 1.0), 1.8);
	float y = mix(-2.0, LENS + 5.0, s);
	float th = th0 + dir * TAU * turns * s;
	float rr = r0 * (half_w(y) / BOTW) * (1.0 - 0.5 * s);
	return vec3(cos(th) * rr, y, sin(th));
}

struct Rock {
	vec2 p;
	vec2 prev;
	float z;
	float size;
	float a;
	float lift;
	float age;
};

// rock params: (born, r0, th0, dir), (size, a0, va, 0)
Rock rock_at(vec4 r, vec4 q, float age) {
	Rock k;
	k.age = age;
	float lift = clamp((age - POP - HOVER) / RISE, 0.0, 1.0);
	k.lift = lift;
	if (lift > 0.0) {
		vec3 h = haul(r.y, r.z, r.w, 1.3, lift);
		vec3 h1 = haul(r.y, r.z, r.w, 1.3, lift - 0.07);
		k.p = h.xy;
		k.z = h.z;
		k.prev = h1.xy;
		k.size = q.x * (1.0 - 0.6 * pow(lift, 2.5));
		k.a = q.y + q.z * age * (0.3 + lift * 2.0);
	} else {
		float u = clamp((age - POP) / HOVER, 0.0, 1.0);
		float y = age < POP ? mix(3.0, -2.0, age / POP) : -2.0 - 2.0 * (u * u * (3.0 - 2.0 * u));
		float wob = age > POP ? sin(age * 55.0 + r.z * 9.0) * 0.7 : 0.0;
		k.p = vec2(cos(r.z) * r.y + wob, y);
		k.prev = k.p;
		k.z = 1.0;
		k.size = q.x;
		k.a = q.y + q.z * age * 0.3;
	}
	return k;
}
