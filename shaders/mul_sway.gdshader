// Painted sprite multiplied on paper, swaying gently away from its anchor corner.
shader_type canvas_item;
render_mode blend_mul;

uniform float sway = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * 0.5 + uv.y * 5.0) * sway * uv.y * uv.y;
	COLOR = vec4(texture(TEXTURE, uv).rgb, 1.0);
}
