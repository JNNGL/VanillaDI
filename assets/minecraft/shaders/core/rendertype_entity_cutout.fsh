#version 150

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;
in vec4 vertexColor;
in vec4 lightMapColor;
in vec4 overlayColor;
in vec2 texCoord0;
in vec4 normal;

out vec4 fragColor;

void main() {
    vec4 color = texture(Sampler0, texCoord0);
    if (color.a == 250.0 / 255.0) {
        int pckd = int(color.b * 255);
        ivec2 d = ivec2(pckd & 0x0F, pckd >> 4);
        ivec2 a = ivec2(color.xy * 255);
        ivec2 atlasCoord = a * 16 + d;
        // TODO: Too hacky to be usable
        color = texelFetch(Sampler0, atlasCoord, 0);
    }

    if (color.a < 0.1) {
        discard;
    }
    color *= vertexColor * ColorModulator;
    color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
    color *= lightMapColor;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}