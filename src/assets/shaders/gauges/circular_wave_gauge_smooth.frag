#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float fillRatio;
    float strokeWidth;
    float useSineWave;
    vec4 accentColor;
    vec4 params;
    vec4 trackColor;
};

const float PI = 3.141592653589793;

float waveOffset(float theta, float amp, float cycles) {
    return amp * sin(theta * cycles);
}

vec2 curvePoint(float t, vec2 center, float radius, float amp, float cycles) {
    float r = radius + (useSineWave > 0.5 ? waveOffset(t, amp, cycles) : 0.0);
    float a = t - PI * 0.5;
    return center + r * vec2(cos(a), sin(a));
}

float foldT(float t, float tMin, float tMax) {
    return (tMax < 100.0 && t > 2.0 * PI) ? t - 2.0 * PI : t;
}

float arcDistance(vec2 p, vec2 center, float radius, float amp, float cycles, float t0, float w, float tMin, float tMax) {
    const int N = 16;
    float best = 1e6;
    float bestT = t0;
    for (int i = 0; i <= N; i++) {
        float t = t0 - w + 2.0 * w * float(i) / float(N);
        float d = length(p - curvePoint(clamp(foldT(t, tMin, tMax), tMin, tMax), center, radius, amp, cycles));
        if (d < best) {
            best = d;
            bestT = t;
        }
    }
    float h = 2.0 * w / float(N);
    for (int k = 0; k < 4; k++) {
        for (int s = -1; s <= 1; s += 2) {
            float t = bestT + float(s) * h * 0.5;
            float d = length(p - curvePoint(clamp(foldT(t, tMin, tMax), tMin, tMax), center, radius, amp, cycles));
            if (d < best) {
                best = d;
                bestT = t;
            }
        }
        h *= 0.5;
    }
    return best;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 center = itemSize * 0.5;
    vec2 d = p - center;
    float dist = length(d);

    float outer = min(center.x, center.y) - 1.0;
    if (outer <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float strokeW = min(strokeWidth > 0.0 ? strokeWidth : 2.2, outer * 0.4);
    float halfW = strokeW * 0.5;
    float amp = (useSineWave > 0.5) ? (params.x > 0.0 ? params.x : strokeW * 0.35) : 0.0;
    amp = min(amp, outer * 0.05);
    float radius = params.y > 0.0 ? params.y : outer - amp - halfW;
    if (radius <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float cycles = params.z > 0.0 ? params.z : 12.0;
    amp = min(amp, radius * 0.05);

    float reach = halfW + amp + 1.5;
    if (dist < radius - reach || dist > radius + reach) {
        fragColor = vec4(0.0);
        return;
    }

    float theta = atan(d.y, d.x) + PI * 0.5;
    if (theta < 0.0) theta += 2.0 * PI;
    float w = dist > reach ? asin(min(1.0, reach / dist)) : PI;

    float dTrack = arcDistance(p, center, radius, amp, cycles, theta, w, -1e3, 1e3) - halfW;
    if (dTrack >= 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    float trackAlpha = clamp(0.5 - dTrack, 0.0, 1.0) * trackColor.a;

    float fill = clamp(fillRatio, 0.0, 1.0);
    float sweep = 2.0 * PI * fill;

    float dProg = 1e6;
    if (fill >= 0.999) {
        dProg = dTrack;
    } else if (fill > 0.001) {
        dProg = arcDistance(p, center, radius, amp, cycles, theta, w, 0.0, sweep) - halfW;
    }

    float progAlpha = clamp(0.5 - dProg, 0.0, 1.0);
    float a = progAlpha + trackAlpha * (1.0 - progAlpha);
    vec3 rgb = accentColor.rgb * progAlpha + trackColor.rgb * trackAlpha * (1.0 - progAlpha);
    fragColor = vec4(rgb * qt_Opacity, a * qt_Opacity);
}
