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

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float pClamp = clamp(progress, 0.0, 1.0);

    // type 0: Fade
    if (transitionType < 0.5) {
        fragColor = vec4(vec3(pClamp), pClamp) * qt_Opacity;
        return;
    }

    // type 1: Wipe (params.x > 0.5: vertical, center split wipe)
    if (transitionType < 1.5) {
        bool isVertical = params.x > 0.5;
        float d;
        float halfSpan;
        if (isVertical) {
            d = abs(p.y - itemSize.y * 0.5);
            halfSpan = pClamp * itemSize.y * 0.5;
        } else {
            d = abs(p.x - itemSize.x * 0.5);
            halfSpan = pClamp * itemSize.x * 0.5;
        }
        float edge = clamp(halfSpan - d + 0.5, 0.0, 1.0);
        fragColor = vec4(vec3(edge), edge) * qt_Opacity;
        return;
    }

    // type 2: Circle (expanding circle from origin)
    if (transitionType < 2.5) {
        vec2 center = origin * itemSize;
        float d1 = length(center);
        float d2 = length(vec2(itemSize.x - center.x, center.y));
        float d3 = length(vec2(center.x, itemSize.y - center.y));
        float d4 = length(itemSize - center);
        float maxR = max(max(d1, d2), max(d3, d4));
        float currentR = pClamp * maxR;

        float dist = length(p - center);
        float edge = clamp(currentR - dist + 0.5, 0.0, 1.0);
        fragColor = vec4(vec3(edge), edge) * qt_Opacity;
        return;
    }

    // type 3: Swipe / directional wipe (params.y: swipe direction 0..7)
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

    float currentLimit = pClamp * total;
    float edge = clamp(currentLimit - dist + 0.5, 0.0, 1.0);
    fragColor = vec4(vec3(edge), edge) * qt_Opacity;
}
