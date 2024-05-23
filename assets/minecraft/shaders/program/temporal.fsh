#version 330

uniform sampler2D RadianceSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D PreviousNormalSampler;
uniform sampler2D PreviousFrameSampler;
uniform sampler2D PreviousRadianceSampler;
uniform sampler2D PreviousDepthSampler;

uniform vec2 OutSize;

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

vec3 reconstructPosition(vec2 uv, float z) {
    vec4 position_clip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 position = invProjViewMat * position_clip;
    return position.xyz / position.w;
}

void main() {
    vec3 color = decodeHdr(texture(RadianceSampler, texCoord));
    fragColor = encodeHdr(color);
    gl_FragDepth = 0.0;

    float depth = texture(DiffuseDepthSampler, texCoord).r;
    if (depth == 1.0) {
        return;
    }
    
    vec3 offset = position - prevPosition;

    vec3 view = reconstructPosition(texCoord, depth);
    vec4 clipSpace = prevProjViewMat * vec4(view - offset, 1.0);
    vec3 screenSpace = clipSpace.xyz / clipSpace.w * 0.5 + 0.5;

    if (clamp(screenSpace.xy, 0.0, 1.0) != screenSpace.xy) {
        return;
    }

    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    vec3 prevNormal = texture(PreviousNormalSampler, screenSpace.xy).rgb * 2.0 - 1.0;
    
    if (dot(normal, prevNormal) < 0.7) {
        return;
    }

    uvec4 prevDepthData = uvec4(texture(PreviousDepthSampler, screenSpace.xy) * 255.0);
    uint prevDepthBits = prevDepthData.r << 24 | prevDepthData.g << 16 | prevDepthData.b << 8 | prevDepthData.a;
    float prevDepth = uintBitsToFloat(prevDepthBits);
    if (abs(screenSpace.z - prevDepth) > 0.001 * screenSpace.z) {
        return;
    }

    float frame = texture(PreviousFrameSampler, screenSpace.xy).r + 1.0 / 100.0;
    vec2 uv = screenSpace.xy * OutSize - 0.5;
    ivec2 coord = ivec2(floor(uv));
    vec2 frac = uv - coord;
    vec3 previousSample = mix(
        mix(decodeHdr(texelFetch(PreviousRadianceSampler, coord, 0)), decodeHdr(texelFetch(PreviousRadianceSampler, coord + ivec2(1, 0), 0)), frac.x), 
        mix(decodeHdr(texelFetch(PreviousRadianceSampler, coord + ivec2(0, 1), 0)), decodeHdr(texelFetch(PreviousRadianceSampler, coord + ivec2(1, 1), 0)), frac.x), 
        frac.y);
    float lum = dot(previousSample, vec3(0.2125, 0.7154, 0.0721));
    float alpha = clamp(0.1 + pow(lum * 0.03, 40), 0.0, 0.5);
    vec3 mixedSample = mix(previousSample, color, max(1.0 / floor(frame * 100), alpha));
    fragColor = encodeHdr(mixedSample.rgb);
    
    // Writing to gl_FragDepth doesn't work with sodium. not sure if it worth computing it in a separate pass.
    gl_FragDepth = clamp(frame, 0.0, 1.0);
}
