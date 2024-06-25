#version 150

uniform sampler2D DiffuseSampler;

out vec4 fragColor;

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);

    bool found = false;
    for (int f = 0; f < 16; f++) {
        if (texelFetch(DiffuseSampler, ivec2(coord.x * 16 + f, coord.y), 0) != vec4(0.0)) {
            found = true;
            break;
        }
    }

    fragColor = found ? vec4(1.0) /* TODO: Store distance field here */ : vec4(0.0);
}