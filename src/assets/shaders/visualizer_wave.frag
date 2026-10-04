// Wave for widgets/faces/visualizer/VisualizerFaceContinuous.qml.
// Gets the smoothed cava levels and builds the curve here.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o visualizer_wave.frag.qsb visualizer_wave.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    mat4 levels0;
    mat4 levels1;
    mat4 levels2;
    mat4 levels3;
    vec4 waveColor;
    vec2 itemSize;
    float pointCount;
    float sourceCount;
};

float sourceAt(int i) {
    int m = i / 16;
    int k = i - m * 16;
    int row = k / 4;
    int col = k - row * 4;
    if (m == 0) return levels0[col][row];
    if (m == 1) return levels1[col][row];
    if (m == 2) return levels2[col][row];
    return levels3[col][row];
}

// Low frequencies in the middle, mirrored to both sides
float pointLevel(int i) {
    float half_ = (pointCount - 1.0) / 2.0;
    float norm = half_ > 0.0 ? abs(float(i) - half_) / half_ : 0.0;
    float pos = pow(norm, 1.25) * (sourceCount - 1.0);
    int i0 = int(floor(pos));
    int i1 = min(int(sourceCount) - 1, i0 + 1);
    float raw = mix(sourceAt(i0), sourceAt(i1), pos - float(i0));
    float v = raw < 0.03 ? 0.0 : pow((raw - 0.03) / 0.97, 1.15);
    return clamp(v, 0.0, 1.0);
}

float pointHeight(int i) {
    int last = int(pointCount) - 1;
    i = clamp(i, 0, last);
    float sm = pointLevel(max(i - 1, 0)) * 0.25 + pointLevel(i) * 0.5 + pointLevel(min(i + 1, last)) * 0.25;
    float e = min(1.0, sin(float(i) / max(1.0, pointCount - 1.0) * 3.14159265) * 2.0);
    e = e * e * (3.0 - 2.0 * e);
    return sm * e * itemSize.y * 0.92;
}

void main() {
    float n = pointCount;
    int last = int(n) - 1;
    float stepX = itemSize.x / (n - 1.0);
    float x = qt_TexCoord0.x * itemSize.x;
    float fromBottom = (1.0 - qt_TexCoord0.y) * itemSize.y;

    // Same path as the old Canvas: quadratic curves through the midpoints, straight ends
    int k = clamp(int(floor(x / stepX + 0.5)), 0, last);
    float hk = pointHeight(k);
    float y;
    float slope;
    if (k == 0) {
        float m0 = (hk + pointHeight(1)) * 0.5;
        slope = (m0 - hk) / (0.5 * stepX);
        y = hk + slope * x;
    } else if (k == last) {
        float m = (pointHeight(last - 1) + hk) * 0.5;
        float x0 = (float(last) - 0.5) * stepX;
        slope = (hk - m) / (0.5 * stepX);
        y = m + slope * (x - x0);
    } else {
        float a = (pointHeight(k - 1) + hk) * 0.5;
        float b = (hk + pointHeight(k + 1)) * 0.5;
        float u = clamp((x - (float(k) - 0.5) * stepX) / stepX, 0.0, 1.0);
        y = (1.0 - u) * (1.0 - u) * a + 2.0 * u * (1.0 - u) * hk + u * u * b;
        slope = (2.0 * (1.0 - u) * (hk - a) + 2.0 * u * (b - hk)) / stepX;
    }

    float d = (fromBottom - y) / sqrt(1.0 + slope * slope);
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) discard;

    fragColor = vec4(waveColor.rgb, 1.0) * waveColor.a * coverage * qt_Opacity;
}
