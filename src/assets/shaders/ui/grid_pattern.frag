#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float stepSize;
    float lineWidth;
    vec4 lineColor;
};

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float stepS = stepSize > 0.0 ? stepSize : 16.0;
    float lw = lineWidth > 0.0 ? lineWidth : 1.0;

    vec2 gridMod = mod(p, stepS);
    float dx = min(gridMod.x, stepS - gridMod.x);
    float dy = min(gridMod.y, stepS - gridMod.y);

    float d = min(dx, dy) - (lw * 0.5);
    float lineAlpha = clamp(0.5 - d, 0.0, 1.0) * lineColor.a * qt_Opacity;

    fragColor = vec4(lineColor.rgb * lineAlpha, lineAlpha);
}
