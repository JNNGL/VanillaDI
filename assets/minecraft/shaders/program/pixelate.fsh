#version 150

uniform sampler2D RadianceSampler;
uniform sampler2D NormalSampler;
uniform sampler2D DiffuseDepthSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 projViewMat;
flat in mat4 mvpInverse;
flat in vec3 position;

out vec4 fragColor;

vec3 reconstructPosition(vec3 offset, in vec2 uv, in float z) {
  vec4 position_s = vec4(uv, z, 1.0f) * 2.0 - 1.0;
  vec4 position_v = mvpInverse * position_s;
  return position_v.xyz / position_v.w - offset;
}

vec2 toScreenSpace(vec3 offset, vec3 worldSpace) {
    vec4 homog = projViewMat * vec4(worldSpace + offset, 1.0);
    return homog.xy / homog.w * 0.5 + 0.5;
}

vec3 decodeHdr(vec4 color) {
    if (color.a == 0.0) return vec3(0.0);
    return color.rgb * (1.0 / color.a);
}

vec4 encodeHdr(vec3 color) {
    float m = min(max(color.r, max(color.g, color.b)), 255);
    if (m <= 0.0) return vec4(0.0);
    if (m < 1.0) return vec4(color, 1.0);
    return vec4(color / m, 1.0 / m);
}

#define BLOCKDIM 16.0

void main() {
    vec3 blockOffset = fract(position);
    float depth = texture(DiffuseDepthSampler, texCoord).r;
    vec3 worldSpace = reconstructPosition(blockOffset, texCoord, depth);
    vec3 centerNormal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    vec3 voxel = floor(worldSpace * BLOCKDIM) / BLOCKDIM + (0.5 / BLOCKDIM);
    const vec3 signs[] = vec3[](vec3(1, 1, 1), vec3(-1, 1, 1), vec3(1, 1, -1), vec3(-1, 1, -1), vec3(1, -1, 1), vec3(-1, -1, 1), vec3(1, -1, -1), vec3(-1, -1, -1));
    vec3 sum = vec3(0.0);
    float wSum = 0.0;
    for (int i = 0; i < 8; i++) {
        vec3 sgn = signs[i];
        sgn *= (0.33 / BLOCKDIM);
        sgn += voxel;
        vec2 ss = toScreenSpace(blockOffset, sgn);
        vec3 normal = normalize(texture(NormalSampler, ss).rgb * 2.0 - 1.0);
        if (dot(normal, centerNormal) < 0.9) continue;
        float d = texture(DiffuseDepthSampler, ss).r;
        vec3 ws = reconstructPosition(blockOffset, ss, d);
        if (distance(ws, sgn) > 0.2) continue;
        vec3 sampl = decodeHdr(texture(RadianceSampler, ss));
        sum += sampl;
        wSum += 1.0;
    }
    sum /= max(wSum, 1.0);
    fragColor = encodeHdr(sum);
}