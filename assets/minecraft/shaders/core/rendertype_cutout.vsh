#version 150

#moj_import <light.glsl>
#moj_import <fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;
uniform int FogShape;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec4 normal;
out vec4 position0;
out vec4 position1;
out vec4 position2;
out vec4 position3;
out vec3 uv0;
out vec3 uv1;
out vec3 uv2;
out vec3 uv3;

void main() {
    vec3 pos = Position + ChunkOffset;
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

    vertexDistance = fog_distance(ModelViewMat, pos, FogShape);
    vertexColor = Color * minecraft_sample_lightmap(Sampler2, UV2);
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);

    position0 =
    position1 =
    position2 =
    position3 = vec4(0.0);

    uv0 = 
    uv1 = 
    uv2 = 
    uv3 = vec3(0.0);

    switch (gl_VertexID % 4) {
        case 0: position0 = vec4(Position, 1.0); uv0 = vec3(UV0, 1.0); break;
        case 1: position1 = vec4(Position, 1.0); uv1 = vec3(UV0, 1.0); break;
        case 2: position2 = vec4(Position, 1.0); uv2 = vec3(UV0, 1.0); break;
        case 3: position3 = vec4(Position, 1.0); uv3 = vec3(UV0, 1.0); break;
    }
}