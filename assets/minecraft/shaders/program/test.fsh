#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D VoxelSampler;
uniform sampler2D VoxelLodSampler;

uniform vec2 InSize;
uniform float Time;

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

float decodeFloat(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 40000.0;
}

vec3 reconstructPosition(in vec2 uv, in float z) {
  vec4 position_s = vec4(uv, z, 1.0f) * 2.0 - 1.0;
  vec4 position_v = mvpInverse * position_s;
  return position_v.xyz / position_v.w;
}

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

float distanceSquared(vec2 a, vec2 b) { a -= b; return dot(a, a); }

bool traceScreenSpaceRay(vec3 origin, vec3 direction, float maxRayDistance, out bool couldHit) {
    couldHit = false;

    const int samples = 50;

    vec3 sstwpos = origin;
    float stepSize = min(maxRayDistance / samples, 0.05);
    vec3 sspos;
    bool found = false;
    for (int ss = 0; ss < samples; ss++) {
        sstwpos += direction * stepSize;
        vec4 ssproj = viewProjMat * vec4(sstwpos, 1.0);
        sspos = ssproj.xyz / ssproj.w * 0.5 + 0.5;
        if (clamp(sspos.xy, 0.0, 1.0) == sspos.xy) {
            float ds = texture(DiffuseDepthSampler, sspos.xy).r;
            vec4 dswproj = mvpInverse * (vec4(sspos.xy, ds, 1.0) * 2.0 - 1.0);
            vec3 dswpos = dswproj.xyz / dswproj.w;
            bool hit = ds != 1.0 && ds <= sspos.z;
            couldHit = couldHit || hit;
            if (hit && length(dswpos - sstwpos) < 0.2) {
                return true;
            }
        } else {
            couldHit = true;
        }
    }

    return false;
}

float traceBlock(vec3 rayPos, vec3 rayDir, vec3 _mask, int texelX, int texelY, inout vec3 normal, float dist) {
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
            float totalDist = d + dist;
            // if (totalDist >= 1.0) 
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

float traceVoxels(vec3 origin, vec3 direction, out vec3 normal, float maxDist) {
    normal = vec3(0.0);
    vec3 traversalOrigin = origin;
    vec3 currentVoxel = floor(traversalOrigin);
    vec3 raySign = sign(direction);
    vec3 deltaDist = 1.0 / direction;
    vec3 sideDist = ((currentVoxel - traversalOrigin) + 0.5 + raySign * 0.5) * deltaDist;

    bvec3 b1 = lessThan(sideDist.xyz, sideDist.yzx);
    bvec3 b2 = lessThanEqual(sideDist.xyz, sideDist.zxy);
    bvec3 mask = bvec3(b1.x && b2.x, b1.y && b2.y, b1.z && b2.z);
    mask.z = mask.z || !any(mask);
    vec3 vmask = vec3(mask);

    for (int i = 0; i < 32; i++) {
        vec3 relativeBlock = floor(currentVoxel);
        if (clamp(relativeBlock, -32, 31) != relativeBlock) {
            break;
        }

        int linearIndex = (int(relativeBlock.z) + 32) * 64 * 64 + (int(relativeBlock.y) + 32) * 64 + int(relativeBlock.x) + 32;
        int texelY = linearIndex / 128;
        int texelX = linearIndex % 128;
        
        vec3 mini = ((currentVoxel - traversalOrigin) + 0.5 - 0.5 * vec3(raySign)) * deltaDist;
        float d = max(mini.x, max(mini.y, mini.z));
        if (d > maxDist) {
            return -1.0;
        }

        if (texelFetch(VoxelLodSampler, ivec2(texelX, texelY), 0) != vec4(0.0)) {
            // normal = vmask;
            // return float(texelX) / 128;
            //return 1.0;
            vec3 intersect = traversalOrigin + direction * d;
            vec3 uv3d = intersect - currentVoxel;
            if (currentVoxel == floor(traversalOrigin))
               uv3d = traversalOrigin - currentVoxel;
            float dist = traceBlock(uv3d * 8.0, direction, vmask, texelX, texelY, normal, d);

            if (dist != -1) return d;
        }

        bvec3 b1 = lessThan(sideDist.xyz, sideDist.yzx);
        bvec3 b2 = lessThanEqual(sideDist.xyz, sideDist.zxy);
        bvec3 mask = bvec3(b1.x && b2.x, b1.y && b2.y, b1.z && b2.z);
        mask.z = mask.z || !any(mask);
        vmask = vec3(mask);
        
        currentVoxel += vmask * raySign;
        sideDist += vmask * raySign * deltaDist;
    }

    return -1.0;
}

struct reservoir {
    int index;
    float weight;
    float wSum;
    float m;
};

struct light {
    vec3 position;
    vec3 normal;
    vec3 direction;
    vec3 radiance;
    float dist;
};

light sampleLight(int index, vec3 fragPos, vec3 normal, inout vec3 seed) {
    const float width = 1.5;
    const float height = 1.0;
    const float area = width * height;
    const float intensity = 10;

    int base = index * 11;
    float x = decodeFloat1024(texelFetch(DiffuseSampler, ivec2(base + 0, 0), 0).rgb);
    float y = decodeFloat1024(texelFetch(DiffuseSampler, ivec2(base + 1, 0), 0).rgb);
    float z = decodeFloat1024(texelFetch(DiffuseSampler, ivec2(base + 2, 0), 0).rgb);
    float tx = decodeFloat(texelFetch(DiffuseSampler, ivec2(base + 3, 0), 0).rgb);
    float ty = decodeFloat(texelFetch(DiffuseSampler, ivec2(base + 4, 0), 0).rgb);
    float tz = decodeFloat(texelFetch(DiffuseSampler, ivec2(base + 5, 0), 0).rgb);
    float bx = decodeFloat(texelFetch(DiffuseSampler, ivec2(base + 6, 0), 0).rgb);
    float by = decodeFloat(texelFetch(DiffuseSampler, ivec2(base + 7, 0), 0).rgb);
    float bz = decodeFloat(texelFetch(DiffuseSampler, ivec2(base + 8, 0), 0).rgb);
    vec3 c = texelFetch(DiffuseSampler, ivec2(base + 9, 0), 0).rgb;

    vec3 tangent = normalize(vec3(tx, ty, tz));
    vec3 bitangent = normalize(vec3(bx, by, bz));
    vec3 lnorm = normalize(cross(tangent, bitangent));

    vec3 pos = vec3(x, y, z) + (random(seed) * width - width * 0.5) * tangent + (random(seed) * height - height * 0.5) * bitangent;
    vec3 lightDir = normalize(pos - fragPos);

    float diff = max(dot(normal, lightDir), 0.0);
    float dist = length(pos - fragPos);
    
    float dist2 = dist * dist;
    float cosine = dot(lightDir, lnorm);
    float attenuation = max(0.0, sign(cosine)) * (2 * 3.1415926535 * intensity) / (dist2 / abs(cosine * area)) * diff;

    light l;
    l.position = pos;
    l.normal = lnorm;
    l.direction = lightDir;
    l.radiance = c * attenuation;
    l.dist = dist;

    return l;
}

bool updateReservoir(inout reservoir res, int i, float w, float n, inout vec3 seed) {
    res.wSum += w;
    res.m += n;
    bool u = random(seed) < w / res.wSum;
    if (u) res.index = i;
    return u;
}

vec3 shade(vec3 color, vec3 fragPos, vec3 normal, inout vec3 seed) {
    reservoir res;
    res.wSum = 0;
    res.m = 0;

    const int M = 8;
    const int lightCount = 3;

    float pdf = 1.0 / lightCount;

    light survived;
    survived.radiance = vec3(0.0);

    for (int i = 0; i < M; i++) {
        int index = int(floor(random(seed) * (lightCount - 0.001)));
        light l = sampleLight(index, fragPos, normal, seed);
        float w = length(l.radiance) / pdf;
        if (updateReservoir(res, index, w, 1, seed))
            survived = l;
    }

    if (survived.radiance == vec3(0.0)) {
        return vec3(0.0);
    }

    vec3 norm;
    float traceDist = traceVoxels(fragPos - offset + vec3(0.5, 1.0, 0.0), survived.direction, norm, survived.dist);
    bool shadowed = traceDist != -1.0 && traceDist < survived.dist;
    if (!shadowed) {
        vec3 radiance = survived.radiance;
        float p = length(radiance);
        res.weight = p > 0.0 ? (1.0 / p) * res.wSum / res.m : 0.0;
        return radiance * res.weight;
    } else {
        res.weight = 0.0;
        return vec3(0.0);
    }
}

vec4 encodeHdr(vec3 color) {
    float m = max(color.r, max(color.g, color.b));
    if (m == 0.0) return vec4(0.0);
    if (m < 1.0) return vec4(color, 1.0);
    return vec4(color / m, 1.0 / m);
}

void main() {
    float depth = texture(DiffuseDepthSampler, texCoord).r;
    vec3 position = reconstructPosition(texCoord, depth);
    vec3 normal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    vec4 color = texture(DiffuseSampler, texCoord);

    vec3 seed = vec3(texCoord, Time);

    vec3 origin = near.xyz / near.w;
    vec3 direction = normalize(far.xyz / far.w - origin);

    color.rgb = shade(color.rgb, position, normal, seed);
    
    fragColor = encodeHdr(color.rgb);
}