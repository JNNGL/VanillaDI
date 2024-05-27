#version 330

uniform sampler2D RadianceSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D PreviousNormalSampler;
uniform sampler2D PreviousFrameSampler;
uniform sampler2D PreviousRadianceSampler;
uniform sampler2D PreviousDepthSampler;

uniform vec2 OutSize;
uniform float Step;

flat in mat4 invProjViewMat;
flat in mat4 prevProjViewMat;
flat in vec3 position;
flat in vec3 prevPosition;
in vec2 texCoord;
in vec4 near;
in vec4 far;

out vec4 fragColor;

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

void main() {
    vec3 color = decodeHdr(texture(RadianceSampler, texCoord));
    vec3 centerNormal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    float centerDepth = texture(DiffuseDepthSampler, texCoord).r;
    float centerLuma = dot(color, vec3(0.2125, 0.7154, 0.0721));
    vec4 cproj = invProjViewMat * (vec4(texCoord, centerDepth, 1.0) * 2.0 - 1.0);
    vec3 cws = cproj.xyz / cproj.w;
    
    float dw = Step <= 1.0 ? 0.0 : (pow(length(cws), 0.5));

    float wSum = 1.0;
    vec3 cSum = color;

    const int radius = 2;
    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            if (x == 0 && y == 0) continue;
            
            vec2 uv = (gl_FragCoord.xy + vec2(x, y) * sqrt(Step)) / OutSize;

            vec3 radiance = decodeHdr(texture(RadianceSampler, uv));
            vec3 normal = normalize(texture(NormalSampler, uv).rgb * 2.0 - 1.0);
            float depth = texture(DiffuseDepthSampler, uv).r;
            float luma = dot(radiance, vec3(0.2125, 0.7154, 0.0721));

            float wNorm = pow(max(0, dot(centerNormal, normal)), 1024.0);
            float wLum = abs(luma - centerLuma) / 5;
            vec4 proj = invProjViewMat * (vec4(uv, depth, 1.0) * 2.0 - 1.0);
            vec3 ws = proj.xyz / proj.w;
            float d = distance(ws, cws);
            if (d > 0.15) continue;
            float w = exp(-d - dw - wLum) * wNorm;
            
            wSum += w;
            cSum += radiance * w;
        }
    }

    cSum /= wSum;
    fragColor = encodeHdr(cSum);
}
