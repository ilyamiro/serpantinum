#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accentColor;
};

layout(binding = 1) uniform sampler2D source;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    if (c.a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float l = dot(c.rgb / c.a, LUMA);
    vec3 accent = accentColor.rgb;
    float la = clamp(dot(accent, LUMA), 0.001, 0.999);
    vec3 tone = l <= la
        ? accent * (l / la)
        : mix(accent, vec3(1.0), (l - la) / (1.0 - la));
    fragColor = vec4(tone * c.a, c.a) * qt_Opacity;
}
