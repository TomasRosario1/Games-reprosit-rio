shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float brightness : hint_range(0.65,1.45) = 1.0;
uniform vec2 motion = vec2(0.0);
uniform float radial_motion = 0.0;

void fragment() {
	vec2 velocity = clamp(motion+(SCREEN_UV-vec2(0.5))*radial_motion,vec2(-0.035),vec2(0.035));
	vec3 color = texture(screen_texture,SCREEN_UV).rgb;
	if (dot(velocity,velocity)>0.00000005) {
		for (int i=1; i<6; i++) {
			vec2 uv = clamp(SCREEN_UV-velocity*(float(i)/5.0),vec2(0.001),vec2(0.999));
			color += texture(screen_texture,uv).rgb;
		}
		color /= 6.0;
	}
	COLOR = vec4(color*brightness,1.0);
}
