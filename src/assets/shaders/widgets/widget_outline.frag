// Wavy selection outline for widgets/SelectionOutline.qml.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o widget_outline.frag.qsb widget_outline.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
    vec2 itemSize;
    float radius;
    float inset;
    float lineWidth;
    float amplitude;
    float frequency;
    float phase;
};

const float HALF_PI = 1.5707963;

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5 - vec2(inset);
    vec2 q = p - itemSize * 0.5;
    vec2 b = max(halfSize - vec2(radius), vec2(0.0));
    vec2 a = abs(q);

    // Signed distance to the rounded rectangle (positive outside).
    vec2 e = a - b;
    float dist = length(max(e, vec2(0.0))) + min(max(e.x, e.y), 0.0) - radius;

    // Length along the outline to the closest point, clockwise from the start
    // of the top edge, the same way the path was walked on the Canvas.
    float sx = 2.0 * b.x;
    float sy = 2.0 * b.y;
    float arc = HALF_PI * radius;
    float s;
    if (e.x > 0.0 && e.y > 0.0) {
        // Corner arcs; every atan gets non-negative arguments, so it stays in [0, pi/2].
        vec2 c = q - sign(q) * b;
        if (q.x > 0.0 && q.y < 0.0) {
            s = sx + atan(c.x, -c.y + 1e-6) * radius;
        } else if (q.x > 0.0) {
            s = sx + sy + arc + atan(c.y, c.x + 1e-6) * radius;
        } else if (q.y > 0.0) {
            s = 2.0 * sx + sy + 2.0 * arc + atan(-c.x, c.y + 1e-6) * radius;
        } else {
            s = 2.0 * sx + 2.0 * sy + 3.0 * arc + atan(-c.y, -c.x + 1e-6) * radius;
        }
    } else if (e.x > e.y) {
        // Right or left edge.
        s = q.x > 0.0 ? sx + arc + (q.y + b.y) : 2.0 * sx + sy + 3.0 * arc + (b.y - q.y);
    } else {
        // Top or bottom edge.
        s = q.y < 0.0 ? q.x + b.x : sx + sy + 2.0 * arc + (b.x - q.x);
    }

    float wave = amplitude * sin(frequency * s + phase);
    float coverage = clamp(lineWidth * 0.5 + 0.5 - abs(dist - wave), 0.0, 1.0);
    fragColor = vec4(color.rgb, 1.0) * color.a * coverage * qt_Opacity;
}
