#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float time;
    float strikeProg;
    float scale;
    float beamCount;
    float coreRadius;
    vec4 activeColor;
    vec4 beam0;
    vec4 beam1;
    vec4 beam2;
    vec4 beam3;
    vec4 beam4;
    vec4 beam5;
    vec4 beam6;
    vec4 beam7;
};

const float PI = 3.141592653589793;

vec4 getBeam(int idx) {
    if (idx == 0) return beam0;
    if (idx == 1) return beam1;
    if (idx == 2) return beam2;
    if (idx == 3) return beam3;
    if (idx == 4) return beam4;
    if (idx == 5) return beam5;
    if (idx == 6) return beam6;
    return beam7;
}

void main() {
    if (strikeProg <= 0.001 || beamCount <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    float sc = scale > 0.0 ? scale : 1.0;
    float reachFactor = min(1.0, strikeProg * 1.15);
    int totalBeams = int(clamp(beamCount, 0.0, 8.0));

    float cutAlpha = 1.0;
    for (int c = 0; c < 8; ++c) {
        if (c >= totalBeams) break;
        vec4 cb = getBeam(c);
        if (cb.x < 0.0) continue;
        cutAlpha *= smoothstep(coreRadius - 0.75, coreRadius + 0.75, length(p - cb.xy));
    }
    if (cutAlpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 accum = vec4(0.0);

    for (int i = 0; i < 8; ++i) {
        if (i >= totalBeams) break;

        vec4 b = getBeam(i);
        if (b.x < 0.0 || b.z < 0.0) continue;

        vec2 startPos = b.xy;
        vec2 targetPos = b.zw;
        vec2 dir = targetPos - startPos;
        float fullDist = length(dir);
        if (fullDist < sc * 10.0) continue;

        vec2 nDir = dir / fullDist;
        vec2 perp = vec2(-nDir.y, nDir.x);

        float coreVisualRadius = sc * 40.0;
        float startOffset = coreVisualRadius + sc * 5.0;
        float endOffset = sc * 26.0;

        float maxDrawDist = fullDist - startOffset - endOffset;
        if (maxDrawDist <= 0.0) continue;

        float drawDist = maxDrawDist * reachFactor;
        if (drawDist <= 0.0) continue;

        vec2 sPos = startPos + nDir * startOffset;
        vec2 pRel = p - sPos;
        float proj = dot(pRel, nDir);

        if (proj < -sc * 6.0 || proj > drawDist + sc * 6.0) continue;

        float t = clamp(proj / max(drawDist, 1.0), 0.0, 1.0);
        float envelope = sin(t * PI);

        float distanceFactor = max(0.0, 1.0 - (fullDist / 420.0));
        float dynamicLineWidthCore = sc * 1.0 + (distanceFactor * sc * 1.2);
        float dynamicLineWidthGlow = sc * 4.5 + (distanceFactor * sc * 3.0);
        float dynamicAlpha = (0.35 + (distanceFactor * 0.65)) * min(1.0, strikeProg * 1.5);

        float stepIdx = floor(t * 22.0);
        float stepFrac = fract(t * 22.0);

        // Strand 1: Outer glow
        float j1_a = (sin(time * 12.0 + stepIdx) - 0.5) * sc * 2.0 * distanceFactor;
        float j1_b = (sin(time * 12.0 + stepIdx + 1.0) - 0.5) * sc * 2.0 * distanceFactor;
        float offset1 = sin(time * 3.4 + t * 9.0 + float(i)) * sc * 9.0 * envelope + mix(j1_a, j1_b, stepFrac);

        // Strand 2: Mid strand
        float j2_a = (cos(time * 10.0 - stepIdx) - 0.5) * sc * 2.5 * distanceFactor;
        float j2_b = (cos(time * 10.0 - (stepIdx + 1.0)) - 0.5) * sc * 2.5 * distanceFactor;
        float offset2 = sin(time * 2.5 + t * 6.0 - float(i)) * sc * 5.5 * envelope + mix(j2_a, j2_b, stepFrac);

        // Strand 3: White core
        float j3_a = (sin(time * 14.0 + stepIdx) - 0.5) * sc * 1.8 * distanceFactor;
        float j3_b = (sin(time * 14.0 + stepIdx + 1.0) - 0.5) * sc * 1.8 * distanceFactor;
        float offset3 = cos(-time * 1.5 + t * 8.0 + float(i * 2)) * sc * 7.0 * envelope + mix(j3_a, j3_b, stepFrac);

        float perpDist = dot(pRel, perp);
        float d1 = abs(perpDist - offset1);
        float d2 = abs(perpDist - offset2);
        float d3 = abs(perpDist - offset3);

        float rGlow = dynamicLineWidthGlow * 0.5;
        float rMid = dynamicLineWidthCore;
        float rCore = dynamicLineWidthCore * 0.5;

        float i1 = clamp(rGlow + 0.75 - d1, 0.0, 1.0) * dynamicAlpha * 0.22;
        float i2 = clamp(rMid + 0.75 - d2, 0.0, 1.0) * dynamicAlpha * 0.55;
        float i3 = clamp(rCore + 0.75 - d3, 0.0, 1.0) * dynamicAlpha * 0.95;

        vec3 col1 = activeColor.rgb;
        vec3 col2 = mix(activeColor.rgb, vec3(1.0), 0.35);
        vec3 col3 = vec3(1.0);

        vec4 beam = vec4(col1 * i1, i1);
        beam = vec4(col2 * i2, i2) + beam * (1.0 - i2);
        beam = vec4(col3 * i3, i3) + beam * (1.0 - i3);

        accum = beam + accum * (1.0 - beam.a);
    }

    fragColor = accum * (qt_Opacity * cutAlpha);
}
