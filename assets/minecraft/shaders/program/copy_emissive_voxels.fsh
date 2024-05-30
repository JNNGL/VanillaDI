#version 150

uniform sampler2D DiffuseSampler;
uniform vec2 InSize;
uniform vec2 OutSize;

out vec4 fragColor;

void main() {
    vec2 screenPos = floor(gl_FragCoord.xy) / OutSize;
    ivec2 coord = ivec2(round(screenPos * InSize));
    vec4 color = texelFetch(DiffuseSampler, coord, 0);
    if (color.a == 249.0 / 255.0) {
        fragColor = vec4(color.rgb, 1.0);
    } else {
        fragColor = vec4(0.0);
    }
}