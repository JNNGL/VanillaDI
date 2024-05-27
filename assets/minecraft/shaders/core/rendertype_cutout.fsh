#version 150

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
in vec4 position0;
in vec4 position1;
in vec4 position2;
in vec4 position3;
in vec3 uv0;
in vec3 uv1;
in vec3 uv2;
in vec3 uv3;

out vec4 fragColor;

void main() {
    vec4 color = texture(Sampler0, texCoord0);
    if (color.a < 0.1) {
        discard;
    }

    if (color.a == 250.0 / 255.0) {
        vec3 pos1 = position0.xyz / position0.w;
        vec3 pos2 = position2.xyz / position2.w;
        vec3 pos3 = gl_PrimitiveID % 2 == 0 ? position1.xyz / position1.w : position3.xyz / position3.w;
        vec3 bitangent = normalize(gl_PrimitiveID % 2 == 0 ? pos3 - pos1 : pos2 - pos3);

        vec2 coord0 = uv0.xy / uv0.z;
        vec2 coord1 = uv2.xy / uv2.z;
        vec2 coord2 = gl_PrimitiveID % 2 == 0 ? uv1.xy / uv1.z : uv3.xy / uv3.z;
        vec2 r = normalize(gl_PrimitiveID % 2 == 0 ? coord2 - coord0 : coord1 - coord2);
        if (abs(r.x) > 0.5) bitangent = normalize(gl_PrimitiveID % 2 == 1 ? pos1 - pos3 : pos3 - pos2);
        if (r.x < -0.5 || r.y < -0.5) bitangent *= -1.0;

        ivec2 fragCoord = ivec2(gl_FragCoord.xy);
        vec4 lighting = linear_fog(vertexColor * ColorModulator, vertexDistance, FogStart, FogEnd, FogColor);
        vec4 data = texelFetch(Sampler0, ivec2(texCoord0 * textureSize(Sampler0, 0)), 0);
        if (fragCoord % 2 == ivec2(0, 0)) {
            fragColor = vec4(lighting.rgb, data.a);
        } else if (fragCoord % 2 == ivec2(1, 1)) {
            fragColor = vec4(bitangent * 0.5 + 0.5, data.a);
        } else {
            fragColor = data;
        }

        return;
    }

    color *= vertexColor * ColorModulator;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}