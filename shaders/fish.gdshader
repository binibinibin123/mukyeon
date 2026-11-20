// Vertex alpha = ink strength, vertex red = softness (mip level).
shader_type canvas_item;
render_mode blend_mul;

varying float strength;
varying float softness;

void vertex() {
	strength = COLOR.a;
	softness = COLOR.r * 6.0;
}

void fragment() {
	vec3 t = textureLod(TEXTURE, UV, softness).rgb;
	COLOR = vec4(mix(vec3(1.0), t, strength), 1.0);
}
