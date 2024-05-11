#version 420

uniform sampler2D DiffuseDepthSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    float depth = texture(DiffuseDepthSampler, texCoord).r;
    fragColor = unpackUnorm4x8(floatBitsToUint(depth));
}