#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D VoxelSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 mvpInverse;
flat in mat4 viewProjMat;
flat in mat4 projection;
flat in vec3 offset;
in vec4 near;
in vec4 far;

out vec4 fragColor;

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

float decodeFloat1024(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 1024.0;
}

vec3 reconstructPosition(in vec2 uv, in float z) {
  vec4 position_s = vec4(uv, z, 1.0f) * 2.0 - 1.0;
  vec4 position_v = mvpInverse * position_s;
  return position_v.xyz / position_v.w;
}

float distanceSquared(vec2 a, vec2 b) { a -= b; return dot(a, a); }

bool traceScreenSpaceRay(vec3 origin, vec3 direction, float maxRayDistance) {
    vec3 sstwpos = origin;
    float stepSize = min(maxRayDistance / 50, 0.05);
    vec3 sspos;
    bool found = false;
    for (int ss = 0; ss < 50; ss++) {
        sstwpos += direction * stepSize;
        vec4 ssproj = viewProjMat * vec4(sstwpos, 1.0);
        sspos = ssproj.xyz / ssproj.w * 0.5 + 0.5;
        if (clamp(sspos.xy, 0.0, 1.0) == sspos.xy) {
            float ds = texture(DiffuseDepthSampler, sspos.xy).r;
            vec4 dswproj = mvpInverse * (vec4(sspos.xy, ds, 1.0) * 2.0 - 1.0);
            vec3 dswpos = dswproj.xyz / dswproj.w;
            if (ds != 1.0 && ds <= sspos.z && length(dswpos - sstwpos) < 0.7) {
                return true;
            }
        }
    }

    return false;
}

float traceBlock(vec3 rayPos, vec3 rayDir, vec3 _mask, int texelX, int texelY, out vec3 normal) {
    rayPos = clamp(rayPos, vec3(0.0001), vec3(7.9999));
    vec3 mapPos = floor(rayPos);
    vec3 raySign = sign(rayDir);
    vec3 deltaDist = 1.0/rayDir;
    vec3 sideDist = ((mapPos - rayPos) + 0.5 + raySign * 0.5) * deltaDist;
    vec3 mask = _mask;
    int j = 0;
    
    while (mapPos.x <= 7.0 && mapPos.x >= 0.0 && mapPos.y <= 7.0 && mapPos.y >= 0.0 && mapPos.z <= 7.0 && mapPos.z >= 0.0) {
        ivec3 voxel = ivec3(mapPos);
        int index = (voxel.y >= 4 ? 1 : 0) + voxel.z * 2;
        uvec4 s = uvec4(texelFetch(VoxelSampler, ivec2(texelX * 16 + index, texelY), 0) * 255);
        if ((s[voxel.y % 4] & (1u << uint(voxel.x))) != 0u) {
            normal = mask;
            vec3 mini = ((mapPos - rayPos) + 0.5 - 0.5 * vec3(raySign)) * deltaDist;
            float d = max(mini.x, max(mini.y, mini.z));
            return d;
        }
            
        bvec3 b1 = lessThan(sideDist.xyz, sideDist.yzx);
        bvec3 b2 = lessThanEqual(sideDist.xyz, sideDist.zxy);
        bvec3 bmask = bvec3(b1.x && b2.x, b1.y && b2.y, b1.z && b2.z);
        bmask.z = bmask.z || !any(bmask);
        mask      = vec3(bmask);
        mapPos   += mask * raySign;
        sideDist += mask * raySign * deltaDist;

        j++;
        if (j >= 24) {
            break;
        }
    }
    
    return -1.0;
}

float traceVoxels(vec3 origin, vec3 direction, out vec3 normal) {
    normal = vec3(0.0);
    vec3 traversalOrigin = origin;
    vec3 currentVoxel = floor(traversalOrigin);
    vec3 raySign = sign(direction);
    vec3 deltaDist = 1.0 / direction;
    vec3 sideDist = ((currentVoxel - traversalOrigin) + 0.5 + raySign * 0.5) * deltaDist;

    for (int i = 0; i < 64; i++) {
        bvec3 b1 = lessThan(sideDist.xyz, sideDist.yzx);
        bvec3 b2 = lessThanEqual(sideDist.xyz, sideDist.zxy);
        bvec3 mask = bvec3(b1.x && b2.x, b1.y && b2.y, b1.z && b2.z);
        mask.z = mask.z || !any(mask);
        vec3 vmask = vec3(mask);
        
        currentVoxel += vmask * raySign;
        sideDist += vmask * raySign * deltaDist;

        vec3 relativeBlock = floor(currentVoxel);
        if (clamp(relativeBlock, -32, 31) != relativeBlock) {
            break;
        }

        int linearIndex = (int(relativeBlock.z) + 32) * 64 * 64 + (int(relativeBlock.y) + 32) * 64 + int(relativeBlock.x) + 32;
        int texelY = linearIndex / 128;
        int texelX = linearIndex % 128;

        bool found = false;
        for (int f = 0; f < 16; f++) {
            if (texelFetch(VoxelSampler, ivec2(texelX * 16 + f, texelY), 0) != vec4(0.0)) {
                found = true;
                break;
            }
        }
        
        if (found) {
            // normal = vmask;
            // return float(texelX) / 128;
            // return 1.0;
            vec3 mini = ((currentVoxel - traversalOrigin) + 0.5 - 0.5 * vec3(raySign)) * deltaDist;
            float d = max(mini.x, max(mini.y, mini.z));
            vec3 intersect = traversalOrigin + direction * d;
            vec3 uv3d = intersect - currentVoxel;
            float dist = traceBlock(uv3d * 8.0, direction, vmask, texelX, texelY, normal);

            if (dist != -1) return d + dist;
        }
    }

    return -1.0;
}

void shade(inout vec4 color, vec3 fragPos, vec3 normal, int index) {
    int base = index * 5;
    float x = decodeFloat1024(texelFetch(DiffuseSampler, ivec2(base + 0, 0), 0).rgb);
    float y = decodeFloat1024(texelFetch(DiffuseSampler, ivec2(base + 1, 0), 0).rgb);
    float z = decodeFloat1024(texelFetch(DiffuseSampler, ivec2(base + 2, 0), 0).rgb);
    vec3 pos = vec3(x, y, z);
    vec3 c = texelFetch(DiffuseSampler, ivec2(base + 3, 0), 0).rgb;

    vec3 lightDir = normalize(pos - fragPos);
    float diff = max(dot(normal, lightDir), 0.0);
    float dist = length(pos - fragPos);
    float attenuation = 1.0 / (0.1 + 0.02 * dist + 0.007 * (dist * dist));

    vec3 norm;
    float traceDist = traceVoxels(fragPos - offset, normalize(vec3(0, 1, 0)), norm);
    // if (traceDist == -2.0 || true) {
    //     color.rgb = vec3(traceDist, 0, 0);
    //     return;
    // }

    bool shadowed = traceDist != -1.0;
    if (!shadowed) {
        c *= attenuation * diff;
        color.rgb *= (1.0 + c);
    }
}

vec3 acesFilm(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0., 1.);
}

void main() {
    float depth = texture(DiffuseDepthSampler, texCoord).r;
    vec3 position = reconstructPosition(texCoord, depth);
    vec3 normal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    vec4 color = texture(DiffuseSampler, texCoord);

    vec3 origin = near.xyz / near.w;
    vec3 direction = normalize(far.xyz / far.w - origin);

    // shade(color, position, normal, 0);
    //shade(color, position, normal, 1);

    color.rgb = acesFilm(color.rgb);
    fragColor = color;

    float r = traceVoxels(origin - offset, direction, normal);
    fragColor = vec4(normal * 0.5 + 0.5, 1.0);

    // fragColor = texture(VoxelSampler, texCoord);
    // fragColor.rgb = mix(fragColor.rgb, color.rgb, 0.5);
    gl_FragDepth = depth;
}