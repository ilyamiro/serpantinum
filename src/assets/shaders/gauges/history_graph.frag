// Usage history line for reusables/display/SystemUsageGraph.qml.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o history_graph.frag.qsb history_graph.frag
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
    vec4 color;
    vec2 itemSize;
    float count;
    float capacity;
    float shift;
    float strokeWidth;
    float padX;
};

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
    return levels3[col][row];
}

float stepX() {
    return (itemSize.x - 2.0 * padX) / max(capacity - 1.0, 1.0);
}

vec2 pointAt(int i) {
    int last = int(count) - 1;
    int c = iclamp(i, 0, last);
    float halfW = strokeWidth * 0.5 + 1.0;
    float x = itemSize.x - padX - (float(last - c) - shift) * stepX();
    float y = halfW + (1.0 - clamp(levelAt(c), 0.0, 1.0)) * (itemSize.y - 2.0 * halfW);
    return vec2(x, y);
}

float segmentDistance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float len2 = dot(ab, ab);
    float t = len2 > 0.0 ? clamp(dot(p - a, ab) / len2, 0.0, 1.0) : 0.0;
    return length(p - (a + ab * t));
}

vec2 bezier(vec2 a, vec2 b, vec2 c, float t) {
    float u = 1.0 - t;
    return u * u * a + 2.0 * u * t * b + t * t * c;
}

void main() {
    if (count < 1.0) discard;

    vec2 p = qt_TexCoord0 * itemSize;
    int last = int(count) - 1;
    float s = stepX();
    int k = int(floor(float(last) + shift - (itemSize.x - padX - p.x) / s + 0.5));

    float best = 1e6;
    for (int j = -2; j <= 2; j++) {
        int i = k + j;
        if (i < 0 || i > last) continue;
        vec2 b = pointAt(i);
        vec2 a = i == 0 ? b : (pointAt(i - 1) + b) * 0.5;
        vec2 c = i == last ? b : (b + pointAt(i + 1)) * 0.5;
        vec2 prev = a;
        for (int n = 1; n <= 6; n++) {
            vec2 next = bezier(a, b, c, float(n) / 6.0);
            best = min(best, segmentDistance(p, prev, next));
            prev = next;
        }
    }

    float coverage = clamp(strokeWidth * 0.5 + 0.5 - best, 0.0, 1.0);
    float fade = padX > 0.0 ? smoothstep(0.0, padX, p.x) * smoothstep(0.0, padX, itemSize.x - p.x) : 1.0;
    coverage *= fade;
    if (coverage <= 0.0) discard;

    fragColor = vec4(color.rgb, 1.0) * color.a * coverage * qt_Opacity;
}
