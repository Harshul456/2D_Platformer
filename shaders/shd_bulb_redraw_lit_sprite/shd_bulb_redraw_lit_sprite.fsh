varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_vWorld;

uniform sampler2D u_sLit;
uniform vec2 u_vViewPos;
uniform vec2 u_vViewSize;

void main()
{
    vec4 _mask = texture2D(gm_BaseTexture, v_vTexcoord);
    if (_mask.a < 0.01) discard;

    vec2 _uv = (v_vWorld - u_vViewPos) / u_vViewSize;
    vec4 _lit = texture2D(u_sLit, _uv);

    gl_FragColor = vec4(_lit.rgb, _mask.a * v_vColour.a);
}
