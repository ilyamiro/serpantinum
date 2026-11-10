#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 origin;
    float smoothing;
    float dpr;
    float fillAlpha;
    vec4 s0;
    vec4 s1;
    vec4 s2;
    vec4 s3;
    vec4 s4;
    vec4 s5;
    vec4 r0;
    vec4 r1;
    vec4 r2;
    vec4 r3;
    vec4 r4;
    vec4 r5;
    vec4 k0;
    vec4 k1;
    vec4 o0;
    vec4 o1;
};

layout(binding = 1) uniform sampler2D src;

float sdShape(vec2 p, vec4 s, vec4 radii) {
    if (s.z <= 0.0 || s.w <= 0.0) return 1e9;
    vec2 h = s.zw * 0.5;
    vec2 q = p - (s.xy + h);
    float r = q.x < 0.0 ? (q.y < 0.0 ? radii.x : radii.w) : (q.y < 0.0 ? radii.y : radii.z);
    r = min(r, min(h.x, h.y));
    vec2 d = abs(q) - h + r;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 p = origin + qt_TexCoord0 * itemSize;

    float d[6];
    d[0] = sdShape(p, s0, r0);
    d[1] = sdShape(p, s1, r1);
    d[2] = sdShape(p, s2, r2);
    d[3] = sdShape(p, s3, r3);
    d[4] = sdShape(p, s4, r4);
    d[5] = sdShape(p, s5, r5);

    float kk[6];
    kk[0] = k0.x;
    kk[1] = k0.y;
    kk[2] = k0.z;
    kk[3] = k0.w;
    kk[4] = k1.x;
    kk[5] = k1.y;
    float oo[6];
    oo[0] = o0.x;
    oo[1] = o0.y;
    oo[2] = o0.z;
    oo[3] = o0.w;
    oo[4] = o1.x;
    oo[5] = o1.y;
    float tt[6];
    tt[0] = min(s0.z, s0.w);
    tt[1] = min(s1.z, s1.w);
    tt[2] = min(s2.z, s2.w);
    tt[3] = min(s3.z, s3.w);
    tt[4] = min(s4.z, s4.w);
    tt[5] = min(s5.z, s5.w);

    float mine = 1e9;
    float up = 1e9;
    for (int i = 0; i < 6; i++) {
        if (oo[i] < 1.5) mine = min(mine, d[i]);
        if (oo[i] > 0.5 && oo[i] < 1.5) up = min(up, d[i]);
    }
    for (int i = 0; i < 6; i++) {
        for (int j = i + 1; j < 6; j++) {
            if (oo[i] > 1.5 || oo[j] > 1.5) continue;
            float k = min(max(kk[i], kk[j]), min(tt[i], tt[j]));
            if (k > 0.0 && max(d[i], d[j]) < k)
                mine = min(mine, smin(d[i], d[j], k));
        }
    }

    float c = max(clamp(0.5 - mine * dpr, 0.0, 1.0) - clamp(0.5 - up * dpr, 0.0, 1.0), 0.0);
    float cover = c * (1.0 - fillAlpha) / max(1.0 - c * fillAlpha, 0.0001);
    fragColor = texture(src, qt_TexCoord0) * (cover * qt_Opacity);
}
