#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float time;
    float progress;
    float fade;
    float scale;
    vec4 accentColor;
    vec4 bands0;
    vec4 bands1;
    vec4 bands2;
};

const float PI = 3.141592653589793;

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float getBandNorm(int idx) {
    float val = 0.0;
    if (idx == 0) val = bands0.x;
    else if (idx == 1) val = bands0.y;
    else if (idx == 2) val = bands0.z;
    else if (idx == 3) val = bands0.w;
    else if (idx == 4) val = bands1.x;
    else if (idx == 5) val = bands1.y;
    else if (idx == 6) val = bands1.z;
    else if (idx == 7) val = bands1.w;
    else if (idx == 8) val = bands2.x;
    else if (idx == 9) val = bands2.y;
    return 1.0 - clamp((val + 12.0) / 24.0, 0.0, 1.0);
}

vec2 getBandPoint(int idx, float topMargin, float availH) {
    float px = (float(idx) + 0.5) * (itemSize.x / 10.0);
    float py = topMargin + getBandNorm(idx) * availH;
    return vec2(px, py);
}

void main() {
    if (progress <= 0.01 || fade >= 0.999) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    float topMargin = bands2.z > 0.0 ? bands2.z : 10.0;
    float botMargin = bands2.w > 0.0 ? bands2.w : 30.0;
    float availH = max(itemSize.y - topMargin - botMargin, 1.0);
    float sc = scale > 0.0 ? scale : 1.0;

    vec4 accum = vec4(0.0);

    for (int s = 0; s < 4; ++s) {
        float r = (s == 0 ? 9.0 : (s == 1 ? 4.5 : (s == 2 ? 2.25 : 1.1))) * sc;
        float alpha = s == 0 ? 0.35 : (s == 1 ? 0.65 : (s == 2 ? 0.90 : 1.00));
        vec3 strandCol = s == 3 ? vec3(1.0) : mix(accentColor.rgb, vec3(1.0), float(s) * 0.25);

        float minDist = 1e6;
        int steps = s == 3 ? 6 : 8;

        for (int i = 0; i < 9; ++i) {
            if (float(i) > progress) break;
            float fraction = clamp(progress - float(i), 0.0, 1.0);
            if (fraction <= 0.0) break;

            vec2 p1 = getBandPoint(i, topMargin, availH);
            vec2 p2 = getBandPoint(i + 1, topMargin, availH);

            if (p.x < min(p1.x, p2.x) - 45.0 * sc || p.x > max(p1.x, p2.x) + 45.0 * sc) {
                continue;
            }

            vec2 prevPt = p1;

            for (int j = 1; j <= 8; ++j) {
                if (j > steps) break;
                float t = float(j) / float(steps);
                if (t > fraction) t = fraction;

                vec2 c = mix(p1, p2, t);
                float envelope = sin(t * PI);
                float noiseAmpX = (s == 3 ? 1.0 : float(4 - s) * 4.0) * sc;
                float noiseAmpY = (s == 3 ? 1.0 : float(4 - s) * 5.0) * sc;

                float sepWaveX = (s < 2) ? sin(time * 3.0 + float(i + j + s)) * 9.0 * sc * envelope : 0.0;
                float sepWaveY = (s < 2) ? cos(time * 2.5 + float(i - j - s)) * 13.5 * sc * envelope : 0.0;

                float noiseX = sin(time * float(10 + s) + float(i + j)) * cos(time * 8.0 - float(i - j)) * noiseAmpX * envelope * (1.0 - fade);
                float noiseY = cos(time * float(9 - s) + float(i - j)) * sin(time * 7.0 + float(i - j)) * noiseAmpY * envelope * (1.0 - fade);

                vec2 currPt = c + vec2(sepWaveX + noiseX, sepWaveY + noiseY);

                float d = sdSegment(p, prevPt, currPt);
                minDist = min(minDist, d);

                prevPt = currPt;
                if (t >= fraction) break;
            }
        }

        float strokeA = clamp(r + 1.0 - minDist, 0.0, 1.0) * alpha;
        vec4 layer = vec4(strandCol * strokeA, strokeA);

        accum = layer + accum * (1.0 - layer.a);
    }

    accum *= (1.0 - fade) * qt_Opacity;
    fragColor = accum;
}
