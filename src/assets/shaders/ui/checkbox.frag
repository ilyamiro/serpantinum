#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 baseColor;
    vec4 hoverColor;
    vec4 accentColor;
    vec4 checkColor;
    vec4 params;
    vec4 params2;
};

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h);
}

vec4 over(vec4 dst, vec4 src, float cover) {
    float a = src.a * cover;
    return vec4(src.rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec2 halfSize = itemSize * 0.5;
    vec2 p = uv * itemSize - halfSize;
    float s = min(itemSize.x, itemSize.y);

    float radius = clamp(params.x, 0.0, min(halfSize.x, halfSize.y));
    float d = sdRoundBox(p, halfSize, radius);
    float shape = clamp(0.5 - d, 0.0, 1.0);

    float fill = clamp(params.z, 0.0, 1.0);
    float draw = clamp(params.w, 0.0, 1.0);
    float hover = clamp(params2.x, 0.0, 1.0);

    vec4 col = vec4(0.0);
    vec4 base = vec4(mix(baseColor.rgb, hoverColor.rgb, hover * 0.25), baseColor.a);
    col = over(col, base, 1.0);

    float reach = length(halfSize) + 1.0;
    float wave = fill * reach;
    float fillMask = clamp(wave - length(p) + 0.5, 0.0, 1.0);
    col = over(col, accentColor, fillMask);

    vec2 a = vec2(-0.24, 0.02) * s;
    vec2 b = vec2(-0.07, 0.19) * s;
    vec2 c = vec2(0.25, -0.17) * s;
    float l1 = length(b - a);
    float l2 = length(c - b);
    float drawn = draw * (l1 + l2);

    float dist = 1e5;
    if (drawn > 0.0) {
        vec2 e1 = a + (b - a) * clamp(drawn / l1, 0.0, 1.0);
        dist = sdSegment(p, a, e1);
        if (drawn > l1) {
            vec2 e2 = b + (c - b) * clamp((drawn - l1) / l2, 0.0, 1.0);
            dist = min(dist, sdSegment(p, b, e2));
        }
    }
    float stroke = max(params2.y, 1.0);
    float check = clamp(stroke * 0.5 - dist + 0.5, 0.0, 1.0);
    col = over(col, checkColor, check);

    fragColor = col * shape * qt_Opacity;
}
