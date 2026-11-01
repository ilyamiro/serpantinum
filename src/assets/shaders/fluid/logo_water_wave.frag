#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float fillLevel;
    float wavePhase;
    vec4 baseColor;
    vec4 params;
};

const float PI = 3.141592653589793;

vec4 layer(vec4 accum, float k, float amp, float darken, vec2 p, float s16) {
    float prog = clamp((fillLevel - k * 0.15) * 1.25, 0.0, 1.0);
    if (prog <= 0.0) return accum;

    vec4 col = vec4(baseColor.rgb / darken, baseColor.a);
    if (prog >= 1.0) return col;

    float fillY = itemSize.y * (1.0 - prog);
    float baseAmp = s16 * sin(prog * PI) * amp;
    float localPhase = wavePhase + k * 0.5;

    float waveHeight = 0.0;
    for (int w = 1; w <= 3; ++w) {
        float freq = float(w) * 1.5;
        float a = baseAmp * (1.0 - float(w - 1) * 0.3);
        waveHeight += sin(localPhase * freq + p.x * 0.01 * freq) * a;
    }

    float surfaceY = fillY + waveHeight * 0.6;
    float edge = clamp(0.5 - (surfaceY - p.y), 0.0, 1.0);

    return mix(accum, col, edge);
}

void main() {
    if (fillLevel <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    float s16 = params.x > 0.0 ? params.x : 16.0;

    // GLSL ES 1.00, the variant Qt uses on NVIDIA, has no array constructors,
    // so each of the five layers is a call to layer() instead of a loop over arrays.
    vec4 accum = vec4(0.0);
    accum = layer(accum, 0.0, 1.8, 2.5, p, s16);
    accum = layer(accum, 1.0, 1.5, 2.0, p, s16);
    accum = layer(accum, 2.0, 1.2, 1.5, p, s16);
    accum = layer(accum, 3.0, 0.9, 1.1, p, s16);
    accum = layer(accum, 4.0, 0.6, 1.0, p, s16);

    fragColor = accum * qt_Opacity;
}
