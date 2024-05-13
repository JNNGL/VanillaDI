#version 150

#define SKIP_FRAMES 5

in vec4 Position;

uniform sampler2D DiffuseSampler;
uniform sampler2D VoxelCacheSampler;

uniform mat4 ProjMat;
uniform vec2 InSize;

out vec2 texCoord;
flat out mat4 viewProjMat;
flat out mat4 mvpInverse;
flat out vec3 offset;
flat out vec3 position;
flat out vec3 prevPosition;
flat out int lightCount;
flat out int frame;
flat out vec3 direction;

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

float decodeFloat(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 40000.0;
}

float decodeFloat1024(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 1024.0;
}

const vec4[] corners = vec4[](
    vec4(-1, -1, 0, 1),
    vec4(1, -1, 0, 1),
    vec4(1, 1, 0, 1),
    vec4(-1, 1, 0, 1)
);

void main() {
    mat4 projection;
    mat4 viewMat;

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i, 0), 0);
        projection[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i + 16, 0), 0);
        viewMat[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    viewProjMat = projection * viewMat;
    mvpInverse = inverse(viewProjMat);

    vec4 near = mvpInverse * vec4(0, 0, -1, 1);
    vec4 far = mvpInverse * vec4(0, 0, 1, 1);
    direction = normalize(far.xyz / far.w - near.xyz / near.w);

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(32 + i, 0), 0);
        position[i] = decodeFloat1024(color.rgb);
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(VoxelCacheSampler, ivec2(i, 0), 0);
        prevPosition[i] = decodeFloat1024(color.rgb);
    }

    offset = fract(position);
    lightCount = decodeInt(texelFetch(DiffuseSampler, ivec2(35, 0), 0).rgb);
    frame = max(decodeInt(texelFetch(VoxelCacheSampler, ivec2(3, 0), 0).rgb), 0);
    if (frame >= SKIP_FRAMES) frame = 0;

    vec4 outPos = corners[gl_VertexID];
    gl_Position = outPos;

    texCoord = outPos.xy * 0.5 + 0.5;
}