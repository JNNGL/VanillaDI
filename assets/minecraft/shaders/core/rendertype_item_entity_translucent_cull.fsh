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
in vec2 texCoord1;
in vec4 normal;
in float marker;
flat in mat4 mvp;

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

vec4 encodeFloat(float v) {
    v *= 40000.0;
    v = floor(v);
    return encodeInt(int(v));
}

void main() {
    if (marker == 1.0) {
        fragColor = vec4(1.0);
        vec2 pixel = floor(gl_FragCoord.xy);
        if (pixel.y >= 1.0 || pixel.x >= 32.0) {
            discard;
        }

        if (pixel.x < 16) {
            int index = int(pixel.x);
            float value = mvp[index / 4][index % 4];
            fragColor = encodeFloat(value);
        } else {
            int index = int(pixel.x) - 16;
            float value = ProjMat[index / 4][index % 4];
            fragColor = encodeFloat(value);
        }
        return;
    }

    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}
