#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 entityTexCoord;
layout (location = 2) in vec4 entityColor;
layout (location = 3) in vec3 barycentricCoord;
layout (location = 4) in vec2 edgeCoord;
layout (location = 5) in mat4 attribTransform;

out vec3 eColor;
out vec2 TexCoord;
out vec3 barycentric;
out vec2 edge;

uniform mat4 projection;

layout(std140) uniform ViewMatrixBlock {
    mat4 viewMatrix;
};

void main()
{
    gl_Position = projection * viewMatrix * attribTransform * vec4(position.xyz, 1.0);
    eColor = vec3(1.0f, 1.0f, 1.0f);
    TexCoord = entityTexCoord;
    barycentric = barycentricCoord;
    edge = edgeCoord;
}