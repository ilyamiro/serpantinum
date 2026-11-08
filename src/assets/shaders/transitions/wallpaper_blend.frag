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

float paintHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + params.z * 13.17) * 43758.5453);
}

float paintNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(paintHash(i), paintHash(i + vec2(1.0, 0.0)), f.x),
               mix(paintHash(i + vec2(0.0, 1.0)), paintHash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float paintFbm(vec2 p) {
    return 0.52 * paintNoise(p) + 0.30 * paintNoise(p * 2.7 + 19.1) + 0.18 * paintNoise(p * 7.3 + 47.3);
}

float paintCellSize() {
    return max(3.0, floor(itemSize.y / 270.0 + 0.5));
}

float paintArrival(vec2 cell) {
    const float COLONY = 1.0 / 3.0;
    float cs = paintCellSize();
    vec2 p = (cell + 0.5) * cs / itemSize.y;
    vec2 w = vec2(paintFbm(p * 4.0 + 11.0), paintFbm(p * 4.0 + 37.0)) - 0.5;
    vec2 q = (p + w * 0.16) / COLONY;
    vec2 home = floor(q);
    vec2 originCell = floor(origin * itemSize / itemSize.y / COLONY);
    float best = 1e9;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = home + vec2(float(x), float(y));
            vec2 site;
            float t0;
            if (g == originCell) {
                site = origin * itemSize / itemSize.y / COLONY;
                t0 = 0.0;
            } else {
                site = g + 0.15 + 0.7 * vec2(paintHash(g + 3.1), paintHash(g + 8.7));
                t0 = 0.45 * pow(paintHash(g + 5.3), 1.5);
            }
            best = min(best, t0 + 0.55 * pow(clamp(length(q - site) / 1.9, 0.0, 1.0), 1.3));
        }
    }
    float rough = 0.75 + 0.5 * paintFbm(p * 9.0 + 71.0);
    float grain = (paintHash(cell * 1.37 + 0.5) - 0.5) * 0.03;
    return clamp(best * rough * 2.0 + grain, 0.0, 0.985);
}

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

    if (transitionType > 3.5) {
        return paintArrival(floor(p / paintCellSize())) <= pClamp ? 1.0 : 0.0;
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
