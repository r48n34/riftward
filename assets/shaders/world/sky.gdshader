shader_type sky;

// RIFTWARD alien sky — warm late-afternoon gradient, sun disc + halo, a ringed
// gas giant, and a faint star field high above. Fully procedural. The ring is
// drawn as an ellipse in the planet's tangent plane so it tracks the disc.

uniform vec3 sky_top_color : source_color = vec3(0.10, 0.19, 0.38);
uniform vec3 sky_horizon_warm : source_color = vec3(0.88, 0.57, 0.34);
uniform vec3 sky_horizon_cool : source_color = vec3(0.45, 0.52, 0.62);
uniform vec3 ground_color : source_color = vec3(0.26, 0.19, 0.15);
uniform vec3 sun_color : source_color = vec3(1.0, 0.80, 0.56);
uniform vec3 sun_dir = vec3(-0.80, 0.30, -0.52);
uniform float sun_size = 0.99986;
uniform vec3 planet_dir = vec3(0.38, 0.44, -0.81);
uniform float planet_radius = 0.105;
uniform float planet_tilt = 0.30;
uniform vec3 planet_band_a : source_color = vec3(0.64, 0.55, 0.42);
uniform vec3 planet_band_b : source_color = vec3(0.36, 0.25, 0.19);
uniform vec3 ring_color : source_color = vec3(0.72, 0.66, 0.55);
uniform float star_amount = 0.22;

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sd = normalize(sun_dir);
	float y = dir.y;

	// --- base gradient -------------------------------------------------------
	float t = pow(clamp(y, 0.0, 1.0), 0.45);
	vec3 col = mix(sky_horizon_cool, sky_top_color, t);

	// Warm side of the horizon follows the sun azimuth.
	vec2 dh = normalize(vec2(dir.x, dir.z) + vec2(0.0001, 0.0));
	vec2 sh = normalize(vec2(sd.x, sd.z) + vec2(0.0001, 0.0));
	float sun_side = max(dot(dh, sh), 0.0);
	vec3 horizon = mix(sky_horizon_cool, sky_horizon_warm, pow(sun_side, 1.7));
	col = mix(col, horizon, pow(clamp(1.0 - y, 0.0, 1.0), 2.6) * 0.95);

	// Thin low haze band, strongest toward the sun.
	col += horizon * (0.10 + 0.16 * pow(sun_side, 2.0)) * exp(-abs(y) * 10.0);

	// --- sun disc + subtle halo ---------------------------------------------
	float sun_dot = max(dot(dir, sd), 0.0);
	col += sun_color * pow(sun_dot, 12.0) * 0.10;
	col += sun_color * pow(sun_dot, 500.0) * 0.32;
	float disk = smoothstep(sun_size, sun_size + 0.0006, sun_dot);
	col = mix(col, sun_color * 2.6, disk);

	// --- ground below horizon ------------------------------------------------
	if (y < 0.0) {
		vec3 g = mix(horizon, ground_color, clamp(-y * 5.0, 0.0, 1.0));
		col = mix(g, col, clamp(1.0 + y * 3.0, 0.0, 0.15));
	}

	// --- ringed giant planet -------------------------------------------------
	vec3 p = normalize(planet_dir);
	vec3 up_hint = vec3(0.0, 1.0, 0.0);
	vec3 u = normalize(cross(up_hint, p));
	vec3 v = cross(p, u);
	vec2 tangent = vec2(dot(dir, u), dot(dir, v)) / planet_radius;
	float r = length(tangent);

	// Atmospheric limb glow just outside the disc.
	if (r > 0.96 && r < 1.30) {
		float limb_glow = smoothstep(1.30, 1.0, r) * smoothstep(0.96, 1.02, r);
		col += vec3(0.45, 0.34, 0.24) * limb_glow * 0.20;
	}

	if (r < 1.0) {
		// Banded gas giant, limb-darkened, with a subtle storm oval.
		float band = sin(tangent.y * 13.0 + sin(tangent.x * 2.8) * 2.0 + 1.1);
		vec3 pcol = mix(planet_band_b, planet_band_a, band * 0.5 + 0.5);
		float spot = smoothstep(0.30, 0.0, length(tangent - vec2(0.26, -0.20)));
		pcol = mix(pcol, planet_band_a * 1.18, spot * 0.45);
		float limb = smoothstep(1.0, 0.60, r);
		pcol *= 0.55 + 0.55 * limb;
		// Sun-facing limb is brighter.
		float lit = clamp(dot(normalize(vec3(tangent.x, tangent.y, 1.4)), sd) * 0.5 + 0.5, 0.0, 1.0);
		pcol *= 0.88 + 0.26 * lit;
		col = mix(col, pcol, smoothstep(1.0, 0.94, r));
	}

	// --- planet ring (inclined ellipse, faint) -------------------------------
	vec2 rt = vec2(tangent.x, tangent.y / max(planet_tilt, 0.05));
	float rr = length(rt);
	if (rr > 1.22 && rr < 1.78) {
		float band = smoothstep(1.22, 1.30, rr) * smoothstep(1.78, 1.64, rr);
		float gaps = 0.55 + 0.45 * sin(rr * 58.0 + sin(tangent.x * 3.0) * 2.0);
		float ring_lit = clamp(dot(normalize(vec3(tangent.x, tangent.y, 1.0)), sd) * 0.5 + 0.5, 0.15, 1.0);
		col = mix(col, ring_color * (0.55 + 0.35 * ring_lit), band * gaps * 0.55);
	}

	// --- faint stars (tiny round dots, high sky only) ------------------------
	vec3 sp = dir * 480.0;
	vec3 cell = floor(sp);
	vec3 frac_c = fract(sp) - 0.5;
	float hsh = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float dot_mask = smoothstep(0.20, 0.0, length(frac_c));
	float star = step(0.9975, hsh) * dot_mask;
	col += vec3(0.72, 0.82, 1.0) * star * star_amount * clamp(y * 2.2 - 0.15, 0.0, 1.0);

	COLOR = col;
}
