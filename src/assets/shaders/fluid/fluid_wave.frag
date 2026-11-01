#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    float fillLevel;
    float waveAmp;
    vec2 itemSize;
    float phase;
    float vertical;
    vec4 color1;
    vec4 color2;
    vec4 params;
};

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    if (fillLevel <= 0.0001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    vec2 pCenter = p - halfSize;
    float clampedR = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float dBox = sdRoundedBox(pCenter, halfSize, clampedR);
    float boxAlpha = clamp(0.5 - dBox, 0.0, 1.0);

    float fluidAlpha = 0.0;
    float globalAlpha = params.x > 0.0 ? params.x : 1.0;

    if (vertical > 0.5) {
        if (fillLevel >= 0.999) {
            fluidAlpha = 1.0;
        } else {
            float fillY = itemSize.y * (1.0 - fillLevel);
            float t = clamp(p.x / max(itemSize.x, 1.0), 0.0, 1.0);
            float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
            float b2 = 3.0 * (1.0 - t) * t * t;
            float waveOffset = waveAmp * (-b1 * cos(phase) + b2 * sin(phase));
            float surfaceY = fillY + waveOffset;
            fluidAlpha = clamp(0.5 - (surfaceY - p.y), 0.0, 1.0);
        }
    } else {
        if (fillLevel >= 0.999) {
            fluidAlpha = 1.0;
        } else {
            float fillX = itemSize.x * fillLevel;
            float t = clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0);
            float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
            float b2 = 3.0 * (1.0 - t) * t * t;
            float waveOffset = waveAmp * (b2 * sin(phase) - b1 * cos(phase));
            float surfaceX = fillX + waveOffset;
            fluidAlpha = clamp(0.5 - (p.x - surfaceX), 0.0, 1.0);
        }
    }

    vec4 col = vertical > 0.5 
        ? mix(color1, color2, clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0))
        : mix(color1, color2, clamp(p.x / max(itemSize.x, 1.0), 0.0, 1.0));

    float a = boxAlpha * fluidAlpha * globalAlpha * col.a * qt_Opacity;
    fragColor = vec4(col.rgb * a, a);
}
