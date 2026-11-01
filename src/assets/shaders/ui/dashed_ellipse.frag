#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 radii;
    vec2 dash;
    float lineWidth;
    vec4 color;
};

const float TAU = 6.283185307179586;
const int STEPS = 32;

float arcLength(float t) {
    float h = t / float(STEPS);
    float acc = 0.0;
    for (int i = 0; i < STEPS; i++) {
        float m = (float(i) + 0.5) * h;
        float sx = radii.x * sin(m);
        float cy = radii.y * cos(m);
        acc += sqrt(sx * sx + cy * cy);
    }
    return acc * h;
}

void main() {
    vec2 d = qt_TexCoord0 * itemSize - itemSize * 0.5;
    vec2 q = d / radii;
    float ql = length(q);
    if (ql < 1e-4) {
        fragColor = vec4(0.0);
        return;
    }

    float grad = length(d / (radii * radii)) / ql;
    float perp = (ql - 1.0) / grad;
    float halfLine = lineWidth * 0.5;
    if (abs(perp) > halfLine + dash.x + 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    float t = atan(q.y, q.x);
    if (t < 0.0) t += TAU;

    float period = dash.x + dash.y;
    float s = arcLength(t);
    float uc = mod(s - dash.x * 0.5 + period * 0.5, period) - period * 0.5;
    float along = max(abs(uc) - dash.x * 0.5, 0.0);
    float dist = length(vec2(along, perp)) - halfLine;

    float alpha = clamp(0.5 - dist, 0.0, 1.0) * color.a * qt_Opacity;
    fragColor = vec4(color.rgb * alpha, alpha);
}
