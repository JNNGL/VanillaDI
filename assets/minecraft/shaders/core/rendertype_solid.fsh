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
in float passUv;
in vec3 position;

out vec4 fragColor;

void main() {
    if (passUv > 0.0) {
        vec3 p1 = dFdx(position);
        vec3 p2 = dFdy(position);
        vec2 t1 = dFdx(texCoord0);
        vec2 t2 = dFdy(texCoord0);
        
        vec3 bitangent = normalize(p1 * t2.x - p2 * t1.x);

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

    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}