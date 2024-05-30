#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D PreviousDataSampler;

uniform vec2 InSize;

flat out int renderDistance;
flat out int range;
out vec3 position;
out vec3 prevPosition;

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
    vec4 outPos = corners[gl_VertexID];
    gl_Position = outPos;

    int totalBlocks = int(InSize.x) * (int(InSize.y) - 1);
    renderDistance = (int(floor(pow(float(totalBlocks), 1.0 / 3.0))) - 1) / 2;
    range = renderDistance * 2;

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i, 0), 0);
        position[i] = decodeFloat1024(color.rgb);
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(PreviousDataSampler, ivec2(i, 0), 0);
        prevPosition[i] = decodeFloat1024(color.rgb);
    }
}