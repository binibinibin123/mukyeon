// Baked paper with the live ink soaked into it.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D paper : filter_linear, repeat_disable;
uniform sampler2D sim : filter_linear, repeat_disable;
uniform vec3 ink_color = vec3(0.095, 0.1, 0.115);

void fragment() {
	vec4 p = texture(paper, UV);
	float ink = texture(sim, UV).r;
	// Thin ink catches on the fibres; the wet rim stays a touch darker.
	float soak = smoothstep(0.01, 0.55, ink * (0.72 + 0.75 * p.a));
	float rim = smoothstep(0.02, 0.16, ink) * (1.0 - smoothstep(0.16, 0.5, ink));
	float a = clamp(soak * 0.8 + rim * 0.1, 0.0, 0.92);
	COLOR = vec4(mix(p.rgb, ink_color, a), 1.0);
}
