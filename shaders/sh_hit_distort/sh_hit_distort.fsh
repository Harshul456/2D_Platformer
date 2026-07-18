// Radial displacement shockwave — refracts the scene outward like a water/heat ripple.
// No color is added; it only warps the sampled UVs within an expanding band.
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

#define MAXR 8

uniform int   u_count;             // Active ripple count
uniform vec2  u_center[MAXR];      // Ripple centers in UV (0..1)
uniform float u_radius[MAXR];      // Current radius (fraction of view width)
uniform float u_width[MAXR];       // Band half-width (fraction of view width)
uniform float u_strength[MAXR];    // Peak displacement (fraction of view width)
uniform float u_aspect;            // view_w / view_h (keeps the ring circular)

void main()
{
    vec2 uv = v_vTexcoord;
    vec2 offset = vec2(0.0);

    for (int i = 0; i < MAXR; i++) {
        if (i >= u_count) break;

        // Measure distance in width-fraction space so the wave stays circular.
        vec2 d = vec2(uv.x - u_center[i].x, (uv.y - u_center[i].y) / u_aspect);
        float dist = length(d);
        float diff = dist - u_radius[i];
        float w = u_width[i];

        if (abs(diff) < w) {
            float t = diff / w;                    // -1 (inner) .. 1 (outer)
            float profile = sin(t * 3.14159265);   // push out / pull in (lens refraction)
            float window  = 1.0 - t * t;           // fade to nothing at the band edges
            float mag = profile * window * u_strength[i];

            vec2 dir = (dist > 1e-4) ? (d / dist) : vec2(0.0);
            offset.x += dir.x * mag;
            offset.y += dir.y * mag * u_aspect;    // convert back to UV space
        }
    }

    gl_FragColor = v_vColour * texture2D(gm_BaseTexture, uv + offset);
}
