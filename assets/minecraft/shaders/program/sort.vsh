#version 150

uniform sampler2D DiffuseSampler;

flat out uint packedEntries0[16];
flat out uint packedEntries1[16];
flat out uint packedEntries2[16];
flat out uint packedEntries3[16];
flat out int numEntries;

const vec4[] corners = vec4[](
    vec4(-1, -1, 0, 1),
    vec4(1, -1, 0, 1),
    vec4(1, 1, 0, 1),
    vec4(-1, 1, 0, 1)
);

void main() {
    vec4 outPos = corners[gl_VertexID];
    gl_Position = outPos;

    for (int i = 0; i < 16; i++) {
        packedEntries0[i] = 0u;
        packedEntries1[i] = 0u;
        packedEntries2[i] = 0u;
        packedEntries3[i] = 0u;
    }

    int entryIndex = 0;
    for (int i = 0; i < 256; i++) {
        int base = 36 + i * 12;
        vec4 marker = texelFetch(DiffuseSampler, ivec2(base + 11, 0), 0);
        if (ivec3(round(marker.rgb * 255.0)) != ivec3(90, 255, 0)) {
            continue;
        }

        int packedIndex = entryIndex / 4;
        int shift = (entryIndex % 4) * 8;
        switch (packedIndex / 16) {
            case 0: packedEntries0[packedIndex % 16] |= uint(i) << shift; break;
            case 1: packedEntries1[packedIndex % 16] |= uint(i) << shift; break;
            case 2: packedEntries2[packedIndex % 16] |= uint(i) << shift; break;
            case 3: packedEntries3[packedIndex % 16] |= uint(i) << shift; break;
        }
        entryIndex++;
    }

    numEntries = entryIndex;
}