#version 150

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform mat4 ProjMat;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
in vec3 position;
in float emissiveQuad;
in vec3 emissiveData;
in vec4 glPos;
flat in vec2 voxelCoord;

out vec4 fragColor;

vec4 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = i % 256;
    i = i / 256;
    int g = i % 256;
    i = i / 256;
    int b = i % 256;
    return vec4(float(r) / 255.0, float(g) / 255.0, float(b + s) / 255.0, 1.0);
}

vec4 encodeFloat1024(float v) {
    v *= 1024.0;
    v = floor(v);
    return encodeInt(int(v));
}

vec4 encodeFloat(float v) {
    v *= 40000.0;
    v = floor(v);
    return encodeInt(int(v));
}

void main() {
    if (emissiveQuad > 0.0) {
        ivec2 screenSize = ivec2(round(gl_FragCoord.xy / (glPos.xy / glPos.w * 0.5 + 0.5)));
        ivec2 coord = ivec2(round(voxelCoord * screenSize));
        ivec2 fragCoord = ivec2(gl_FragCoord.xy);
        if (fragCoord == coord) {
            // TODO: Hide these voxels in post
            fragColor = vec4(emissiveData, 249.0 / 255.0);
        } else {
            discard;
        }

        return;
    }

    vec4 color = texelFetch(Sampler0, ivec2(texCoord0 * textureSize(Sampler0, 0)), 0);
    if (color.a < 0.1) {
        discard;
    }

    if (color.a == 250.0 / 255.0) {
        vec3 p1 = dFdx(position);
        vec3 p2 = dFdy(position);
        vec2 t1 = dFdx(texCoord0);
        vec2 t2 = dFdy(texCoord0);
        
        vec3 bitangent = normalize(p1 * t2.x - p2 * t1.x);

        ivec2 fragCoord = ivec2(gl_FragCoord.xy);
        vec4 lighting = linear_fog(vertexColor * ColorModulator, vertexDistance, FogStart, FogEnd, FogColor);
        if (fragCoord % 2 == ivec2(0, 0)) {
            fragColor = vec4(lighting.rgb, color.a);
        } else if (fragCoord % 2 == ivec2(1, 1)) {
            fragColor = vec4(bitangent * 0.5 + 0.5, color.a);
        } else {
            fragColor = color;
        }

        return;
    }

    color *= vertexColor * ColorModulator;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}