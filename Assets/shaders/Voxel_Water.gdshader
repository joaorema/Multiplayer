shader_type spatial;

#include "C:/Multiplayer/addons/zylann.voxel/shaders/transvoxel.gdshaderinc"
#include "C:/Multiplayer/addons/zylann.voxel/shaders/virtual_texturing.gdshaderinc"
#include "C:/Multiplayer/addons/zylann.voxel/shaders/triplanar.gdshaderinc"
#include "C:/Multiplayer/addons/zylann.voxel/shaders/lod_fade.gdshaderinc"

// --- Textures ---
uniform sampler2D u_texture_top : source_color;
uniform sampler2D u_texture_sides : source_color;

// --- Wave parameters ---
uniform float wave_frequency : hint_range(0.01, 2.0) = 0.2;
uniform float wave_amplitude : hint_range(0.0, 5.0) = 1.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_vertex_pos_model;

void vertex() {
    // Base voxel LOD position
    VERTEX = get_transvoxel_position(VERTEX, CUSTOM0);
    v_vertex_pos_model = VERTEX;

    // Add sound-wave style deformation along Y
    VERTEX.y += sin(VERTEX.x * wave_frequency + TIME * wave_speed) * wave_amplitude;

    // World position for fragment shader
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Calculate normals
    NORMAL = get_voxel_normal_view(v_vertex_pos_model, NORMAL, VIEW_MATRIX * MODEL_MATRIX);
    vec3 normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;

    // World position for texture coordinates
    vec3 wpos = v_world_pos * 0.1; // tweak if textures appear stretched

    // Triplanar blending
    float triplanar_sharpness = 8.0;
    vec3 blending = get_triplanar_blend(normal, triplanar_sharpness);

    // Top/sides mixing
    float topness_midlevel = 0.5;
    float topness_smoothness = 0.04;
    float topness_min = topness_midlevel - topness_smoothness;
    float topness_max = topness_midlevel + topness_smoothness;
    float topness = smoothstep(topness_min, topness_max, normal.y);

    vec3 top_col = texture_triplanar(u_texture_top, wpos, blending).rgb;
    vec3 side_col = texture_triplanar(u_texture_sides, wpos, blending).rgb;

    ALBEDO = mix(side_col, top_col, topness);

    // LOD fade discard
    if (get_lod_fade_discard(SCREEN_UV)) {
        discard;
    }
}
