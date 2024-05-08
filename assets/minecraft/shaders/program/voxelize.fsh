#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 viewProjMat;
flat in mat4 mvpInverse;
flat in vec3 offset;

out vec4 fragColor;

bool collectVoxel(ivec3 blockCoord, int x, int y, int z, out bool valid) {
    valid = false;
    vec3 worldSpace = vec3(blockCoord) + (vec3(x, y, z)) / 8 + offset;
    vec4 homog = viewProjMat * vec4(worldSpace, 1.0);
    vec3 clip = homog.xyz / homog.w;
    if (clamp(clip.xy, -1, 1) != clip.xy) {
        return false;
    }

    float depth = texture(DiffuseDepthSampler, clip.xy * 0.5 + 0.5).r;
    if (depth == 1.0) {
        return false;
    }

    homog = mvpInverse * vec4(clip.xy, depth * 2.0 - 1.0, 1.0);
    vec3 backProj = homog.xyz / homog.w;

    valid = true;
    return distance(backProj, worldSpace) < 0.2;
}

void collectRow(out uint row, ivec3 blockCoord, int voxelRow, int voxelDepth) {
    row = 0u;
    uint shift = 0u;
    for (int i = 0; i < 8; i++) {
        bool valid;
        bool present = collectVoxel(blockCoord, i, voxelRow, voxelDepth, valid);
        if (valid) {
            row |= (present ? (1u << shift) : 0u);
        }
        shift++;
    }
}

void main() {
    // Discard marker
    if (texCoord.y <= 1.0 / InSize.y && texCoord.x <= 16.0 / InSize.x) {
        fragColor = vec4(0.0);
        return;
    }

    ivec2 coord = ivec2(gl_FragCoord.xy);

    uint row0;
    uint row1;
    uint row2;
    uint row3;

    ivec2 blockFragCoord = coord / ivec2(16, 1);
    int voxelFragCoord = coord.x % 16;
    int voxelDepth = voxelFragCoord / 2;
    int voxelRowOffset = (voxelFragCoord % 2) * 4;
    int blockLinCoord = blockFragCoord.y * 128 + blockFragCoord.x;
    ivec3 blockCoord = ivec3(blockLinCoord % 64, (blockLinCoord / 64) % 64, (blockLinCoord / 4096) % 64) - 32;

    collectRow(row0, blockCoord, voxelRowOffset, voxelDepth);
    collectRow(row1, blockCoord, voxelRowOffset + 1, voxelDepth);
    collectRow(row2, blockCoord, voxelRowOffset + 2, voxelDepth);
    collectRow(row3, blockCoord, voxelRowOffset + 3, voxelDepth);

    fragColor = vec4(float(row0), float(row1), float(row2), float(row3)) / 255.;
}