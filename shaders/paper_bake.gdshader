// Hanji paper, rendered once into a texture.
shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 res = vec2(1920.0, 1080.0);
uniform vec3 base = vec3(0.945, 0.925, 0.878);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * res;
	float broad = fbm(p * 0.0035);
	float c1 = cos(0.5);
	float s1 = sin(0.5);
	vec2 q = vec2(c1 * p.x - s1 * p.y, s1 * p.x + c1 * p.y);
	vec2 r = vec2(c1 * p.x + s1 * p.y, -s1 * p.x + c1 * p.y);
	float fibre = fbm(q * vec2(0.22, 0.012)) * 0.5 + fbm(r * vec2(0.014, 0.19)) * 0.5;
	float grain = vnoise(p * 1.4);
	vec3 col = base * (0.965 + 0.06 * broad + 0.05 * (fibre - 0.5) + 0.012 * (grain - 0.5));
	vec2 d = UV - 0.5;
	col *= 1.0 - 0.14 * smoothstep(0.25, 0.85, length(d * vec2(1.0, 0.8)));
	// Alpha keeps the fibre value so the ink pass can catch on it.
	COLOR = vec4(col, fibre);
}
