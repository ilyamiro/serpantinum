// Wave for reusables/media/Visualizer.qml.
// Gets one ready level per wave point and builds the curve here.
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
    mat4 levels4;
    mat4 levels5;
    mat4 levels6;
    mat4 levels7;
    vec4 color;
    vec2 itemSize;
    float count;
    float vertical;
    float alignment;
    float maxLength;
};

// GLSL ES 1.00 (the variant Qt picks under EGL) has no int overloads of min/max/clamp.
// Strict compilers such as NVIDIA's reject them, so use explicit int helpers.
int imin(int a, int b) { return a < b ? a : b; }
int imax(int a, int b) { return a > b ? a : b; }
int iclamp(int v, int lo, int hi) { return imin(imax(v, lo), hi); }

float levelAt(int i) {
    int m = i / 16;
    int k = i - m * 16;
    int row = k / 4;
    int col = k - row * 4;
    if (m == 0) return levels0[col][row];
    if (m == 1) return levels1[col][row];
    if (m == 2) return levels2[col][row];
    if (m == 3) return levels3[col][row];
    if (m == 4) return levels4[col][row];
    if (m == 5) return levels5[col][row];
    if (m == 6) return levels6[col][row];
    return levels7[col][row];
}

float pointHeight(int i) {
    return levelAt(iclamp(i, 0, int(count) - 1)) * maxLength;
}

void main() {
    // x runs along the wave points, "across" is where the wave grows
    vec2 p = qt_TexCoord0 * itemSize;
    float x = vertical > 0.5 ? p.y : p.x;
    float across = vertical > 0.5 ? p.x : p.y;
    float alongSize = vertical > 0.5 ? itemSize.y : itemSize.x;
    float acrossSize = vertical > 0.5 ? itemSize.x : itemSize.y;

    float n = count;
    int last = int(n) - 1;
    float stepX = alongSize / (n - 1.0);

    // Same path as the old Canvas: quadratic curves through the midpoints, straight ends
    int k = iclamp(int(floor(x / stepX + 0.5)), 0, last);
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

    // Distance from the base: the wave grows from the start (top/left), the middle or the end
    float t = across;
    if (alignment > 1.5) {
        t = acrossSize - across;
    } else if (alignment > 0.5) {
        t = abs(across - acrossSize * 0.5);
        y *= 0.5;
        slope *= 0.5;
    }

    float d = (t - y) / sqrt(1.0 + slope * slope);
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) discard;

    fragColor = vec4(color.rgb, 1.0) * color.a * coverage * qt_Opacity;
}
