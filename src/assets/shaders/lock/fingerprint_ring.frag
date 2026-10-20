#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 accentColor;
    vec4 params;
    vec4 cfg;
};

const float TAU = 6.28318530718;

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

vec4 orbit(vec2 p, float time, float fill, float burst, float live, float speed, float aa) {
    float R = 0.30;
    float len = length(p);
    float th = atan(p.y, p.x);
    float d = abs(len - R);

    float disc = smoothstep(R + 0.07 + aa * 2.0, R + 0.07 - aa * 2.0, len);
    float rim = smoothstep(0.012 + aa * 3.0, 0.0, abs(len - (R + 0.07)));
    float body = disc * 0.07 + rim * 0.08;
    float inner = smoothstep(R - 0.07 + aa * 3.0, R - 0.07 - aa * 3.0, len) * disc * 0.05;

    float w = 0.017;
    float track = smoothstep(w + aa * 1.5, w - aa * 1.5, d) * 0.14;

    float head = time * speed;
    float behind = mod(head - th, TAU) / TAU;
    float tail = pow(max(1.0 - behind * 1.15, 0.0), 2.2);
    float cometW = w * (0.55 + 0.45 * tail);
    float comet = smoothstep(cometW + aa * 1.5, cometW - aa * 1.5, d) * tail * live * (1.0 - fill);
    float glow = exp(-d * 55.0) * tail * 0.32 * live * (1.0 - fill);

    vec2 hp = vec2(cos(head), sin(head)) * R;
    float hd = length(p - hp);
    float bloom = exp(-hd * 38.0) * 0.55 * live * (1.0 - fill);

    float prog = mod(th + 1.57079632679, TAU) / TAU;
    float edge = smoothstep(fill, fill - 0.01, prog) * step(0.001, fill);
    float filled = smoothstep(w * 1.2 + aa * 1.5, w * 1.2 - aa * 1.5, d) * edge;
    float filledGlow = exp(-d * 45.0) * edge * 0.25;

    float wave = 0.0;
    if (burst > 0.0 && burst < 1.0) {
        float rr = R + burst * 0.16;
        wave = exp(-pow((len - rr) * 38.0, 2.0)) * (1.0 - burst) * (1.0 - burst) * 0.6;
    }

    float a = clamp(track + comet + glow + bloom + filled + filledGlow + wave + body + inner, 0.0, 1.0);
    float hl = clamp(comet * 0.25 + bloom * 0.8 + filled * 0.15, 0.0, 1.0);
    return vec4(mix(accentColor.rgb, vec3(1.0), hl), a);
}

vec4 liquid(vec2 p, float time, float fill, float burst, float live, float speed, float aa) {
    float t = time * speed;
    float len = length(p);
    float th = atan(p.y, p.x);

    float amp = mix(0.35, 1.0, live) * (1.0 + 2.6 * sin(clamp(burst, 0.0, 1.0) * 3.14159265));
    float R = 0.30 * (1.0 + 0.1 * sin(clamp(burst, 0.0, 1.0) * 3.14159265)) + 0.012 * sin(t * 1.1);
    float wob = 0.020 * sin(2.0 * th + t * 0.9)
              + 0.014 * sin(3.0 * th - t * 1.3 + 1.7)
              + 0.009 * sin(5.0 * th + t * 1.9 + 4.1);
    float r = R + wob * amp;

    float prog = mod(th + 1.57079632679, TAU) / TAU;
    float edge = smoothstep(fill, fill - 0.015, prog) * step(0.001, fill);
    float w = 0.0075 + 0.0055 * (0.5 + 0.5 * sin(3.0 * th - t * 1.1)) + 0.009 * edge;

    float dRing = abs(len - r) - w;
    float dist = dRing;

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float a = t * (0.32 + 0.11 * fi) + fi * 2.1;
        float off = sin(t * (0.55 + 0.2 * fi) + fi * 1.3) * 0.05 * amp + burst * (0.05 + 0.04 * fi);
        float rad = 0.011 + 0.006 * (0.5 + 0.5 * sin(t * 0.8 + fi * 2.0));
        vec2 c = vec2(cos(a), sin(a)) * (R + 0.012 + off);
        float dd = length(p - c) - rad;
        dist = smin(dist, dd, 0.05);
    }

    float body = smoothstep(aa * 1.6, -aa * 1.6, dist);
    float core = smoothstep(-w * 0.2, -w * 0.9, dRing) * 0.5;
    float glow = exp(-max(dist, 0.0) * 42.0) * 0.22;
    float a = clamp(body + glow * (1.0 - body), 0.0, 1.0);
    float hl = clamp(core * body, 0.0, 1.0);
    return vec4(mix(accentColor.rgb, vec3(1.0), hl * 0.55), a);
}

void main() {
    float m = min(itemSize.x, itemSize.y);
    vec2 p = (qt_TexCoord0 * itemSize - itemSize * 0.5) / m;
    float aa = 1.0 / m;

    float time = params.x;
    float fill = clamp(params.y, 0.0, 1.0);
    float burst = params.z;
    float live = cfg.x;
    float speed = cfg.y;

    vec4 c = params.w < 0.5
        ? orbit(p, time, fill, burst, live, speed, aa)
        : liquid(p, time, fill, burst, live, speed, aa);

    float a = c.a * accentColor.a * qt_Opacity;
    fragColor = vec4(c.rgb * a, a);
}
