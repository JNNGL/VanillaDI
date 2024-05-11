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
in float marker;
flat in int type;
in vec4 position0;
in vec4 position1;
in vec4 position2;
in vec4 position3;
flat in int index;

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
    if (marker == 1.0) {
        int base = index * 11;
        ivec2 coord = ivec2(gl_FragCoord.xy);

        if (coord.x < base && coord.x >= base + 11) {
            discard;
        }

        if (coord.y > 0) {
            discard;
        }

        vec3 pos0 = position0.xyz / position0.w;
        vec3 pos1 = position1.xyz / position1.w;
        vec3 pos2 = position2.xyz / position2.w;
        vec3 pos3 = position3.xyz / position3.w;
        vec3 pos = mix(pos0, pos2, 0.5);

        vec3 pPos = gl_PrimitiveID % 2 == 0 ? pos1 : pos3;
        vec3 tangent = normalize(gl_PrimitiveID % 2 == 1 ? pPos - pos0 : pos2 - pPos);
        vec3 bitangent = normalize(gl_PrimitiveID % 2 == 0 ? pPos - pos0 : pos2 - pPos);

        // Colored light
        // 0,1,2 - position
        // 3,4,5 - tangent
        // 6,7,8 - bitangent
        // 9 - color
        // 10 - properties
        vec4 color = vec4(0.0);
        switch (coord.x - base) {
            case 0: color = encodeFloat1024(pos.x); break;
            case 1: color = encodeFloat1024(pos.y); break;
            case 2: color = encodeFloat1024(pos.z); break;
            case 3: color = encodeFloat(tangent.x); break;
            case 4: color = encodeFloat(tangent.y); break;
            case 5: color = encodeFloat(tangent.z); break;
            case 6: color = encodeFloat(bitangent.x); break;
            case 7: color = encodeFloat(bitangent.y); break;
            case 8: color = encodeFloat(bitangent.z); break;
            case 9: color = index == 0 ? vec4(1, 0.25, 0.25, 1.0) : (index == 1 ? vec4(0.25, 0.25, 1.0, 1.0) : vec4(0.25, 1.0, 0.25, 1.0)); break;
            case 10: color = vec4(0.0, 0.0, 0.0, 1.0); break;
        }

        if (color.a == 0.0) {
            discard;
        }

        fragColor = vec4(color);
        return;
    }

    vec4 color = texture(Sampler0, texCoord0);
    if (color.a < 0.1) {
        discard;
    }
    color *= vertexColor * ColorModulator;
    color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
    color *= lightMapColor;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}
