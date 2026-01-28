varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main() {
    vec4 tex_col = v_vColour * texture2D(gm_BaseTexture, v_vTexcoord);
    
    // Check the brightness (Luminance) of the tile pixel
    float lum = (tex_col.r + tex_col.g + tex_col.b) / 3.0;
    
    if (lum > 0.8) {
        // Bright White Rim: Keep it solid so the reflection is sharp at the edge
        gl_FragColor = tex_col;
    } else {
        // Grey Portion: Force it to be semi-transparent
        // You can change 0.2 to 0.1 for more transparency, or 0.4 for less
        gl_FragColor = vec4(tex_col.rgb, tex_col.a * 0.2); 
    }
}