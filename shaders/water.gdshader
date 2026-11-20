// Final pass: bends and shades everything by the water surface.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D sim : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.00208333, 0.0037037);
uniform float bend = 0.55;
uniform float shade = 5.0;

void fragment() {
	float l = texture(sim, UV - vec2(texel.x, 0.0)).g;
	float r = texture(sim, UV + vec2(texel.x, 0.0)).g;
	float u = texture(sim, UV - vec2(0.0, texel.y)).g;
	float d = texture(sim, UV + vec2(0.0, texel.y)).g;
	vec2 g = vec2(r - l, d - u);
	vec3 c = texture(screen, SCREEN_UV + g * bend * texel * 40.0).rgb;
	c *= 1.0 + clamp((g.x + g.y) * shade, -0.22, 0.14);
	COLOR = vec4(c, 1.0);
}
