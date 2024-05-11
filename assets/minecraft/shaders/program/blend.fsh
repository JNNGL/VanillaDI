#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D LightSampler;

uniform vec2 InSize;

in vec2 texCoord;

out vec4 fragColor;

vec3 acesFilm(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0., 1.);
}

vec3 decodeHdr(vec4 color) {
    if (color.a == 0.0) return vec3(0.0);
    return color.rgb * (1.0 / color.a);
}

void main() {
    vec4 color = texture(DiffuseSampler, texCoord);
    vec3 light = decodeHdr(texture(LightSampler, texCoord));
    color.rgb *= (1.0 + light);
    color.rgb = acesFilm(color.rgb);
    fragColor = color;
}