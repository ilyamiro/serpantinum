#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 radii;
    vec4 tintColor;
    float bezel;
    float thickness;
    float ior;
    float dispersion;
    float frost;
    float rim;
    float saturation;
    float tintAmount;
    vec4 srcRect;
    vec2 cursor;
    float hover;
    float clear;
    float glassPad;
    float shadowAmt;
    float energy;
    float nest;
    float morph;
    float motion;
    vec4 sampleBounds;
    float unpremul;
    vec4 fieldInfo;
    vec4 fs0;
    vec4 fs1;
    vec4 fs2;
    vec4 fs3;
    vec4 fs4;
    vec4 fs5;
    vec4 fr0;
    vec4 fr1;
    vec4 fr2;
    vec4 fr3;
    vec4 fr4;
    vec4 fr5;
    vec4 fk0;
    vec4 fk1;
    vec4 fo0;
    vec4 fo1;
};

layout(binding = 1) uniform sampler2D src;

const int TAPS = 10;
const float GOLDEN = 2.39996323;
const float LENS_ZOOM = 0.045;
const float LENS_FULL = 180.0;
const float LENS_NONE = 420.0;
const float FRESNEL = 0.55;
const float INNER_SHADOW = 0.16;
const float BROAD_SPEC = 0.2;
const float GRAIN = 0.004;
const vec2 lightDir = vec2(-0.55, -0.83);

float sdRoundBox(vec2 p, vec2 b, vec4 r) {
    float rad = p.x > 0.0 ? (p.y > 0.0 ? r.z : r.y) : (p.y > 0.0 ? r.w : r.x);
    rad = min(rad, min(b.x, b.y));
    vec2 q = abs(p) - b + rad;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

float sdfCard(vec2 p) {
    return sdRoundBox(p, itemSize * 0.5 - glassPad, radii);
}

float sdShape(vec2 p, vec4 s, vec4 r) {
    if (s.z <= 0.0 || s.w <= 0.0) return 1e9;
    vec2 h = s.zw * 0.5;
    return sdRoundBox(p - (s.xy + h), h, r);
}

float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

vec2 screenPos(vec2 p) {
    return fieldInfo.zw + p + itemSize * 0.5;
}

vec4 pairK0;
vec4 pairK1;
vec4 pairK2;
vec4 pairK3;
vec4 pairX0;
vec4 pairX1;
vec4 pairX2;
vec4 pairX3;
vec4 ownX0;
vec2 ownX1;
vec4 upX0;
vec2 upX1;

float pairRadius(float ka, float kb, vec4 sa, vec4 sb) {
    return min(max(ka, kb), min(min(sa.z, sa.w), min(sb.z, sb.w)));
}

void prepareField() {
    ownX0 = step(vec4(1.5), fo0) * 1e9;
    ownX1 = step(vec2(1.5), fo1.xy) * 1e9;
    upX0 = (1.0 - vec4(greaterThan(fo0, vec4(0.5))) * vec4(lessThan(fo0, vec4(1.5)))) * 1e9;
    upX1 = (1.0 - vec2(greaterThan(fo1.xy, vec2(0.5))) * vec2(lessThan(fo1.xy, vec2(1.5)))) * 1e9;
    pairK0 = vec4(pairRadius(fk0.x, fk0.y, fs0, fs1), pairRadius(fk0.x, fk0.z, fs0, fs2), pairRadius(fk0.x, fk0.w, fs0, fs3), pairRadius(fk0.x, fk1.x, fs0, fs4));
    pairK1 = vec4(pairRadius(fk0.x, fk1.y, fs0, fs5), pairRadius(fk0.y, fk0.z, fs1, fs2), pairRadius(fk0.y, fk0.w, fs1, fs3), pairRadius(fk0.y, fk1.x, fs1, fs4));
    pairK2 = vec4(pairRadius(fk0.y, fk1.y, fs1, fs5), pairRadius(fk0.z, fk0.w, fs2, fs3), pairRadius(fk0.z, fk1.x, fs2, fs4), pairRadius(fk0.z, fk1.y, fs2, fs5));
    pairK3 = vec4(pairRadius(fk0.w, fk1.x, fs3, fs4), pairRadius(fk0.w, fk1.y, fs3, fs5), pairRadius(fk1.x, fk1.y, fs4, fs5), 0.0);
    pairX0 = vec4(max(ownX0.x, ownX0.y), max(ownX0.x, ownX0.z), max(ownX0.x, ownX0.w), max(ownX0.x, ownX1.x));
    pairX1 = vec4(max(ownX0.x, ownX1.y), max(ownX0.y, ownX0.z), max(ownX0.y, ownX0.w), max(ownX0.y, ownX1.x));
    pairX2 = vec4(max(ownX0.y, ownX1.y), max(ownX0.z, ownX0.w), max(ownX0.z, ownX1.x), max(ownX0.z, ownX1.y));
    pairX3 = vec4(max(ownX0.w, ownX1.x), max(ownX0.w, ownX1.y), max(ownX1.x, ownX1.y), 0.0);
}

void blendPair(float a, float b, float k, float x, inout float all, inout float own, inout float deep) {
    if (k <= 0.0) return;
    float hi = max(a, b);
    if (hi < k) {
        float s = smin(a, b, k);
        all = min(all, s);
        own = min(own, s + x);
    }
    float kIn = k + 3.0 * bezel;
    if (hi < kIn) deep = min(deep, smin(a, b, kIn));
}

void fieldEval(vec2 p, out float dist, out float cover) {
    vec2 q = screenPos(p);
    float d0 = sdShape(q, fs0, fr0);
    float d1 = sdShape(q, fs1, fr1);
    float d2 = sdShape(q, fs2, fr2);
    float d3 = sdShape(q, fs3, fr3);
    float d4 = sdShape(q, fs4, fr4);
    float d5 = sdShape(q, fs5, fr5);
    float all = min(min(min(d0, d1), min(d2, d3)), min(d4, d5));
    float own = min(min(min(d0 + ownX0.x, d1 + ownX0.y), min(d2 + ownX0.z, d3 + ownX0.w)), min(d4 + ownX1.x, d5 + ownX1.y));
    float up = min(min(min(d0 + upX0.x, d1 + upX0.y), min(d2 + upX0.z, d3 + upX0.w)), min(d4 + upX1.x, d5 + upX1.y));
    float deep = 1e9;
    blendPair(d0, d1, pairK0.x, pairX0.x, all, own, deep);
    blendPair(d0, d2, pairK0.y, pairX0.y, all, own, deep);
    blendPair(d0, d3, pairK0.z, pairX0.z, all, own, deep);
    blendPair(d0, d4, pairK0.w, pairX0.w, all, own, deep);
    blendPair(d0, d5, pairK1.x, pairX1.x, all, own, deep);
    blendPair(d1, d2, pairK1.y, pairX1.y, all, own, deep);
    blendPair(d1, d3, pairK1.z, pairX1.z, all, own, deep);
    blendPair(d1, d4, pairK1.w, pairX1.w, all, own, deep);
    blendPair(d1, d5, pairK2.x, pairX2.x, all, own, deep);
    blendPair(d2, d3, pairK2.y, pairX2.y, all, own, deep);
    blendPair(d2, d4, pairK2.z, pairX2.z, all, own, deep);
    blendPair(d2, d5, pairK2.w, pairX2.w, all, own, deep);
    blendPair(d3, d4, pairK3.x, pairX3.x, all, own, deep);
    blendPair(d3, d5, pairK3.y, pairX3.y, all, own, deep);
    blendPair(d4, d5, pairK3.z, pairX3.z, all, own, deep);
    dist = (all < 0.0 ? min(all, deep) : all) + glassPad;
    cover = max(clamp(0.5 - own - glassPad, 0.0, 1.0) - clamp(0.5 - up - glassPad, 0.0, 1.0), 0.0);
}

float sdf(vec2 p) {
    if (fieldInfo.x > 0.5) {
        float d;
        float c;
        fieldEval(p, d, c);
        return d;
    }
    return sdfCard(p);
}

vec4 fetchLod4(vec2 p, float lod) {
    vec2 uv = clamp((p + itemSize * 0.5) / itemSize, max(vec2(0.001), sampleBounds.xy), min(vec2(0.999), sampleBounds.zw));
    vec4 c = textureLod(src, srcRect.xy + uv * srcRect.zw, lod);
    return unpremul > 0.5 ? c : vec4(c.rgb, 1.0);
}

vec3 fetchLod(vec2 p, float lod) {
    return fetchLod4(p, lod).rgb;
}

float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float blurLod(float rad, int taps) {
    float R = max(rad, 0.5) * 0.9;
    float gap = R * sqrt(3.14159265 / float(taps));
    return clamp(log2(max(gap, 1.0)) - 0.15, 0.0, 6.0);
}

vec3 blurredAt(vec2 p, float rad, float lod, int taps) {
    float R = max(rad, 0.5) * 0.9;
    float rot = ign(gl_FragCoord.xy) * 6.2831853;
    vec4 acc = vec4(0.0);
    float wsum = 0.0;
    for (int i = 0; i < TAPS; ++i) {
        if (i >= taps) break;
        float fi = float(i) + 0.5;
        float r = sqrt(fi / float(taps));
        float a = fi * GOLDEN + rot;
        float w = exp(-2.2 * r * r);
        acc += fetchLod4(p + vec2(cos(a), sin(a)) * r * R, lod) * w;
        wsum += w;
    }
    return acc.a > 1e-4 * wsum ? acc.rgb / acc.a : vec3(0.0);
}

vec3 spectrum(float x) {
    return 0.5 + 0.5 * cos(6.2831853 * (x + vec3(0.0, 0.33, 0.67)));
}

vec2 displacement(vec3 normal, float index, float travel) {
    vec3 r = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / index);
    return r.xy / max(-r.z, 0.2) * travel;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    float dist;
    float coverage;
    if (fieldInfo.x > 0.5) {
        prepareField();
        fieldEval(p, dist, coverage);
        if (coverage <= 0.0) {
            fragColor = vec4(0.0);
            return;
        }
    } else {
        dist = sdfCard(p);
        coverage = clamp(0.5 - dist, 0.0, 1.0);
    }
    float shadow = 0.0;
    if (shadowAmt > 0.0) shadow = 0.13 * shadowAmt * (1.0 - smoothstep(-2.0, 9.0, sdf(p - vec2(0.0, 3.0))));
    if (dist > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadow) * qt_Opacity;
        return;
    }

    float t = max(-dist, 0.0);
    float bz = max(bezel, 1.0) * 1.45;
    vec2 g = vec2(0.0, -1.0);
    if (t < bz + 2.0) {
        const vec2 e = vec2(0.75, 0.0);
        vec2 grad = vec2(sdf(p + e.xy) - sdf(p - e.xy), sdf(p + e.yx) - sdf(p - e.yx));
        if (length(grad) > 0.0001) g = normalize(grad);
    }

    float u = clamp(t / bz, 0.0, 1.0);
    float om = 1.0 - u;
    float om4 = om * om * om * om;
    float slope = min((om * om * om) / pow(max(1.0 - om4, 1e-3), 0.75), 7.0);
    vec2 toCursor = cursor - itemSize * 0.5 - p;
    float cd = length(toCursor);
    float reach = max(40.0, min(itemSize.x, itemSize.y) * 0.6) * (1.0 + 0.4 * morph);
    float near = hover * exp(-cd * cd / (2.0 * reach * reach));
    float sigma = reach * 0.5;
    float bulgeH = hover * exp(-cd * cd / (2.0 * sigma * sigma)) * 0.35 * (1.0 + 1.4 * morph + 1.2 * motion) * thickness * (1.0 - 0.5 * nest);
    vec2 bulge = bulgeH * toCursor / (sigma * sigma);
    vec3 normal = normalize(vec3(g * slope - bulge, 1.0));
    float th = thickness * 1.35 * (1.0 + (0.12 + 0.3 * morph) * near + 0.74 * energy + 0.64 * motion);

    float edgeFall = om * om;
    float wobble = sin(dot(p, vec2(0.11, 0.09)) + t * 0.35) * 0.5 + 0.5;
    float warpK = 1.0 + 0.644 * motion + 0.368 * energy;
    vec2 warp = (-g * edgeFall * bz * (0.294 + 0.11 * wobble) + vec2(-g.y, g.x) * edgeFall * bz * 0.092 * (wobble - 0.5)) * warpK;
    vec2 dG = displacement(normal, ior, th) + warp;
    float spread = dispersion * (0.35 + 1.2 * edgeFall) * (1.0 + 2.2 * motion + 0.55 * energy);
    vec2 dR = dG * (1.0 + spread);
    vec2 dB = dG * (1.0 - spread);

    float rad = frost * mix(0.45, 1.0, smoothstep(0.0, bz, t));
    vec2 glassSize = itemSize - 2.0 * glassPad;
    vec2 zq = p / max(glassSize * 0.5, vec2(1.0));
    float zr = clamp(length(zq), 0.0, 1.0);
    float zoomAmt = LENS_ZOOM * (1.0 - 0.5 * nest) + 0.129 * clamp(energy, 0.0, 1.0) + 0.064 * motion;
    float lensK = 1.0 - smoothstep(LENS_FULL, LENS_NONE, max(glassSize.x, glassSize.y) * 0.5);
    vec2 ps = p + (vec2(p.x, p.y * (1.0 - 0.08 * 1.5)) * (1.0 - zoomAmt * (1.0 - zr * zr)) - p) * lensK;
    vec2 follow = clamp((cursor - itemSize * 0.5) / max(itemSize * 0.5, vec2(1.0)), vec2(-1.0), vec2(1.0));
    ps -= follow * 6.0 * near * morph * (1.0 - zr * zr * 0.5);
    bool interior = t >= bz && near < 0.02;
    int taps = interior ? 6 : (frost <= 1.2 ? 6 : TAPS);
    float lod = blurLod(rad, taps);
    vec3 col = blurredAt(ps + dG, rad, lod, taps);
    if (!interior && dot(dG, dG) > 0.25) {
        vec4 cR = fetchLod4(ps + dR, lod + 0.5);
        vec4 cB = fetchLod4(ps + dB, lod + 0.5);
        if (cR.a > 0.05) col.r = cR.r / cR.a;
        if (cB.a > 0.05) col.b = cB.b / cB.a;
    }

    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(l), col, saturation);

    col *= 1.0 - (1.0 - nest) * 0.06 * exp(-t / 6.0) * clamp(g.y, 0.0, 1.0);
    col *= 1.0 - (1.0 - nest) * 0.025 * exp(-t / (bz * 0.45));

    vec2 cursorDir = cd > 0.001 ? toCursor / cd : normalize(lightDir);
    vec2 L = normalize(mix(normalize(lightDir), cursorDir, hover * 0.4));
    float facing = dot(g, L);
    float spec = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);

    float fres = pow(1.0 - normal.z, 1.5) * (1.0 - 0.6 * nest);
    if (fres > 0.001) {
        vec4 e = fetchLod4(p + g * (t + bz * 1.4), min(lod + 2.0, 6.0));
        vec3 env = e.a > 1e-3 ? e.rgb / e.a : col;
        env = env * 1.12 + 0.03;
        col = mix(col, env, clamp(fres * FRESNEL * (0.4 + 0.6 * max(facing, 0.0)), 0.0, 0.6));
    }
    float counter = exp(-t / (bz * 0.55)) * max(-facing, 0.0);
    col *= 1.0 - INNER_SHADOW * counter * (1.0 - 0.7 * nest);
    float hair = exp(-t / 1.1);
    float wide = exp(-t / 5.0);
    float edgeHi = (hair * (0.18 + 0.78 * spec) + wide * 0.10 * (0.30 + spec)) * rim * (1.0 + 0.5 * near + 0.9 * energy);
    float broad = exp(-t / (bz * 0.45)) * pow(max(facing, 0.0), 2.0) * BROAD_SPEC * rim * (1.0 + 0.5 * near);
    float mx = (t - bz * 0.5) / (bz * 0.2 + 1.0);
    float men = exp(-mx * mx) * 0.07 * (0.35 + spec) * rim;
    vec3 fringe = vec3(0.0);
    if (t < bz * 2.5) {
        float fb = (t - bz * 0.42) / (bz * 0.22 + 1.0);
        float fringeBand = exp(-fb * fb);
        float fringePhase = dot(g, vec2(0.7, 0.45)) * 0.9 + t / (bz * 1.6) + 0.15 * dot(p, vec2(0.004, 0.003));
        fringe = (spectrum(fringePhase) - 0.5) * fringeBand * (0.04 + 0.08 * spec) * rim * (1.0 + 3.0 * motion);
    }
    vec3 tcol = tintColor.rgb;
    float tA = clamp(tintAmount * (0.7 + 0.6 * l), 0.0, 1.0);
    float lensA = smoothstep(0.0, 1.0, length(dG) * 0.5);
    vec3 light = vec3(edgeHi + men + broad + energy * 0.03) + fringe;
    light += vec3(0.02 * clear * lensA);

    vec3 opaqueRgb = col * mix(vec3(1.0), tcol, tA);
    vec3 clearRgb = col * lensA * (1.0 - tA) + tcol * tA;
    float clearA = lensA * (1.0 - tA) + tA;

    vec3 premul = mix(opaqueRgb, clearRgb, clear);
    premul += light;
    float alpha = mix(1.0, clearA, clear);

    float gn = hash12(gl_FragCoord.xy) + hash12(gl_FragCoord.xy * 1.7 + 17.0) - 1.0;
    premul += vec3(gn * GRAIN * (1.0 - 0.7 * nest)) * alpha;

    float a = coverage * qt_Opacity;
    float outA = clamp(alpha, 0.0, 1.0) * coverage + shadow * (1.0 - coverage);
    fragColor = vec4(clamp(premul, 0.0, 1.0) * a, outA * qt_Opacity);
}
