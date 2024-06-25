#version 150

#define VOXELIZATION_OFFSET (vec3(0.5, 1.0, 0.0))

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D VoxelCacheSampler;

in vec2 texCoord;
flat in mat4 viewProjMat;
flat in mat4 mvpInverse;
flat in vec3 offset;
flat in vec3 position;
flat in vec3 prevPosition;
flat in int lightCount;
flat in int frame;

out vec4 fragColor;

vec4 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = i % 256;
    i = i / 256;
    int g = i % 256;
    i = i / 256;
    int b = i % 256;
    return vec4(float(r) / 255.0, float(g) / 255.0, float(b + s) / 255.0, 1.0);
}

vec4 encodeFloat1024(float v) {
    v *= 1024.0;
    v = floor(v);
    return encodeInt(int(v));
}

bool collectVoxel(ivec3 blockCoord, int x, int y, int z, out bool valid, out bool force) {
    valid = false;
    force = false;
    vec3 worldSpace = vec3(blockCoord) + (vec3(x, y, z) + 0.5) / 8 + offset - VOXELIZATION_OFFSET;
    vec4 homog = viewProjMat * vec4(worldSpace, 1.0);
    vec3 clip = homog.xyz / homog.w;
    if (clamp(clip.xy, -1, 1) != clip.xy) {
        return false;
    }

    vec3 normal = normalize(texture(NormalSampler, clip.xy * 0.5 + 0.5).rgb * 2.0 - 1.0);
    worldSpace += normal * (1.0 / 16.0);
    
    homog = viewProjMat * vec4(worldSpace, 1.0);
    clip = homog.xyz / homog.w;
    if (clamp(clip.xy, -1, 1) != clip.xy) {
        return false;
    }

    float depth = texture(DiffuseDepthSampler, clip.xy * 0.5 + 0.5).r;
    if (depth > clip.z * 0.5 + 0.5) {
        valid = true;
        force = true;
        return false;
    }

    if (depth == 1.0) {
        return false;
    }

    homog = mvpInverse * vec4(clip.xy, depth * 2.0 - 1.0, 1.0);
    vec3 backProj = homog.xyz / homog.w;

    valid = true;
    return distance(backProj, worldSpace) < depth * 0.2;
}

void collectRow(inout uint row, ivec3 blockCoord, int voxelRow, int voxelDepth) {
    uint shift = 0u;
    for (int i = 0; i < 8; i++) {
        bool valid, force;
        bool present = collectVoxel(blockCoord, i, voxelRow, voxelDepth, valid, force);
        if (force) {
            row &= ~(1u << shift);
        }
        if (valid) {
            row |= (present ? (1u << shift) : 0u);
        }
        shift++;
    }
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    if (coord.y == 0 && coord.x < 4) {
        switch (coord.x) {
            case 0: fragColor = encodeFloat1024(position.x); break;
            case 1: fragColor = encodeFloat1024(position.y); break;
            case 2: fragColor = encodeFloat1024(position.z); break;
            case 3: fragColor = encodeInt(frame + 1); break;
        }
        return;
    }

    ivec2 blockFragCoord = coord / ivec2(16, 1);
    int voxelFragCoord = coord.x % 16;
    int voxelDepth = voxelFragCoord / 2;
    int voxelRowOffset = (voxelFragCoord % 2) * 4;
    int blockLinCoord = blockFragCoord.y * 128 + blockFragCoord.x;
    ivec3 blockCoord = ivec3(blockLinCoord % 64, (blockLinCoord / 64) % 64, (blockLinCoord / 4096) % 64) - 32;

    bool hasCache = texelFetch(VoxelCacheSampler, ivec2(0, 0), 0) != vec4(0.0);
    uint row0 = 0u;
    uint row1 = 0u;
    uint row2 = 0u;
    uint row3 = 0u;

    ivec3 blockOff = ivec3(floor(position) - floor(prevPosition));
    ivec3 prevBlock = blockCoord - blockOff;
    if (hasCache && clamp(prevBlock, -32, 31) == prevBlock) {
        int linearIndex = (int(prevBlock.z) + 32) * 64 * 64 + (int(prevBlock.y) + 32) * 64 + int(prevBlock.x) + 32;
        int texelY = linearIndex / 128;
        int texelX = linearIndex % 128;
        vec4 cache = texelFetch(VoxelCacheSampler, ivec2(texelX * 16 + voxelFragCoord, texelY), 0);
        row0 = uint(cache[0] * 255);
        row1 = uint(cache[1] * 255);
        row2 = uint(cache[2] * 255);
        row3 = uint(cache[3] * 255);
    }

    if (lightCount > 0 && frame == 0) {
        collectRow(row0, blockCoord, voxelRowOffset, voxelDepth);
        collectRow(row1, blockCoord, voxelRowOffset + 1, voxelDepth);
        collectRow(row2, blockCoord, voxelRowOffset + 2, voxelDepth);
        collectRow(row3, blockCoord, voxelRowOffset + 3, voxelDepth);
    }

    fragColor = vec4(float(row0), float(row1), float(row2), float(row3)) / 255.;
}