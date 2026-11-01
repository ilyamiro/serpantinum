#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 accentColor;
    vec4 cfg1;
    vec4 cfg2;
    vec4 params;
};

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 center = itemSize * 0.5;
    vec2 d = p - center;
    float dist = length(d);
    float baseRadius = min(center.x, center.y) * 0.72;

    float theta = atan(d.y, d.x);

    // Shape 1
    float r1 = 1.0 + cfg1.y * cos(cfg1.x * theta);
    vec2 scale1 = vec2(cfg1.z > 0.0 ? cfg1.z : 1.0, cfg1.w > 0.0 ? cfg1.w : 1.0);
    float effR1 = baseRadius * r1 * length(vec2(cos(theta) * scale1.x, sin(theta) * scale1.y));

    // Shape 2
    float r2 = 1.0 + cfg2.y * cos(cfg2.x * theta);
    vec2 scale2 = vec2(cfg2.z > 0.0 ? cfg2.z : 1.0, cfg2.w > 0.0 ? cfg2.w : 1.0);
    float effR2 = baseRadius * r2 * length(vec2(cos(theta) * scale2.x, sin(theta) * scale2.y));

    float morphProgress = clamp(params.x, 0.0, 1.0);
    float targetR = mix(effR1, effR2, morphProgress);

    float alpha = clamp(0.5 - (dist - targetR), 0.0, 1.0) * accentColor.a * qt_Opacity;
    fragColor = vec4(accentColor.rgb * alpha, alpha);
}
