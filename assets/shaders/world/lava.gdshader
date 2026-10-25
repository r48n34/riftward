shader_type spatial;

// RIFTWARD lava surface. Opaque, emissive, slowly flowing crust plates with hot
// cracks. WorldFluid builds one flat surface per lava basin at the basin level.

render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 crust_color : source_color = vec4(0.035, 0.018, 0.012, 1.0);
uniform vec4 lava_color : source_color = vec4(0.88, 0.18, 0.025, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.58, 0.16, 1.0);
uniform float flow_speed = 0.35;
uniform float emission_energy = 1.25;
uniform float wave_height = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.30 + TIME * flow_speed)
		* cos(world_pos.z * 0.36 - TIME * flow_speed * 0.8);
	VERTEX.y += w * wave_height;
}

void fragment() {
	float n = sin(world_pos.x * 0.18 + sin(world_pos.z * 0.11) * 2.0 + TIME * flow_speed)
		* cos(world_pos.z * 0.23 + sin(world_pos.x * 0.09) * 1.7 - TIME * flow_speed * 0.6);
	float n2 = sin((world_pos.x * 0.55 + world_pos.z * 0.47) - TIME * 0.31)
		* cos((world_pos.x * 0.31 - world_pos.z * 0.62) + TIME * 0.19);
	float lava = smoothstep(0.08, 0.78, n * 0.55 + n2 * 0.45 + 0.5);
	vec3 col = mix(crust_color.rgb, lava_color.rgb, lava);
	col = mix(col, hot_color.rgb, pow(lava, 3.0) * 0.42);
	ALBEDO = col;
	EMISSION = col * emission_energy * (0.20 + lava * 0.85);
	ROUGHNESS = mix(0.94, 0.45, lava);
	METALLIC = 0.0;
}
