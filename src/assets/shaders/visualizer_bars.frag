// Bars for reusables/media/Visualizer.qml.
// Gets one ready level per bar and only does the layout and the shape here.
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
    mat4 levels4;
    mat4 levels5;
    mat4 levels6;
    mat4 levels7;
    vec4 color;
    vec2 itemSize;
    float count;
    float vertical;
    float alignment;
    float spacing;
    float minLength;
    float maxLength;
    float radiusRatio;
    float opacityBase;
    float opacityRange;
    float edgeFade;
};

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

void main() {
    // "along" is where the bars follow each other, "across" is where they grow
    vec2 p = qt_TexCoord0 * itemSize;
    float along = vertical > 0.5 ? p.y : p.x;
    float across = vertical > 0.5 ? p.x : p.y;
    float alongSize = vertical > 0.5 ? itemSize.y : itemSize.x;
    float acrossSize = vertical > 0.5 ? itemSize.x : itemSize.y;

    float n = count;
    float thickness = (alongSize - (n - 1.0) * spacing) / n;
    float slot = thickness + spacing;
    int i = int(floor((along + spacing * 0.5) / slot));
    if (i < 0 || i >= int(n)) discard;
    float x = along - float(i) * slot;

    float level = levelAt(i);
    float e = 1.0;
    if (edgeFade > 0.5) {
        e = min(1.0, sin(float(i) / max(1.0, n - 1.0) * 3.14159265) * 2.0);
        e = e * e * (3.0 - 2.0 * e);
        level *= e;
    }

    // Distance from the base: bars grow from the start (top/left), the middle or the end
    float len = max(minLength, level * maxLength);
    float t = across;
    float extent = len;
    if (alignment > 1.5) {
        t = acrossSize - across;
    } else if (alignment > 0.5) {
        t = abs(across - acrossSize * 0.5);
        extent = len * 0.5;
    }

    // Rounded free end, clamped like a Rectangle radius
    float r = min(thickness * radiusRatio, len * 0.5);
    float d;
    if (t > extent - r && (x < r || x > thickness - r)) {
        vec2 c = vec2(clamp(x, r, thickness - r), extent - r);
        d = length(vec2(x, t) - c) - r;
    } else {
        d = max(max(-x, x - thickness), t - extent);
    }
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) discard;

    fragColor = vec4(color.rgb, 1.0) * color.a * (opacityBase + level * opacityRange) * e * coverage * qt_Opacity;
}
