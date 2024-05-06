#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 mvpInverse;

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

    c *= attenuation * diff;

    color.rgb *= (1.0 + c);
}

void main() {
    vec3 position = reconstructPosition(texCoord, texture(DiffuseDepthSampler, texCoord).r);
    vec3 normal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    vec4 color = texture(DiffuseSampler, texCoord);

    shade(color, position, normal, 0);

    fragColor = color;
}