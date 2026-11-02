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

layout(binding = 1) uniform sampler2D source;

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;
const float STAGGER = 0.079;
const float SPEED = 1.65;

float layerDist(float i, vec2 p, float u, float phase, out bool started, out bool finished) {
    float prog = (reveal - i * STAGGER) * SPEED;
    started = prog > 0.0;
    finished = prog >= 1.0;
    if (!started || finished) return 0.0;

    float smoothProg = mix(prog, prog * prog * (3.0 - 2.0 * prog), 0.5);
    float currentY = itemSize.y * smoothProg;
    float envelope = pow(sin(smoothProg * PI), 0.7);
    float amp = s28 * 2.0 * envelope * (1.0 - i * 0.05);

    float f1 = 1.1 + i * 0.17;
    float f2 = 2.3 + i * 0.29;
    float ph1 = phase * (1.0 + i * 0.15) + i * 1.7;
    float ph2 = -phase * 1.4 + i * 2.9;
    float wave = sin(u * TAU * f1 + ph1) * 0.62 + sin(u * TAU * f2 + ph2) * 0.38;

    return p.y - (currentY + wave * amp);
}

vec4 shade(vec4 accum, float d) {
    float shadow = 0.24 * exp(-max(d, 0.0) / max(s28 * 0.9, 1.0)) * step(0.0, d);
    accum.rgb *= 1.0 - shadow;
    return accum;
}

vec4 layer(vec4 accum, vec4 color, float i, vec2 p, float u, float phase) {
    bool started;
    bool finished;
    float d = layerDist(i, p, u, phase, started, finished);
    if (!started) return accum;
    if (finished) return color;

    accum = shade(accum, d);

    float crest = 0.07 * exp(-max(-d, 0.0) / max(s28 * 0.3, 1.0)) * step(d, 0.0);
    vec4 lit = vec4(min(color.rgb + crest * color.a, vec3(color.a)), color.a);

    float edge = clamp(0.5 - d, 0.0, 1.0);
    return mix(accum, lit, edge);
}

vec4 opening(vec4 accum, float i, vec2 p, float u, float phase) {
    bool started;
    bool finished;
    float d = layerDist(i, p, u, phase, started, finished);
    if (!started) return accum;
    if (finished) return vec4(0.0);

    accum = shade(accum, d);

    float edge = clamp(0.5 - d, 0.0, 1.0);
    return accum * (1.0 - edge);
}

void main() {
    vec4 accum = texture(source, qt_TexCoord0);
    if (reveal <= 0.0) {
        fragColor = accum * qt_Opacity;
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    float u = p.x / max(itemSize.x, 1.0);
    float phase = reveal * 9.0;

    accum = layer(accum, color0, 0.0, p, u, phase);
    accum = layer(accum, color1, 1.0, p, u, phase);
    accum = layer(accum, color2, 2.0, p, u, phase);
    accum = layer(accum, color3, 3.0, p, u, phase);
    accum = layer(accum, color4, 4.0, p, u, phase);
    accum = opening(accum, 5.0, p, u, phase);

    fragColor = accum * qt_Opacity;
}
