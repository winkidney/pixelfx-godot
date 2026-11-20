// The end of every weather particle process shader: it defines `bool body(int i, out vec2 p, out vec4 cu, out vec4
// col)` (where slot i is at the clock `t`, false when it shows nothing) before including this. Each particle sits
// on the corner of its pixel cell (floor(p)), so its quad (an even number of px) lies on the pixel grid and the
// canvas shader draws whole cells around it; CUSTOM.xy hands it the fraction of p, CUSTOM.zw and COLOR whatever
// else the body needs (the Compatibility renderer passes them at half precision: keep them small).

void wx_place(int i, inout mat4 tr, inout vec4 cu_out, inout vec4 col_out) {
	vec2 p = vec2(0.0);
	vec4 cu = vec4(0.0);
	vec4 col = vec4(0.0);
	bool on = body(i, p, cu, col);
	vec2 cell = floor(p);
	float sc = on ? 1.0 : 0.0;
	tr = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(on ? cell : vec2(-4096.0), 0.0, 1.0));
	cu_out = vec4(p - cell, cu.zw);
	col_out = col;
}

void start() {
	VELOCITY = vec3(0.0);
	wx_place(int(INDEX), TRANSFORM, CUSTOM, COLOR);
}

void process() {
	VELOCITY = vec3(0.0);
	wx_place(int(INDEX), TRANSFORM, CUSTOM, COLOR);
}
