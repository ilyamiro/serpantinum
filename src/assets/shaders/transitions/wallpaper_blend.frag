#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float progress;
    float transitionType;
    vec2 origin;
    vec4 params;
};

layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

float revealAt(vec2 p) {
    if (progress < 0.0) return 0.0;
    float pClamp = clamp(progress, 0.0, 1.0);
    if (pClamp >= 1.0) return 1.0;

    if (transitionType < 0.5) {
        return pClamp;
    }

    if (transitionType < 1.5) {
        float d;
        float halfSpan;
        if (params.x > 0.5) {
            d = abs(p.y - itemSize.y * 0.5);
            halfSpan = pClamp * itemSize.y * 0.5;
        } else {
            d = abs(p.x - itemSize.x * 0.5);
            halfSpan = pClamp * itemSize.x * 0.5;
        }
        return clamp(halfSpan - d + 0.5, 0.0, 1.0);
    }

    if (transitionType < 2.5) {
        vec2 center = origin * itemSize;
        float d1 = length(center);
        float d2 = length(vec2(itemSize.x - center.x, center.y));
        float d3 = length(vec2(center.x, itemSize.y - center.y));
        float d4 = length(itemSize - center);
        float maxR = max(max(d1, d2), max(d3, d4));
        return clamp(pClamp * maxR - length(p - center) + 0.5, 0.0, 1.0);
    }

    int dir = int(floor(params.y + 0.5));
    float dist = 0.0;
    float total = 1.0;

    if (dir == 0) {
        dist = p.x;
        total = itemSize.x;
    } else if (dir == 1) {
        dist = itemSize.x - p.x;
        total = itemSize.x;
    } else if (dir == 2) {
        dist = p.y;
        total = itemSize.y;
    } else if (dir == 3) {
        dist = itemSize.y - p.y;
        total = itemSize.y;
    } else {
        vec2 dirVec;
        vec2 originPt;
        if (dir == 4) {
            originPt = vec2(0.0, 0.0);
            dirVec = normalize(itemSize);
        } else if (dir == 5) {
            originPt = vec2(itemSize.x, 0.0);
            dirVec = normalize(vec2(-itemSize.x, itemSize.y));
        } else if (dir == 6) {
            originPt = vec2(0.0, itemSize.y);
            dirVec = normalize(vec2(itemSize.x, -itemSize.y));
        } else {
            originPt = itemSize;
            dirVec = normalize(-itemSize);
        }
        dist = dot(p - originPt, dirVec);
        total = length(itemSize);
    }

    return clamp(pClamp * total - dist + 0.5, 0.0, 1.0);
}

void main() {
    float m = revealAt(qt_TexCoord0 * itemSize);
    vec4 oldC = texture(oldTex, qt_TexCoord0);
    vec4 newC = texture(newTex, qt_TexCoord0);
    fragColor = mix(oldC, newC, m) * qt_Opacity;
}
