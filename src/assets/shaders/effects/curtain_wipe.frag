#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float reveal;
    float s28;
    vec4 color0;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    vec4 color4;
};

const float PI = 3.141592653589793;

vec4 layer(vec4 accum, vec4 color, float i, float amp, vec2 p, float t, float b1, float b2, float phase) {
    float prog = (reveal - i * 0.07) * 1.55;
    if (prog <= 0.0) return accum;
    if (prog >= 1.0) return color;

    float smoothProg = pow(prog, 1.4);
    float currentY = itemSize.y * smoothProg;
    float waveAmp = s28 * sin(smoothProg * PI) * amp;
    float offset = i * 0.5;
    float cp1y = currentY + sin(phase + offset) * waveAmp;
    float cp2y = currentY - cos(phase + offset) * waveAmp;

    float surfaceY = (1.0 - t)*(1.0 - t)*(1.0 - t)*currentY + b1 * cp1y + b2 * cp2y + t*t*t*currentY;
    float edge = clamp(0.5 - (p.y - surfaceY), 0.0, 1.0);

    return mix(accum, color, edge);
}

void main() {
    if (reveal <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    float t = clamp(p.x / max(itemSize.x, 1.0), 0.0, 1.0);
    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;
    float phase = reveal * 7.853981633974483;

    // GLSL ES 1.00, the variant Qt uses on NVIDIA, has no array constructors,
    // so each of the five layers is a call to layer() instead of a loop over arrays.
    vec4 accum = vec4(0.0);
    accum = layer(accum, color0, 0.0, 1.5, p, t, b1, b2, phase);
    accum = layer(accum, color1, 1.0, 1.3, p, t, b1, b2, phase);
    accum = layer(accum, color2, 2.0, 1.1, p, t, b1, b2, phase);
    accum = layer(accum, color3, 3.0, 0.9, p, t, b1, b2, phase);
    accum = layer(accum, color4, 4.0, 0.6, p, t, b1, b2, phase);

    fragColor = accum * qt_Opacity;
}
