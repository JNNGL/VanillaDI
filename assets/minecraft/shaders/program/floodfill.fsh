#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D VoxelCacheSampler;
uniform vec2 InSize;

flat in int renderDistance;
flat in int range;
in vec3 position;

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

    {
        vec4 current = texelFetch(DiffuseSampler, ivec2(gl_FragCoord.xy), 0);
        if (current.a == 1.0) {
            fragColor = current;
            return;
        }
    }

    ivec2 screenPos = ivec2(floor(gl_FragCoord.xy) - vec2(0, 1));
    int linear = screenPos.y * int(InSize.x) + screenPos.x;
    ivec3 voxelPos = ivec3(linear % range, (linear / range) % range, linear / (range * range)) - renderDistance;

    ivec2 bestCoord = ivec2(0, 0);
    int bestValue = 0;

    const ivec3 offsets[] = ivec3[](ivec3(-1, 0, 0), ivec3(1, 0, 0), ivec3(0, -1, 0), ivec3(0, 1, 0), ivec3(0, 0, -1), ivec3(0, 0, 1));
    for (int i = 0; i < 6; i++) {
        ivec3 neighVoxel = voxelPos + offsets[i];
        int neighLinear = (neighVoxel.z + renderDistance) * range * range + (neighVoxel.y + renderDistance) * range + (neighVoxel.x + renderDistance);
        ivec2 neighCoord = ivec2(neighLinear % int(InSize.x), neighLinear / int(InSize.x) + 1);
        vec4 neighPointer = texelFetch(VoxelCacheSampler, neighCoord, 0);
        int neighValue = int(neighPointer.a * 255.0);
        if (neighValue >= bestValue) {
            bestCoord = neighCoord;
            bestValue = neighValue;
        }
    }

    if (bestValue <= 15) {
        fragColor = vec4(0.0);
        return;
    }

    if (bestValue != 255) {
        vec4 neighPointer = texelFetch(VoxelCacheSampler, bestCoord, 0);
        ivec3 data = ivec3(neighPointer.rgb * 255.0);
        bestCoord = ivec2(data.x << 4 | (data.z & 0xF), data.y << 4 | (data.z >> 4));
    }

    ivec3 pointer = ivec3(bestCoord.x >> 4, bestCoord.y >> 4, ((bestCoord.y & 0xF) << 4) | (bestCoord.x & 0xF));
    fragColor = vec4(pointer, bestValue - 15) / 255.0;
}