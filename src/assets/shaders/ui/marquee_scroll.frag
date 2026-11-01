#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 srcSize;
    float offset;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float x = (qt_TexCoord0.x * itemSize.x + offset) / srcSize.x;
    fragColor = texture(source, vec2(x, qt_TexCoord0.y)) * qt_Opacity;
}
