#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 feather;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 h = itemSize * 0.5;
    vec2 edge = h - abs(qt_TexCoord0 * itemSize - h);
    float ax = smoothstep(0.0, max(feather.x, 1.0), edge.x);
    float ay = smoothstep(0.0, max(feather.y, 1.0), edge.y);
    fragColor = texture(source, qt_TexCoord0) * (ax * ay * qt_Opacity);
}
