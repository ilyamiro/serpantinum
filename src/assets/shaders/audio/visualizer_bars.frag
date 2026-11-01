// Bars for reusables/media/Visualizer.qml.
// Gets one ready level per bar and only does the layout and the shape here,
// in a row or around a circle.
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
    float ringRadius;
    float ringBarWidth;
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

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float n = count;
    int i;
    float x;
    float t;
    float thickness;
    float level;
    float e = 1.0;
    float len;
    float extent;

    if (ringRadius > 0.0) {
        // Bars stand around a circle in the middle, bar 0 at the top, going clockwise
        vec2 dir = p - itemSize * 0.5;
        float step = 6.28318531 / n;
        float angle = atan(dir.x, -dir.y);
        if (angle < 0.0) angle += 6.28318531;
        i = int(floor(angle / step + 0.5));
        if (i >= int(n)) i = 0;
        vec2 radial = vec2(sin(float(i) * step), -cos(float(i) * step));

        thickness = ringBarWidth;
        x = dot(dir, vec2(-radial.y, radial.x)) + thickness * 0.5;
        t = dot(dir, radial) - ringRadius;
        level = levelAt(i);
        len = max(minLength, level * maxLength);
        extent = len;
    } else {
        // "along" is where the bars follow each other, "across" is where they grow
        float along = vertical > 0.5 ? p.y : p.x;
        float across = vertical > 0.5 ? p.x : p.y;
        float alongSize = vertical > 0.5 ? itemSize.y : itemSize.x;
        float acrossSize = vertical > 0.5 ? itemSize.x : itemSize.y;

        thickness = (alongSize - (n - 1.0) * spacing) / n;
        float slot = thickness + spacing;
        i = int(floor((along + spacing * 0.5) / slot));
        if (i < 0 || i >= int(n)) discard;
        x = along - float(i) * slot;

        level = levelAt(i);
        if (edgeFade > 0.5) {
            e = min(1.0, sin(float(i) / max(1.0, n - 1.0) * 3.14159265) * 2.0);
            e = e * e * (3.0 - 2.0 * e);
            level *= e;
        }

        // Distance from the base: bars grow from the start (top/left), the middle or the end
        len = max(minLength, level * maxLength);
        t = across;
        extent = len;
        if (alignment > 1.5) {
            t = acrossSize - across;
        } else if (alignment > 0.5) {
            t = abs(across - acrossSize * 0.5);
            extent = len * 0.5;
        }
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
    // Ring bars also have a base edge on the circle
    if (ringRadius > 0.0) d = max(d, -t);
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) discard;

    // Optionally lighter towards the end and on loud bars
    vec3 rgb = mix(color.rgb, vec3(1.0), (float(i) / n * 0.4 + level * 0.6) * tintStrength);
    fragColor = vec4(rgb, 1.0) * color.a * (opacityBase + level * opacityRange) * e * coverage * qt_Opacity;
}
