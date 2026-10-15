#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float mouth;
    vec4 bodyColor;
    vec4 eyeColor;
};

const float PI = 3.141592653589793;

void main() {
    float r = itemSize.x * 0.5;
    vec2 p = qt_TexCoord0 * itemSize - vec2(r);

    float m = mouth * PI;
    vec2 q = vec2(p.x, abs(p.y));
    vec2 dir = vec2(cos(m), sin(m));
    float mouthDist = dot(q, dir) > 0.0 ? (q.y * dir.x - q.x * dir.y) : length(q);

    float body = max(length(p) - (r - 0.5), -mouthDist);
    float bodyA = clamp(0.5 - body, 0.0, 1.0);

    vec2 eye = vec2(r * 0.12, -r * 0.46);
    float eyeR = max(1.5, r * 0.14);
    float eyeA = clamp(0.5 - (length(p - eye) - eyeR), 0.0, 1.0);

    vec4 base = vec4(bodyColor.rgb * bodyColor.a, bodyColor.a) * bodyA;
    vec4 pupil = vec4(eyeColor.rgb * eyeColor.a, eyeColor.a) * eyeA;
    fragColor = (pupil + base * (1.0 - pupil.a)) * qt_Opacity;
}
