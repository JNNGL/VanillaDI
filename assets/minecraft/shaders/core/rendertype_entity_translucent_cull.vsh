#version 150

#moj_import <light.glsl>
#moj_import <fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform int FogShape;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;

out float vertexDistance;
out vec4 vertexColor;
out vec4 lightMapColor;
out vec4 overlayColor;
out vec2 texCoord0;
out vec4 normal;
out float marker;
flat out int type;
out vec4 position0;
out vec4 position1;
flat out int index;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    vec4 col = texture(Sampler0, UV0);
    marker = col.rg == vec2(195, 76) / 255 ? 1.0 : 0.0;
    type = 0;
    index = int(Color.b * 255);

    position0 = position1 = vec4(0.0);

    vertexDistance = fog_distance(Position, FogShape);
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color);
    lightMapColor = texelFetch(Sampler2, UV2 / 16, 0);
    overlayColor = texelFetch(Sampler1, UV1, 0);
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);

    if (marker == 1.0) {
        vec3 worldSpace = Position;
        switch (gl_VertexID % 4) {
            case 0: position0 = vec4(worldSpace, 1.0); break;
            case 2: position1 = vec4(worldSpace, 1.0); break;
        }

        // TODO: better vertex positions
        vec2 bottomLeftCorner = vec2(-1.0);
        vec2 topRightCorner = vec2(1.0, 0.1);
        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(bottomLeftCorner.x, topRightCorner.y,   0, 1); break;
            case 1: gl_Position = vec4(bottomLeftCorner.x, bottomLeftCorner.y, 0, 1); break;
            case 2: gl_Position = vec4(topRightCorner.x,   bottomLeftCorner.y, 0, 1); break;
            case 3: gl_Position = vec4(topRightCorner.x,   topRightCorner.y,   0, 1); break;
        }
    }
}
