// Ring wave for reusables/media/Visualizer.qml.
// Gets one ready level per point and joins the points with straight segments around the circle here.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o visualizer_ring_wave.frag.qsb visualizer_ring_wave.frag
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
    float minLength;
    float maxLength;
    float opacityBase;
    float opacityRange;
    float ringRadius;
    float tintStrength;
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

int wrapIndex(int i, int n) {
    if (i < 0) return i + n;
    if (i >= n) return i - n;
    return i;
}

float pointHeight(int i, int n) {
    return max(minLength, levelAt(wrapIndex(i, n)) * maxLength);
}

void main() {
    vec2 dir = qt_TexCoord0 * itemSize - itemSize * 0.5;
    float dist = length(dir);
    if (dist < 0.5) discard;

    int n = int(count);
    float step = 6.28318531 / count;
    float angle = atan(dir.x, -dir.y);
    if (angle < 0.0) angle += 6.28318531;

    float f = angle / step;
    int k = int(floor(f));
    float u = f - float(k);
    float h0 = pointHeight(k, n);
    float h1 = pointHeight(k + 1, n);
    float h = mix(h0, h1, u);
    float slope = (h1 - h0) / (step * dist);

    float outer = (dist - ringRadius - h) / sqrt(1.0 + slope * slope);
    float d = max(outer, ringRadius - dist);
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) discard;

    float level = clamp((dist - ringRadius) / max(maxLength, 1.0), 0.0, 1.0);
    vec3 rgb = mix(color.rgb, vec3(1.0), level * tintStrength);
    fragColor = vec4(rgb, 1.0) * color.a * (opacityBase + level * opacityRange) * coverage * qt_Opacity;
}
