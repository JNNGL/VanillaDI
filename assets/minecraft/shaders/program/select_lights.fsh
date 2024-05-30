#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D PreviousLightSampler;

uniform vec2 InSize;
uniform vec2 OutSize;
uniform float Time;

flat in int renderDistance;
flat in int range;
in vec3 position;
in vec3 prevPosition;

out vec4 fragColor;

uint hash(uint x) {
    x += (x << 10u);
    x ^= (x >> 6u);
    x += (x << 3u);
    x ^= (x >> 11u);
    x += (x << 15u);
    return x;
}

uint hash(uvec3 v) {
    return hash(v.x ^ hash(v.y) ^ hash(v.z));
}

float floatConstruct(uint m) {
    const uint ieeeMantissa = 0x007FFFFFu;
    const uint ieeeOne = 0x3F800000u;

    m &= ieeeMantissa;
    m |= ieeeOne;

    float f = uintBitsToFloat(m);
    return f - 1.0;
}

float random(inout vec3 v) {
    return floatConstruct(hash(floatBitsToUint(v += 1.0)));
}

vec4 pickLight(inout vec3 seed) {
    vec4 prevLight = texelFetch(PreviousLightSampler, ivec2(gl_FragCoord.xy), 0);
    ivec3 prevData = ivec3(prevLight.rgb * 255.0);
    ivec2 pointCoord = ivec2(prevData.x << 4 | (prevData.z & 0xF), prevData.y << 4 | (prevData.z >> 4));
    int pointLinear = pointCoord.y * int(InSize.x) + pointCoord.x;
    ivec3 pointPos = ivec3(pointLinear % range, (pointLinear / range) % range, pointLinear / (range * range)) - renderDistance;
    pointPos += ivec3(floor(position) - floor(prevPosition));;
    pointLinear = (pointPos.z + renderDistance) * range * range + (pointPos.y + renderDistance) * range + (pointPos.x + renderDistance);
    pointCoord = ivec2(pointLinear % int(InSize.x), pointLinear / int(InSize.x));
    prevData = ivec3(pointCoord.x >> 4, pointCoord.y >> 4, ((pointCoord.y & 0xF) << 4) | (pointCoord.x & 0xF));
    prevLight.rgb = vec3(prevData) / 255.0;
    if (texelFetch(DiffuseSampler, pointCoord, 0).a < 1.0) {
        prevLight = vec4(0.0);
    }

    for (int i = 0; i < 16; i++) {
        ivec3 voxel = ivec3(vec3(random(seed), random(seed), random(seed)) * range - renderDistance);
        int linear = (voxel.z + renderDistance) * range * range + (voxel.y + renderDistance) * range + (voxel.x + renderDistance);
        ivec2 coord = ivec2(linear % int(InSize.x), linear / int(InSize.x));

        vec4 pointer = texelFetch(DiffuseSampler, coord, 0);
        if (pointer.a == 0.0) {
            continue;
        }

        if (pointer.a < 1.0) {
            ivec3 data = ivec3(pointer.rgb * 255.0);
            coord = ivec2(data.x << 4 | (data.z & 0xF), data.y << 4 | (data.z >> 4));
            pointer = texelFetch(DiffuseSampler, coord, 0);
        }

        if (pointer.a < 1.0) {
            continue;
        }

        ivec3 packedCoord = ivec3(coord.x >> 4, coord.y >> 4, ((coord.y & 0xF) << 4) | (coord.x & 0xF));
        if (packedCoord == prevData) prevLight.a *= 0.9;
        if (random(seed) >= prevLight.a) return vec4(vec3(packedCoord) / 255.0, 1.0);
    }

    return prevLight;
}

void main() {
    vec3 seed = vec3(gl_FragCoord.xy, Time);
    fragColor = pickLight(seed);
}