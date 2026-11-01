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
};

const float PI = 3.141592653589793;

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 center = itemSize * 0.5;
    vec2 d = p - center;
    float dist = length(d);

    float strokeW = strokeWidth > 0.0 ? strokeWidth : 2.2;
    float amp = params.x > 0.0 ? params.x : 0.9;
    float radius = params.y > 0.0 ? params.y : min(center.x, center.y) - amp - (strokeW * 0.5) - 0.4;
    if (radius <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // 1. Background ring track (alpha 0.22)
    float dTrack = abs(dist - radius) - strokeW * 0.5;
    float trackAlpha = clamp(0.5 - dTrack, 0.0, 1.0) * 0.22;
    vec4 trackCol = vec4(accentColor.rgb, 1.0) * trackAlpha;

    if (fillRatio <= 0.001) {
        float a = trackAlpha * qt_Opacity;
        fragColor = vec4(trackCol.rgb * a, a);
        return;
    }

    // 2. Progress arc: starts at top (-PI/2) and goes clockwise
    float a = atan(d.y, d.x); // [-PI, PI]
    // Map -PI/2 to 0, clockwise
    float normAngle = a + PI * 0.5;
    while (normAngle < 0.0) normAngle += 2.0 * PI;
    while (normAngle >= 2.0 * PI) normAngle -= 2.0 * PI;

    float sweepAngle = 2.0 * PI * clamp(fillRatio, 0.0, 1.0);

    float dProg = 1e6;

    if (fillRatio >= 0.999) {
        float rTarget = radius;
        if (useSineWave > 0.5) {
            float totalP = 2.0 * PI * radius;
            float cycles = max(5.0, floor(totalP / 8.5 + 0.5));
            float freq = (2.0 * PI * cycles) / totalP;
            float arcDist = normAngle * radius;
            rTarget += amp * sin(freq * arcDist);
        }
        dProg = abs(dist - rTarget) - strokeW * 0.5;
    } else {
        float rTarget = radius;
        if (useSineWave > 0.5) {
            float totalP = 2.0 * PI * radius;
            float cycles = max(5.0, floor(totalP / 8.5 + 0.5));
            float freq = (2.0 * PI * cycles) / totalP;
            float arcDist = normAngle * radius;
            rTarget += amp * sin(freq * arcDist);
        }

        if (normAngle <= sweepAngle) {
            dProg = abs(dist - rTarget) - strokeW * 0.5;
        }

        // Round end caps
        vec2 startCap = center + vec2(0.0, -radius);
        float endA = -PI * 0.5 + sweepAngle;
        vec2 endCap = center + radius * vec2(cos(endA), sin(endA));
        float dCap0 = length(p - startCap) - strokeW * 0.5;
        float dCap1 = length(p - endCap) - strokeW * 0.5;
        dProg = min(dProg, min(dCap0, dCap1));
    }

    float progAlpha = clamp(0.5 - dProg, 0.0, 1.0);
    vec4 progCol = vec4(accentColor.rgb, 1.0) * progAlpha;

    // Composite progress over track
    vec4 res = progCol + trackCol * (1.0 - progAlpha);
    float finalA = res.a * qt_Opacity;
    fragColor = vec4(res.rgb * finalA, finalA);
}
