#version 150

#define X_RESOLUTION 1280
#define Y_RESOLUTION 720

#moj_import <light.glsl>
#moj_import <fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;
uniform int FogShape;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec4 normal;
out vec3 position;
out float emissiveQuad;
out vec3 emissiveData;
out vec4 glPos;
flat out vec2 voxelCoord;

void main() {
    vec3 pos = Position + ChunkOffset;
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

    vec4 col = texture(Sampler0, UV0);
    emissiveQuad = col.a == 249.0 / 255.0 ? 1.0 : 0.0;
    emissiveData = col.rgb;

    vertexDistance = fog_distance(ModelViewMat, pos, FogShape);
    vertexColor = Color * minecraft_sample_lightmap(Sampler2, UV2);
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);

    position = pos;

    if (emissiveQuad > 0.0) {
        const int checkeredWidth = int(X_RESOLUTION) / 2;
        const int checkeredHeight = int(Y_RESOLUTION) / 2;
        const int freeY = checkeredHeight - 1;
        const int totalBlocks = int(checkeredWidth * freeY);
        const int renderDistance = (int(floor(pow(float(totalBlocks), 1.0 / 3.0))) - 1) / 2;
        const int range = renderDistance * 2;
        const vec2 screenSize = vec2(X_RESOLUTION, Y_RESOLUTION);

        ivec3 blockPos = ivec3(floor(Position + floor(ChunkOffset)));

        int linearIndex = (blockPos.z + renderDistance) * range * range + (blockPos.y + renderDistance) * range + (blockPos.x + renderDistance);
        ivec2 screenPos = ivec2(linearIndex % checkeredWidth, linearIndex / checkeredWidth + 1) * 2;

        vec2 bottomLeftCorner = (screenPos - 2.0) / screenSize * 2.0 - 1.0;
        vec2 topRightCorner = (screenPos + 2.0) / screenSize * 2.0 - 1.0;
        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(bottomLeftCorner.x, topRightCorner.y,   0, 1); break;
            case 1: gl_Position = vec4(bottomLeftCorner.x, bottomLeftCorner.y, 0, 1); break;
            case 2: gl_Position = vec4(topRightCorner.x,   bottomLeftCorner.y, 0, 1); break;
            case 3: gl_Position = vec4(topRightCorner.x,   topRightCorner.y,   0, 1); break;
        }

        voxelCoord = vec2(screenPos) / screenSize;
    }

    glPos = gl_Position;
}