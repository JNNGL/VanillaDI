#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 mvpInverse;
flat in mat4 viewProjMat;
flat in mat4 projection;

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

    vec4 cs4 = inverse(projection) * (vec4(texCoord, texture(DiffuseDepthSampler, texCoord).r, 1.0) * 2.0 - 1.0);
    vec3 cs = cs4.xyz / cs4.w;

    vec4 sDir = viewProjMat * vec4(lightDir, 1.0);
    vec4 projDir4 = inverse(projection) * vec4(sDir.xyz / sDir.w, 1.0);
    vec3 projDir =  normalize(projDir4.xyz / projDir4.w);

    bool shadowed = traceScreenSpaceRay(fragPos, lightDir, dist);
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

    shade(color, position, normal, 0);
    shade(color, position, normal, 1);

    color.rgb = acesFilm(color.rgb);
    fragColor = color;
    gl_FragDepth = depth;
}