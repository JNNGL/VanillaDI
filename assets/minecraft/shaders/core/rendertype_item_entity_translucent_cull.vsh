#version 150

#moj_import <light.glsl>
#moj_import <fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in vec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;
uniform int FogShape;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord1;
out vec2 texCoord2;
out vec4 normal;
out float marker;
flat out mat4 mvp;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    marker = texture(Sampler0, UV0).rgb == vec3(76, 195, 86) / 255 ? 1.0 : 0.0;

    vertexDistance = fog_distance(ModelViewMat, IViewRotMat * Position, FogShape);
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color) * texelFetch(Sampler2, UV2 / 16, 0);
    texCoord0 = UV0;
    texCoord1 = UV1;
    texCoord2 = UV2;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);

    if (marker == 1.0) {
        vec2 bottomLeftCorner = vec2(-1.0);
        vec2 topRightCorner = vec2(0.0);
        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(bottomLeftCorner.x, topRightCorner.y,   0, 1); break;
            case 1: gl_Position = vec4(bottomLeftCorner.x, bottomLeftCorner.y, 0, 1); break;
            case 2: gl_Position = vec4(topRightCorner.x,   bottomLeftCorner.y, 0, 1); break;
            case 3: gl_Position = vec4(topRightCorner.x,   topRightCorner.y,   0, 1); break;
        }

        mvp = ProjMat * mat4(transpose(IViewRotMat));
    }
}
