#version 150

uniform sampler2D DiffuseSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    if (texture(DiffuseSampler, texCoord).a == 250.0 / 255.0) {
        ivec2 coord = ivec2(gl_FragCoord.xy + 1);
        ivec2 offset = coord % 2;
        ivec2 baseCoord = coord - offset;
        ivec2 nextCoord = coord + offset;
        vec4 baseSample = texelFetch(DiffuseSampler, baseCoord - 1, 0);
        vec4 nextSample = texelFetch(DiffuseSampler, nextCoord - 1, 0);
        vec4 sample = vec4(0.0);
        float alpha = 1.0;
        if (baseSample.a == 250.0 / 255.0) { sample = baseSample; alpha = 0.5; }
        if (nextSample.a == 250.0 / 255.0) sample = mix(sample, nextSample, alpha);
        fragColor = vec4(sample.rgb, 1.0);
    } else {
        fragColor = vec4(0.0);
    }
}