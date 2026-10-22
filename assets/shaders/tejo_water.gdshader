shader_type spatial;
render_mode cull_disabled;
uniform sampler2D water_texture : source_color, filter_linear_mipmap;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y += sin(world_position.x*0.06+TIME*0.33)*0.045 + sin(world_position.z*0.08+TIME*0.22)*0.035;
}
void fragment() {
	vec2 uv = world_position.xz*0.035+vec2(TIME*0.006,TIME*0.003);
	vec3 t = texture(water_texture,uv).rgb;
	float wave = sin(world_position.x*0.19+TIME*0.6)*sin(world_position.z*0.21+TIME*0.3);
	ALBEDO = vec3(0.065,0.12,0.145)*(0.75+t.r*0.5)+wave*0.009;
	METALLIC = 0.18;
	ROUGHNESS = 0.34;
	NORMAL_MAP = vec3(0.5+wave*0.055,0.5+cos(world_position.z*0.12+TIME*0.4)*0.035,1.0);
	NORMAL_MAP_DEPTH = 0.35;
}
