#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D LightingSampler;
uniform sampler2D UvSampler;
uniform sampler2D AtlasSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec4 color = texture(DiffuseSampler, texCoord);
    vec4 lighting = texture(LightingSampler, texCoord);

    vec4 uvData = texture(UvSampler, texCoord);
    if (uvData.a == 1.0) {
        int pckd = int(uvData.b * 255);
        ivec2 d = ivec2(pckd & 0x0F, pckd >> 4);
        ivec2 a = ivec2(uvData.xy * 255);
        ivec2 atlasCoord = a * 16 + d;
        color = texelFetch(AtlasSampler, atlasCoord, 0);
    }

    fragColor = color * lighting;
}