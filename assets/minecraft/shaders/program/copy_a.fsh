#version 150

uniform sampler2D DiffuseSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    fragColor = texture(DiffuseSampler, texCoord);
    fragColor.rgb *= fragColor.a;
    fragColor.rgb = vec3(fragColor.a);
    fragColor.a = 1.0;
}