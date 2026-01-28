//
// Reflection fragment shader - gradient fade from top to bottom using UV
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_maxAlpha;           // Maximum alpha (0.0 to 1.0)

void main()
{
    vec4 tex_col = v_vColour * texture2D(gm_BaseTexture, v_vTexcoord);
    
    // Fade from top (v=0) to bottom (v=1) of the flipped sprite
    // Since sprite is flipped, v=0 is at the feet (top of reflection), v=1 is bottom
    float fade = 1.0 - v_vTexcoord.y;
    
    // Apply fade and max alpha
    float final_alpha = tex_col.a * fade * u_maxAlpha;
    
    gl_FragColor = vec4(tex_col.rgb, final_alpha);
}
