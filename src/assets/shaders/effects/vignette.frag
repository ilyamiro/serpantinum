#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 vignetteColor;
    vec4 params;
};

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    float dist = length(p);
    float maxDim = max(itemSize.x, itemSize.y);
    float outerRadius = maxDim * (params.y > 0.0 ? params.y : 0.75);
    float innerRadius = outerRadius * (params.x > 0.0 ? params.x : 0.4);
    float maxAlpha = params.z > 0.0 ? params.z : 0.4;

    float t = clamp((dist - innerRadius) / max(outerRadius - innerRadius, 1.0), 0.0, 1.0);
    float a = t * maxAlpha * vignetteColor.a * qt_Opacity;

    fragColor = vec4(vignetteColor.rgb * a, a);
}
