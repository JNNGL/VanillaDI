#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D VoxelCacheSampler;
uniform vec2 InSize;

flat in int renderDistance;
flat in int range;
in vec3 position;
in vec3 prevPosition;

out vec4 fragColor;

vec4 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = i % 256;
    i = i / 256;
    int g = i % 256;
    i = i / 256;
    int b = i % 256;
    return vec4(float(r) / 255.0, float(g) / 255.0, float(b + s) / 255.0, 0.0);
}

vec4 encodeFloat1024(float v) {
    v *= 1024.0;
    v = floor(v);
    return encodeInt(int(v));
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    if (coord.y == 0 && coord.x < 3) {
        switch (coord.x) {
            case 0: fragColor = encodeFloat1024(position.x); break;
            case 1: fragColor = encodeFloat1024(position.y); break;
            case 2: fragColor = encodeFloat1024(position.z); break;
        }
        return;
    }

    ivec3 blockOff = ivec3(floor(position) - floor(prevPosition));
    if (blockOff == ivec3(0, 0, 0)) {
        fragColor = texelFetch(DiffuseSampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    ivec2 screenPos = ivec2(floor(gl_FragCoord.xy) - vec2(0, 1));
    int linear = screenPos.y * int(InSize.x) + screenPos.x;
    ivec3 voxelPos = ivec3(linear % range, (linear / range) % range, linear / (range * range)) - renderDistance;
    voxelPos -= blockOff;
    int prevLinear = (voxelPos.z + renderDistance) * range * range + (voxelPos.y + renderDistance) * range + (voxelPos.x + renderDistance);
    ivec2 prevCoord = ivec2(prevLinear % int(InSize.x), prevLinear / int(InSize.x) + 1);
    vec4 prevPointer = texelFetch(DiffuseSampler, prevCoord, 0);
    if (prevPointer.a == 1.0) {
        fragColor = prevPointer;
        return;
    }

    ivec3 data = ivec3(prevPointer.rgb * 255.0);
    ivec2 pointCoord = ivec2(data.x << 4 | (data.z & 0xF), data.y << 4 | (data.z >> 4));
    int pointLinear = pointCoord.y * int(InSize.x) + pointCoord.x;
    ivec3 pointPos = ivec3(pointLinear % range, (pointLinear / range) % range, pointLinear / (range * range)) - renderDistance;
    pointPos += blockOff;
    pointLinear = (pointPos.z + renderDistance) * range * range + (pointPos.y + renderDistance) * range + (pointPos.x + renderDistance);
    pointCoord = ivec2(pointLinear % int(InSize.x), pointLinear / int(InSize.x));
    ivec3 pointer = ivec3(pointCoord.x >> 4, pointCoord.y >> 4, ((pointCoord.y & 0xF) << 4) | (pointCoord.x & 0xF));
    fragColor = vec4(vec3(pointer) / 255.0, prevPointer.a);
}