varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main() {
    vec4 base_col = v_vColour * texture2D(gm_BaseTexture, v_vTexcoord);
    
    // Calculate brightness: (R+G+B)/3
    float brightness = (base_col.r + base_col.g + base_col.b) / 3.0;
    
    // 1. Thresholding: If it's a bright pixel (the white rim), keep it solid
    if (brightness > 0.8) {
        gl_FragColor = base_col;
    } 
    // 2. If it's the darker grey body, apply extra transparency
    else {
        // Multiply original alpha by 0.2 to make the grey part 80% see-through
        gl_FragColor = vec4(base_col.rgb, base_col.a * 0.2); 
    }
}