#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float reveal;
    float phase;
    vec4 color0;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    vec4 color4;
    vec4 params;
};

const float PI = 3.141592653589793;

vec4 layer(vec4 accum, vec4 color, float i, float amp, vec2 p, float t, float b1, float b2, float baseAmp) {
    float prog = clamp((reveal - i * 0.05) * 2.5, 0.0, 1.0);
    if (prog <= 0.0) return accum;
    if (prog >= 1.0) return color;

    float currentX = itemSize.x * prog;
    float waveAmp = baseAmp * sin(prog * PI) * amp;
    float offset = i * 0.5;
    float cp1x = currentX + sin(phase + offset) * waveAmp;
    float cp2x = currentX - cos(phase + offset) * waveAmp;

    float surfaceX = (1.0 - t)*(1.0 - t)*(1.0 - t)*currentX + b1 * cp1x + b2 * cp2x + t*t*t*currentX;
    float edge = clamp(0.5 - (p.x - surfaceX), 0.0, 1.0);

    return mix(accum, color, edge);
}

void main() {
    if (reveal <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    float t = clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0);
    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;
    float baseAmp = params.x > 0.0 ? params.x : 45.0;

    // GLSL ES 1.00, the variant Qt uses on NVIDIA, has no array constructors,
    // so each of the five layers is a call to layer() instead of a loop over arrays.
    vec4 accum = vec4(0.0);
    accum = layer(accum, color0, 0.0, 1.8, p, t, b1, b2, baseAmp);
    accum = layer(accum, color1, 1.0, 1.5, p, t, b1, b2, baseAmp);
    accum = layer(accum, color2, 2.0, 1.2, p, t, b1, b2, baseAmp);
    accum = layer(accum, color3, 3.0, 0.9, p, t, b1, b2, baseAmp);
    accum = layer(accum, color4, 4.0, 0.6, p, t, b1, b2, baseAmp);

    fragColor = accum * qt_Opacity;
}
