#version 150

flat in uint packedEntries0[16];
flat in uint packedEntries1[16];
flat in uint packedEntries2[16];
flat in uint packedEntries3[16];
flat in int numEntries;

out vec4 fragColor;

void main() {
    int index = int(floor(gl_FragCoord.x));
    if (index >= 64) {
        fragColor = vec4(numEntries == 0 ? 0.0 : 1.0, float(numEntries - 1) / 255.0, 0.0, 1.0);
        return;
    }

    uint entry = 0u;
    switch (index / 16) {
        case 0: entry = packedEntries0[index % 16]; break;
        case 1: entry = packedEntries1[index % 16]; break;
        case 2: entry = packedEntries2[index % 16]; break;
        case 3: entry = packedEntries3[index % 16]; break;
    }
    uint r = entry & 0xFFu;
    uint g = (entry >> 8) & 0xFFu;
    uint b = (entry >> 16) & 0xFFu;
    uint a = (entry >> 24) & 0xFFu;
    fragColor = vec4(r, g, b, a) / 255.0;
}