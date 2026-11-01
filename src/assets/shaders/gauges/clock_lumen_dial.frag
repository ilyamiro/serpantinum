#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 fillColor;
    vec4 weights0;
    vec4 weights1;
    vec4 weights2;
    vec4 params;
};

const float PI = 3.141592653589793;

float getWeight(int idx) {
    if (idx == 0) return weights0.x;
    if (idx == 1) return weights0.y;
    if (idx == 2) return weights0.z;
    if (idx == 3) return weights0.w;
    if (idx == 4) return weights1.x;
    if (idx == 5) return weights1.y;
    if (idx == 6) return weights1.z;
    if (idx == 7) return weights1.w;
    if (idx == 8) return weights2.x;
    if (idx == 9) return weights2.y;
    if (idx == 10) return weights2.z;
    return weights2.w;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 center = itemSize * 0.5;
    vec2 d = p - center;
    float dist = length(d);

    float size = min(itemSize.x, itemSize.y);
    float rBase = params.x > 0.0 ? params.x : size * 0.435;
    float rAmp = params.y > 0.0 ? params.y : size * 0.042;

    // Angle: clockwise from top
    float a = atan(d.x, -d.y);
    if (a < 0.0) a += 2.0 * PI;

    float deg = mod(a * 180.0 / PI, 360.0);
    int h = int(mod(floor(deg / 30.0 + 0.5), 12.0));
    float diff = abs(deg - float(h) * 30.0);
    if (diff > 180.0) diff = 360.0 - diff;

    float bump = 0.5 * (1.0 + cos((diff / 15.0) * PI));
    float wVal = getWeight(h);
    float bumpScale = 0.28 + 0.72 * wVal;
    float rTarget = rBase + (rAmp * bumpScale) * bump;

    float alpha = clamp(0.5 - (dist - rTarget), 0.0, 1.0) * fillColor.a * qt_Opacity;
    fragColor = vec4(fillColor.rgb * alpha, alpha);
}
