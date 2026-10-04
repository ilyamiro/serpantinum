// Bars for widgets/faces/visualizer/VisualizerFace.qml.
// Gets the raw cava levels and does the whole bar layout here.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o visualizer_bars.frag.qsb visualizer_bars.frag
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
    vec4 barColor;
    vec2 itemSize;
    float barCount;
    float sourceCount;
    float spacing;
    float minBarHeight;
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

void main() {
    float n = barCount;
    float barW = (itemSize.x - (n - 1.0) * spacing) / n;
    float slot = barW + spacing;
    vec2 p = vec2(qt_TexCoord0.x * itemSize.x, (1.0 - qt_TexCoord0.y) * itemSize.y);

    int i = int(floor((p.x + spacing * 0.5) / slot));
    if (i < 0 || i >= int(n)) discard;
    float x = p.x - float(i) * slot;

    // Low frequencies in the middle, mirrored to both sides
    float half_ = (n - 1.0) / 2.0;
    float norm = half_ > 0.0 ? abs(float(i) - half_) / half_ : 0.0;
    float pos = pow(norm, 1.25) * (sourceCount - 1.0);
    int i0 = int(floor(pos));
    int i1 = min(int(sourceCount) - 1, i0 + 1);
    float raw = mix(sourceAt(i0), sourceAt(i1), pos - float(i0));
    float level = raw < 0.03 ? 0.0 : pow((raw - 0.03) / 0.97, 1.15);

    float e = min(1.0, sin(float(i) / max(1.0, n - 1.0) * 3.14159265) * 2.0);
    e = e * e * (3.0 - 2.0 * e);
    level = clamp(level, 0.0, 1.0) * e;

    float h = max(minBarHeight, level * itemSize.y * 0.96);
    float r = min(barW * 0.35, h);

    float d;
    if (p.y > h - r && (x < r || x > barW - r)) {
        vec2 c = vec2(clamp(x, r, barW - r), h - r);
        d = length(vec2(x, p.y) - c) - r;
    } else {
        d = max(max(-x, x - barW), p.y - h);
    }
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) discard;

    fragColor = vec4(barColor.rgb, 1.0) * barColor.a * (0.3 + level * 0.7) * e * coverage * qt_Opacity;
}
