shader_type spatial;

// RIFTWARD water surface. Vertex waves are tiny (the mesh is a flat basin
// surface); the shader supplies the shimmer, depth tint and fresnel rim.
// Vertex alpha carries a depth factor baked by WorldFluid (0 = shore, 1 = deep).

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.04, 0.24, 0.28, 1.0);
uniform vec4 deep_color : source_color = vec4(0.008, 0.05, 0.08, 1.0);
uniform vec4 foam_color : source_color = vec4(0.62, 0.84, 0.82, 1.0);
uniform float wave_height = 0.045;
uniform float wave_speed = 0.8;
uniform float wave_scale = 0.22;
uniform float alpha_base = 0.88;

varying vec3 world_pos;
varying vec4 v_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * wave_scale + TIME * wave_speed)
		* cos(world_pos.z * wave_scale * 1.3 - TIME * wave_speed * 0.75);
	VERTEX.y += w * wave_height;
	v_color = COLOR;
}

void fragment() {
	float depth = clamp(v_color.a, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth);
	NORMAL = normalize(NORMAL + vec3(
		sin(world_pos.x * 0.85 + TIME * 1.1) * 0.035,
		0.0,
		cos(world_pos.z * 0.95 - TIME * 0.9) * 0.035));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, foam_color.rgb, clamp(fres * 0.18 + (1.0 - depth) * 0.08, 0.0, 0.30));
	ALBEDO = col;
	ROUGHNESS = 0.18;
	METALLIC = 0.06;
	SPECULAR = 0.45;
	ALPHA = clamp(alpha_base * (0.50 + depth * 0.60) + fres * 0.10, 0.18, 0.97);
	EMISSION = shallow_color.rgb * 0.025;
}
