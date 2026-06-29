attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_vWorld;

void main()
{
    vec4 _world = gm_Matrices[MATRIX_WORLD] * vec4(in_Position.xyz, 1.0);
    v_vWorld = _world.xy;
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position.xyz, 1.0);
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
}
