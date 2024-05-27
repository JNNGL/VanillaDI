#version 150

uniform sampler2D DiffuseSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    if (texture(DiffuseSampler, texCoord).a == 250.0 / 255.0) {
        ivec2 coord = ivec2(gl_FragCoord.xy);
        ivec2 offset = coord % 2;
        vec4 sample;
        if (offset.x == offset.y) {
            sample = vec4(0.0);
            ivec2 offsets[] = ivec2[](ivec2(1, 0), ivec2(0, 1), ivec2(-1, 0), ivec2(0, -1));
            for (int i = 0; i < 4; i++) {
                ivec2 offset = offsets[i];
                ivec2 sampleCoord = coord + offset;
                vec4 data = texelFetch(DiffuseSampler, sampleCoord, 0);
                if (data.a == 250.0 / 255.0) {
                    sample = data;
                    sample.a = 1.0;
                    break;
                }
            }
        } else {
            sample = texelFetch(DiffuseSampler, coord, 0);
            sample.a = 1.0;
        }

        fragColor = sample;
    } else {
        fragColor = vec4(0.0);
    }
}