#version 330

// *======= CONFIG =======* //

#define ENABLE_SHADOWS
#define LIGHT_SELECTIONS 8

#define VOXELIZATION_OFFSET (vec3(0.5, 1.0, 0.0))
#define MIN_TRACE_DISTANCE 0.015

#define ENABLE_SSRT

//////////////////////////////

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
flat in mat4 viewMat;
flat in vec3 offset;
flat in int lightCount;
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

bool traceScreenSpaceRay(vec3 origin, float depth, vec3 direction, float maxRayDistance, inout vec3 seed) {
    const int samples = 25;

    vec3 sstwpos = origin + direction * 0.01 * length(origin);

    float stepSize = 1. / 50.;
    origin += direction * random(seed) * stepSize;

    for (int ss = 0; ss < samples; ss++) {
        sstwpos += direction * stepSize;
        vec4 ssproj = viewProjMat * vec4(sstwpos, 1.0);
        vec3 sspos = (ssproj.xyz / ssproj.w) * 0.5 + 0.5;
        if (clamp(sspos, 0.0, 1.0) != sspos) break;
        float ds = texture(DiffuseDepthSampler, sspos.xy).r;
        float delta = sspos.z - ds;
        if (ds != 1.0 && delta > 0 && delta < 0.02 * (1.0 - depth)) {
            return true;
        }
    }

    return false;
}

bool traceBlock(vec3 rayPos, vec3 rayDir, vec3 mask, int texelX, int texelY, float dist) {
    rayPos = clamp(rayPos, vec3(0.0001), vec3(7.9999));
    vec3 mapPos = floor(rayPos);
    vec3 raySign = sign(rayDir);
    vec3 deltaDist = 1.0 / rayDir;
    vec3 sideDist = ((mapPos - rayPos) + 0.5 + raySign * 0.5) * deltaDist;
    
    for (int j = 0; j < 24; j++) {
        if (clamp(mapPos, 0.0, 7.0) != mapPos) break;

        ivec3 voxel = ivec3(mapPos);
        int index = (voxel.y >= 4 ? 1 : 0) + voxel.z * 2;
        uvec4 s = uvec4(texelFetch(VoxelSampler, ivec2(texelX * 16 + index, texelY), 0) * 255);
        if ((s[voxel.y % 4] & (1u << uint(voxel.x))) != 0u) {
            return true;
        }
            
        mask = vec3(lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy)));
        mapPos += mask * raySign;
        sideDist += mask * raySign * deltaDist;
    }
    
    return false;
}

float traceVoxels(vec3 origin, vec3 direction, float maxDist) {
    vec3 traversalOrigin = origin;
    vec3 currentVoxel = floor(traversalOrigin);
    vec3 raySign = sign(direction);
    vec3 deltaDist = 1.0 / direction;
    vec3 sideDist = ((currentVoxel - traversalOrigin) + 0.5 + raySign * 0.5) * deltaDist;
    vec3 mask = vec3(lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy)));

    for (int i = 0; i < 32; i++) {
        vec3 relativeBlock = floor(currentVoxel);
        if (clamp(relativeBlock, -32, 31) != relativeBlock) {
            break;
        }

        int linearIndex = (int(relativeBlock.z) + 32) * 64 * 64 + (int(relativeBlock.y) + 32) * 64 + int(relativeBlock.x) + 32;
        int texelY = linearIndex / 128;
        int texelX = linearIndex % 128;
        
        vec3 s = ((currentVoxel - traversalOrigin) + 0.5 - 0.5 * vec3(raySign)) * deltaDist;
        float d = max(s.x, max(s.y, s.z));
        if (d > maxDist) {
            return -1.0;
        }

        if (texelFetch(VoxelLodSampler, ivec2(texelX, texelY), 0) != vec4(0.0)) {
            vec3 p = traversalOrigin + direction * d;
            vec3 u = p - currentVoxel;
            if (currentVoxel == floor(traversalOrigin))
               u = traversalOrigin - currentVoxel;
            bool hit = traceBlock(u * 8.0, direction, mask, texelX, texelY, d);
            if (hit) return d;
        }

        mask = vec3(lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy)));
        currentVoxel += mask * raySign;
        sideDist += mask * raySign * deltaDist;
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

bool areaLight(vec3 fragPos, vec3 position, mat3 tbn, inout vec3 color, 
               inout vec3 pointOnLight, inout vec3 normal, out float area, inout vec3 seed) {
    const float width = 1.5;
    const float height = 1.0;

    pointOnLight = position + (random(seed) * width - width * 0.5) * tbn[0] + (random(seed) * height - height * 0.5) * tbn[1];
    area = width * height;

    vec3 direction = normalize(pointOnLight - fragPos);
    return dot(direction, normal) < 0;
}

bool samplePointOnLight(int type, int index, vec3 fragPos, vec3 position, mat3 tbn, inout vec3 color, inout vec3 pointOnLight, 
                        inout vec3 normal, out float area, inout float pdf, inout vec3 seed) {
    switch (type) {
        case 0: return areaLight(fragPos, position, tbn, color, pointOnLight, normal, area, seed);
        // Add your custom light here
    }

    return false;
}

light sampleLight(int index, vec3 fragPos, vec3 normal, inout vec3 seed) {
    int base = index * 11 + 36;
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
    vec3 var = texelFetch(DiffuseSampler, ivec2(base + 10, 0), 0).rgb;
    
    float intensity = var.r * 100;

    vec3 tangent = normalize(vec3(tx, ty, tz));
    vec3 bitangent = normalize(vec3(bx, by, bz));
    mat3 tbn = mat3(tangent, bitangent, normalize(cross(tangent, bitangent)));

    float area, pdf = 1.0;
    vec3 lnorm = tbn[2], pos = vec3(x, y, z);
    bool valid = samplePointOnLight(0, index, fragPos, vec3(x, y, z), tbn, c, pos, lnorm, area, pdf, seed);
    vec3 lightDir = normalize(pos - fragPos);

    float diff = max(dot(normal, lightDir), 0.0);
    float dist = length(pos - fragPos);
    
    float dist2 = dist * dist;
    float cosine = dot(lightDir, lnorm);
    float attenuation = float(valid) * (2 * 3.1415926535 * pdf) / (dist2 / abs(cosine * area)) * diff;

    light l;
    l.position = pos;
    l.normal = lnorm;
    l.direction = lightDir;
    l.radiance = c * intensity * attenuation;
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

vec3 shade(vec3 color, vec3 fragPos, float depth, vec3 normal, inout vec3 seed) {
    reservoir res;
    res.wSum = 0;
    res.m = 0;

    const int M = LIGHT_SELECTIONS;

    float pdf = 1.0 / lightCount;

    light survived;
    survived.radiance = vec3(0.0);

    for (int i = 0; i < M; i++) {
        int index = int(floor(random(seed) * lightCount));
        light l = sampleLight(index, fragPos, normal, seed);
        float w = length(l.radiance) / pdf;
        if (updateReservoir(res, index, w, 1, seed))
            survived = l;
    }

    if (survived.radiance == vec3(0.0)) {
        return vec3(0.0);
    }

#ifdef ENABLE_SHADOWS
    float minDistance = MIN_TRACE_DISTANCE * length(fragPos);
    vec3 traversalOrigin = fragPos - offset + VOXELIZATION_OFFSET + survived.direction * minDistance;

    float traceDist = traceVoxels(traversalOrigin, survived.direction, survived.dist);

    bool shadowed = traceDist != -1.0;
#ifdef ENABLE_SSRT
    if (!shadowed) {
        shadowed = traceScreenSpaceRay(fragPos, depth, survived.direction, survived.dist, seed);
    }
#endif
#else
    const bool shadowed = false;
#endif
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
    float m = min(max(color.r, max(color.g, color.b)), 255);
    if (m == 0.0) return vec4(0.0);
    if (m < 1.0) return vec4(color, 1.0);
    return vec4(color / m, 1.0 / m);
}

void main() {
    if (gl_FragCoord.y == 0 || lightCount == 0) {
        fragColor = encodeHdr(vec3(0.0));
        return;
    }

    float depth = texture(DiffuseDepthSampler, texCoord).r;
    vec3 position = reconstructPosition(texCoord, depth);
    vec3 normal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    vec4 color = texture(DiffuseSampler, texCoord);

    vec3 seed = vec3(texCoord, Time);

    vec3 origin = near.xyz / near.w;
    vec3 direction = normalize(far.xyz / far.w - origin);

    color.rgb = shade(color.rgb, position, depth, normal, seed);
    
    fragColor = encodeHdr(color.rgb);
}