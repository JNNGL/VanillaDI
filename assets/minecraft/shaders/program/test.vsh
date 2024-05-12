#version 150

in vec4 Position;

uniform sampler2D DiffuseSampler;

uniform mat4 ProjMat;
uniform vec2 InSize;

out vec2 texCoord;
flat out mat4 mvpInverse;
flat out mat4 viewProjMat;
flat out mat4 projection;
flat out vec3 offset;
flat out int lightCount;
out vec4 near;
out vec4 far;

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

void main() {
    mat4 mvp;
    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i, 0), 0);
        mvp[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    viewProjMat = mvp;
    mvpInverse = inverse(mvp);

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i + 16, 0), 0);
        projection[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(32 + i, 0), 0);
        offset[i] = decodeFloat1024(color.rgb);
    }

    lightCount = decodeInt(texelFetch(DiffuseSampler, ivec2(35, 0), 0).rgb);

    offset = fract(offset);

    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);

    texCoord = outPos.xy * 0.5 + 0.5;

    near = mvpInverse * vec4(gl_Position.xy, -1, 1);
    far = mvpInverse * vec4(gl_Position.xy, 1, 1);
}