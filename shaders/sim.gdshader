// One step of pond state. R = ink, G = water height, B = water velocity.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D prev : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.00208333, 0.0037037);
uniform float aspect = 1.7778;
uniform int stamp_count = 0;
uniform vec4 stamps[16]; // xy = uv, z = radius in uv height, w = ink
uniform float pushes[16]; // added to water velocity

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec4 c = texture(prev, uv);
	vec4 l = texture(prev, uv - vec2(texel.x, 0.0));
	vec4 r = texture(prev, uv + vec2(texel.x, 0.0));
	vec4 u = texture(prev, uv - vec2(0.0, texel.y));
	vec4 d = texture(prev, uv + vec2(0.0, texel.y));

	float lap = (l.g + r.g + u.g + d.g) * 0.25 - c.g;
	float vel = (c.b + lap * 0.72) * 0.986;
	float height = (c.g + vel) * 0.985;

	// Ink drifts on a slow turbulent field and is pushed by the water.
	float e = 0.05;
	vec2 n = uv * vec2(aspect, 1.0) * 5.0 + vec2(TIME * 0.02, -TIME * 0.015);
	float n0 = vnoise(n);
	vec2 curl = vec2(vnoise(n + vec2(0.0, e)) - n0, -(vnoise(n + vec2(e, 0.0)) - n0)) / e;
	vec2 flow = curl * 0.16 + vec2(r.g - l.g, d.g - u.g) * 14.0;
	float ink = texture(prev, uv - flow * texel).r;
	float around = (l.r + r.r + u.r + d.r) * 0.25;
	ink = mix(ink, around, 0.07);
	ink = max(ink * 0.9968 - 0.00012, 0.0);

	for (int i = 0; i < stamp_count; i++) {
		vec2 delta = (uv - stamps[i].xy) * vec2(aspect, 1.0);
		float rad = stamps[i].z;
		float g = exp(-dot(delta, delta) / (rad * rad));
		ink = min(ink + g * stamps[i].w, 1.5);
		vel += g * pushes[i];
	}
	COLOR = vec4(ink, height, vel, 1.0);
}
