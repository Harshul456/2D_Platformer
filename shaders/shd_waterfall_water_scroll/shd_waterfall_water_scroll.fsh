varying vec2 v_vTexcoord;
varying vec4 v_vColour;

// Scroll in UV space (pixels / tile height). Silhouette stays fixed; content moves down.
uniform float u_scroll_uv;

void main() {
    vec4 mask_sample = texture2D(gm_BaseTexture, v_vTexcoord);
    if (mask_sample.a < 0.05) {
        gl_FragColor = vec4(0.0);
        return;
    }

    // Subtract so content moves down.
    vec2 uv_scroll = v_vTexcoord;
    uv_scroll.y = fract(uv_scroll.y - u_scroll_uv);
    vec4 scrolled = texture2D(gm_BaseTexture, uv_scroll);

    // If scroll lands on empty/metal, keep original water so the pour never opens black holes.
    vec3 rgb = (scrolled.a > 0.05) ? scrolled.rgb : mask_sample.rgb;
    gl_FragColor = vec4(rgb, mask_sample.a) * v_vColour;
}
