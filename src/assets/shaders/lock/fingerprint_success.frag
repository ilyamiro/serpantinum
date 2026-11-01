#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 accentColor;
    vec4 params;
};

const float TAU = 6.28318530718;

float hash(float n) {
    return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float easeOut(float t) {
    return 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 3.0);
}

float sdSeg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

vec4 over(vec4 acc, vec3 c, float a) {
    a = clamp(a, 0.0, 1.0);
    return vec4(c * a + acc.rgb * (1.0 - a), a + acc.a * (1.0 - a));
}

void main() {
    float m = min(itemSize.x, itemSize.y);
    float scaleK = params.y;
    vec2 p = (qt_TexCoord0 * itemSize - itemSize * 0.5) / m * scaleK;
    float aa = scaleK / m;
    float t = clamp(params.x, 0.0, 1.0);
    float len = length(p);

    vec3 base = accentColor.rgb;
    vec3 light = mix(base, vec3(1.0), 0.55);
    vec4 acc = vec4(0.0);

    float inner = 0.31;
    float te = easeOut(t);
    float r1 = inner + 0.5 * te;
    float w1 = 0.026 * (1.0 - t) + 0.004;
    float f1 = pow(1.0 - t, 1.7);
    acc = over(acc, base, exp(-pow((len - r1) / (w1 * 2.2), 2.0)) * f1 * 0.35);
    acc = over(acc, light, smoothstep(w1 + aa, w1 - aa, abs(len - r1)) * f1 * 0.9);

    float t2 = clamp((t - 0.08) / 0.92, 0.0, 1.0);
    float r2 = inner + 0.34 * easeOut(t2);
    float f2 = pow(1.0 - t2, 2.0) * step(0.08, t);
    acc = over(acc, light, smoothstep(0.008 + aa, 0.008 - aa, abs(len - r2)) * f2 * 0.6);

    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float a = fi / 16.0 * TAU + hash(fi) * 0.5;
        float v = 0.28 + 0.42 * hash(fi + 31.0);
        float delay = 0.04 * hash(fi + 7.0);
        float pt = clamp((t - delay) / (1.0 - delay), 0.0, 1.0);
        float head = inner + 0.02 + v * easeOut(pt);
        float tail = inner + 0.02 + v * easeOut(max(pt - 0.12, 0.0));
        vec2 dir = vec2(cos(a), sin(a));
        vec2 grav = vec2(0.0, 0.1 * pt * pt);
        vec2 ph = dir * head + grav;
        vec2 pt0 = dir * tail + grav * 0.7;
        float wd = (0.006 + 0.01 * hash(fi + 13.0)) * (1.0 - pt);
        float d = sdSeg(p, pt0, ph) - wd;
        float tw = 0.65 + 0.35 * sin(pt * 22.0 + hash(fi + 3.0) * 6.0);
        float fade = (1.0 - pt) * smoothstep(0.0, 0.05, pt);
        vec3 c = mix(base, vec3(1.0), 0.35 + 0.5 * hash(fi + 5.0));
        acc = over(acc, c, smoothstep(aa, -aa, d) * fade * tw);
        acc = over(acc, base, exp(-max(d, 0.0) * 45.0) * fade * 0.18);
    }

    float outside = smoothstep(inner - aa * 2.0, inner + aa * 2.0, len);
    acc *= outside;

    fragColor = acc * accentColor.a * qt_Opacity;
}
