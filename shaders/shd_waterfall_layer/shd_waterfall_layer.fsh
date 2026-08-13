varying vec2 v_vTexcoord;
varying vec4 v_vColour;

// 1 = keep green water (drop metal), 0 = keep metal/rim (drop water)
uniform float u_keep_water;
uniform float u_min_g;
uniform float u_g_over_r;

bool is_water(vec4 c) {
    return c.a > 0.05 && c.g > u_min_g && c.g > c.r + u_g_over_r && c.g >= c.b - 0.1;
}

void main() {
    vec4 col = texture2D(gm_BaseTexture, v_vTexcoord) * v_vColour;
    bool water = is_water(col);
    if (u_keep_water > 0.5) {
        if (!water) {
            gl_FragColor = vec4(0.0);
            return;
        }
    } else {
        if (water) {
            gl_FragColor = vec4(0.0);
            return;
        }
    }
    gl_FragColor = col;
}
