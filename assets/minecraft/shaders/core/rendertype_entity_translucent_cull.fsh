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

void main() {
    if (marker == 1.0) {
        // Colored light
        // 0,1,2 - x,y,z
        // 3 - color
        // 4 - properties
        int base = index * 5;
        ivec2 coord = ivec2(gl_FragCoord.xy);

        vec3 pos0 = position0.xyz / position0.w;
        vec3 pos1 = position1.xyz / position1.w;
        vec3 pos = pos0 * 0.5 + pos1 * 0.5;

        if (coord.x < base && coord.x >= base + 5) {
            discard;
        }

        if (coord.y > 0) {
            discard;
        }

        vec4 color = vec4(0.0);
        switch (coord.x - base) {
            case 0: color = encodeFloat1024(pos.x); break;
            case 1: color = encodeFloat1024(pos.y); break;
            case 2: color = encodeFloat1024(pos.z); break;
            case 3: color = index == 0 ? vec4(1, 1, 0.5, 1.0) : vec4(0.25, 0.25, 1.0, 1.0); break;
            case 4: color = vec4(0.0, 0.0, 0.0, 1.0); break;
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
