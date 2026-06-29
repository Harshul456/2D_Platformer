varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_strength;
uniform float u_softness;
uniform float u_aspect;

void main()
{
    vec2 uv = v_vTexcoord;
    vec2 dc = uv - vec2(0.5);
    dc.x *= u_aspect;

    float dist = length(dc);
    float edge = smoothstep(u_softness, 0.72, dist);

    gl_FragColor = vec4(0.02, 0.03, 0.07, edge * u_strength * v_vColour.a);
}
