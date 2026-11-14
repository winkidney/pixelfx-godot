// Shared by the blessing's cone shaders: the cone's half width at y and the light across it at q = x / half width.
const float TOP = -108.0;
// offset across the cone, width, shimmers a loop, phase
const vec4 BLESS_RAYS[4] = vec4[](vec4(-0.62, 0.16, 1.0, 0.3), vec4(-0.2, 0.2, 2.0, 1.7), vec4(0.22, 0.14, 1.0, 4.1), vec4(0.6, 0.18, 2.0, 2.6));

float bless_half(float y) {
	return mix(5.0, 20.0, (y - TOP) / -TOP);
}

float bless_ray(float q, float t) {
	float I = 0.3 * max(0.0, 1.0 - q * q);
	for (int i = 0; i < 4; i++) {
		vec4 r = BLESS_RAYS[i];
		float d = (q - r.x) / r.y;
		I += exp(-d * d) * (0.55 + 0.45 * sin(t * TAU * r.z + r.w)) * 0.6;
	}
	return I * (1.0 - smoothstep(0.75, 1.25, abs(q)));
}
