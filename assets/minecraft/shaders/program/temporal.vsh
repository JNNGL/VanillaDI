#version 150

in vec4 Position;

uniform sampler2D DiffuseSampler;
uniform sampler2D PreviousDataSampler;

uniform mat4 ProjMat;
uniform vec2 OutSize;

flat out mat4 invProjViewMat;
flat out mat4 prevProjViewMat;
flat out vec3 position;
flat out vec3 prevPosition;
out vec2 texCoord;
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
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    
    mat4 mvp;

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i, 0), 0);
        mvp[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    invProjViewMat = inverse(mvp);

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(PreviousDataSampler, ivec2(i, 0), 0);
        prevProjViewMat[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(32 + i, 0), 0);
        position[i] = decodeFloat1024(color.rgb);
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(PreviousDataSampler, ivec2(32 + i, 0), 0);
        prevPosition[i] = decodeFloat1024(color.rgb);
    }
    
    vec2 pos = gl_Position.xy / gl_Position.w;
    near = invProjViewMat * vec4(pos, -1, 1);
    far = invProjViewMat * vec4(pos, 1, 1);

    texCoord = outPos.xy * 0.5 + 0.5;
}