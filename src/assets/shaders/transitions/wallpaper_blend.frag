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

const float PI = 3.14159265;
const float TAU = 6.28318530;

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

void directionalCoords(vec2 p, int dir, out float dist, out float total, out float across) {
    if (dir == 0) {
        dist = p.x;
        total = itemSize.x;
        across = p.y / max(itemSize.y, 1.0);
    } else if (dir == 1) {
        dist = itemSize.x - p.x;
        total = itemSize.x;
        across = p.y / max(itemSize.y, 1.0);
    } else if (dir == 2) {
        dist = p.y;
        total = itemSize.y;
        across = p.x / max(itemSize.x, 1.0);
    } else if (dir == 3) {
        dist = itemSize.y - p.y;
        total = itemSize.y;
        across = p.x / max(itemSize.x, 1.0);
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
        vec2 perp = vec2(-dirVec.y, dirVec.x);
        total = length(itemSize);
        dist = dot(p - originPt, dirVec);
        across = dot(p - itemSize * 0.5, perp) / max(total, 1.0) + 0.5;
    }
}

vec4 hexCoords(vec2 uv) {
    vec2 r = vec2(1.0, 1.7320508);
    vec2 h = r * 0.5;
    vec2 a = mod(uv, r) - h;
    vec2 b = mod(uv - h, r) - h;
    vec2 gv = dot(a, a) < dot(b, b) ? a : b;
    vec2 id = uv - gv;
    return vec4(gv.x, gv.y, id.x, id.y);
}

float hexDist(vec2 p) {
    vec2 q = abs(p);
    return max(dot(q, vec2(0.5, 0.8660254)), q.x);
}

float inkField(vec2 p) {
    float invH = 1.0 / max(itemSize.y, 1.0);
    vec2 uv = p * invH;
    vec2 orig = origin * itemSize * invH;
    float aspect = itemSize.x * invH;
    float r1 = length(orig);
    float r2 = length(vec2(aspect, 0.0) - orig);
    float r3 = length(vec2(0.0, 1.0) - orig);
    float r4 = length(vec2(aspect, 1.0) - orig);
    float maxR = max(max(r1, r2), max(r3, r4));
    vec2 warp = vec2(
        paintFbm(uv * 3.2 + vec2(5.2, 1.3)),
        paintFbm(uv * 3.2 + vec2(17.8, 9.4))
    ) - 0.5;
    float detail = paintFbm(uv * 6.5 + warp * 1.4 + vec2(31.1, 22.7));
    float fine = paintNoise(uv * 16.0 + warp * 2.2 + vec2(7.3, 41.9));
    float radial = length(uv - orig) / max(maxR, 0.001);
    float organic = detail * 0.72 + fine * 0.28;
    return clamp(radial * 0.62 + organic * 0.38, 0.0, 1.0);
}

float revealAt(vec2 p) {
    if (progress <= 0.0) return 0.0;
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

    if (transitionType < 3.5) {
        int dir = int(floor(params.y + 0.5));
        float dist;
        float total;
        float across;
        directionalCoords(p, dir, dist, total, across);
        return clamp(pClamp * total - dist + 0.5, 0.0, 1.0);
    }

    if (transitionType < 4.5) {
        return paintArrival(floor(p / paintCellSize())) <= pClamp ? 1.0 : 0.0;
    }

    if (transitionType < 5.5) {
        int dir = int(floor(params.y + 0.5));
        float dist;
        float total;
        float across;
        directionalCoords(p, dir, dist, total, across);
        float env = sin(pClamp * PI);
        float phase = pClamp * 7.5 + params.z * 0.37;
        float w = sin(across * TAU * 1.25 + phase) * 0.54
                + sin(across * TAU * 2.55 - phase * 1.3 + 1.4) * 0.30
                + sin(across * TAU * 4.3 + phase * 0.8 + 2.7) * 0.16;
        float surface = pClamp * total + w * total * 0.085 * env;
        return clamp(0.5 - (dist - surface), 0.0, 1.0);
    }

    if (transitionType < 6.5) {
        bool isVertical = params.x > 0.5;
        float span = isVertical ? itemSize.x : itemSize.y;
        float coord = isVertical ? p.x : p.y;
        float count = clamp(floor(span / 95.0 + 0.5), 6.0, 16.0);
        float slatW = span / count;
        float idx = min(floor(coord / slatW), count - 1.0);
        float normIdx = idx / max(count - 1.0, 1.0);
        if (fract(params.z * 0.13) > 0.5) normIdx = 1.0 - normIdx;
        float lp = clamp((pClamp - normIdx * 0.36) / 0.64, 0.0, 1.0);
        lp = lp * lp * (3.0 - 2.0 * lp);
        if (lp <= 0.0) return 0.0;
        if (lp >= 1.0) return 1.0;
        float localPos = coord - idx * slatW;
        return clamp(0.5 - (localPos - lp * slatW), 0.0, 1.0);
    }

    if (transitionType < 7.5) {
        vec2 center = origin * itemSize;
        vec2 rel = p - center;
        float r = length(rel);
        float ang = mod(atan(rel.x, -rel.y) + TAU, TAU) / TAU;
        float env = sin(pClamp * PI);
        float edgeW = max(1.0, r * 0.055 * env);
        float m = smoothstep(-edgeW, 0.75, (pClamp - ang) * TAU * r);
        if (rel.y < 0.0 && abs(rel.x) < 0.5) {
            float leftCov = smoothstep(-edgeW, 0.75, (pClamp - 1.0) * TAU * r);
            float rightCov = smoothstep(-edgeW, 0.75, pClamp * TAU * r);
            m = mix(leftCov, rightCov, clamp(rel.x + 0.5, 0.0, 1.0));
        }
        if (r < 1.5) m = mix(pClamp, m, clamp(r / 1.5, 0.0, 1.0));
        return m;
    }

    if (transitionType < 8.5) {
        float targetPx = params.x > 1.0 ? params.x : 80.0;
        float hexSize = max(5.0, targetPx * max(itemSize.y / 1080.0, 0.17));
        vec4 hc = hexCoords(p / hexSize);
        vec2 cellId = floor(vec2(hc.z * 2.0, hc.w / 0.8660254) + 0.5);
        vec2 cellPos = hc.zw * hexSize;
        vec2 center = origin * itemSize;
        float d1 = length(center);
        float d2 = length(vec2(itemSize.x - center.x, center.y));
        float d3 = length(vec2(center.x, itemSize.y - center.y));
        float d4 = length(itemSize - center);
        float maxR = max(max(d1, d2), max(d3, d4));
        float waveT = clamp(length(cellPos - center) / max(maxR, 1.0), 0.0, 1.0);
        float delay = waveT * 0.56 + paintHash(cellId + 4.2) * 0.16;
        float lp = clamp((pClamp - delay) / 0.28, 0.0, 1.0);
        lp = lp * lp * (3.0 - 2.0 * lp);
        if (lp <= 0.0001) return 0.0;
        if (lp >= 0.9999) return 1.0;
        float hd = hexDist(hc.xy);
        float edgePx = (lp * 0.506 - hd) * hexSize;
        return clamp(edgePx + 0.5, 0.0, 1.0);
    }

    float field = inkField(p);
    float env = sin(pClamp * PI);
    float feather = 0.028 * env + 0.004;
    float threshold = pClamp * (1.0 + 2.0 * feather) - feather;
    return 1.0 - smoothstep(threshold - feather, threshold + feather, field);
}

void main() {
    float m = revealAt(qt_TexCoord0 * itemSize);
    vec4 oldC = texture(oldTex, qt_TexCoord0);
    vec4 newC = texture(newTex, qt_TexCoord0);
    fragColor = mix(oldC, newC, m) * qt_Opacity;
}
