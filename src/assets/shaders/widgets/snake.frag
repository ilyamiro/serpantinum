#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 area;
    vec4 params;
    vec4 fillColor;
    vec4 head;
    vec4 tail;
    vec4 tongueA;
    vec4 tongueB;
    vec4 skip0;
    vec4 skip1;
    vec4 skip2;
    vec4 skip3;
    vec4 skip4;
    vec4 j0;
    vec4 j1;
    vec4 j2;
    vec4 j3;
    vec4 j4;
    vec4 j5;
    vec4 j6;
    vec4 j7;
    vec4 j8;
    vec4 j9;
    vec4 j10;
    vec4 j11;
    vec4 j12;
    vec4 j13;
    vec4 j14;
    vec4 j15;
    vec4 j16;
    vec4 j17;
    vec4 j18;
    vec4 j19;
    vec4 j20;
    vec4 j21;
    vec4 j22;
    vec4 j23;
    vec4 j24;
    vec4 j25;
    vec4 j26;
    vec4 j27;
    vec4 j28;
    vec4 j29;
    vec4 j30;
    vec4 j31;
    vec4 j32;
    vec4 j33;
    vec4 j34;
    vec4 j35;
    vec4 j36;
    vec4 j37;
    vec4 j38;
    vec4 j39;
    vec4 j40;
    vec4 j41;
    vec4 j42;
    vec4 j43;
    vec4 j44;
    vec4 j45;
    vec4 j46;
    vec4 j47;
};

const float PI = 3.14159265;
const float CHUNK_REACH = 48.0;
const float SHADOW_SIGMA = 4.5;

float halfWidth(float k, float n) {
    if (k < 0.5) return 4.9;
    if (k < 1.5) return 4.8;
    if (k < 2.5) return 4.95;
    float u = (k - 2.0) / (n - 3.0);
    if (u < 0.65) return 5.1 + sin((u / 0.65) * PI) * 0.75;
    float t = (u - 0.65) / 0.35;
    return 5.1 - 2.9 * t * t;
}

float segDist(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

vec2 cubicAt(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
    float s = 1.0 - t;
    return s * s * s * p0 + 3.0 * s * s * t * p1 + 3.0 * s * t * t * p2 + t * t * t * p3;
}

vec2 cubicTangent(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
    float s = 1.0 - t;
    return 3.0 * s * s * (p1 - p0) + 6.0 * s * t * (p2 - p1) + 3.0 * t * t * (p3 - p2);
}

float profileDist(float u, float v, vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
    float t = clamp((p0.x - u) / (p0.x - p3.x), 0.0, 1.0);
    for (int i = 0; i < 4; i++) {
        float du = cubicTangent(p0, p1, p2, p3, t).x;
        t = clamp(t - (cubicAt(p0, p1, p2, p3, t).x - u) / (abs(du) > 1e-4 ? du : -1e-4), 0.0, 1.0);
    }
    vec2 d = cubicTangent(p0, p1, p2, p3, t);
    float slope = d.y / (abs(d.x) > 1e-4 ? d.x : -1e-4);
    return (v - cubicAt(p0, p1, p2, p3, t).y) / sqrt(1.0 + slope * slope);
}

float headDist(vec2 p) {
    vec2 rel = p - head.xy;
    vec2 n = vec2(-head.w, head.z);
    float u = dot(rel, head.zw);
    float v = abs(dot(rel, n));
    if (u < -12.0 || u > 40.0 || v > 24.0) return 1e5;

    float outer = u >= 8.8
        ? profileDist(u, v, vec2(26.6, 0.0), vec2(26.2, 2.4), vec2(17.4, 7.4), vec2(8.8, 8.8))
        : profileDist(u, v, vec2(8.8, 8.8), vec2(4.2, 9.0), vec2(-1.4, 6.8), vec2(-6.8, 4.8));
    outer = max(outer, u - 26.6);
    if (u < -6.8) outer = max(outer, -6.8 - u);

    float hole = u >= 8.8
        ? profileDist(u, v, vec2(17.6, 0.0), vec2(14.533, 1.1667), vec2(11.6, 2.0833), vec2(8.8, 2.75))
        : profileDist(u, v, vec2(8.8, 2.75), vec2(6.133, 2.0167), vec2(3.367, 1.1), vec2(0.5, 0.0));
    hole = max(hole, max(0.5 - u, u - 17.6));

    return max(outer, -hole);
}

bool inRect(vec2 p, vec4 r) {
    return p.x >= r.x && p.y >= r.y && p.x < r.z && p.y < r.w;
}

float shadowBand(float d, float width) {
    float a = 1.0 / (1.0 + exp(1.702 * d / SHADOW_SIGMA));
    float b = 1.0 / (1.0 + exp(1.702 * (d + width) / SHADOW_SIGMA));
    return a - b;
}

void main() {
    vec2 p = area.xy + qt_TexCoord0 * area.zw;
    if (inRect(p, skip0) || inRect(p, skip1) || inRect(p, skip2) || inRect(p, skip3) || inRect(p, skip4)) {
        fragColor = vec4(0.0);
        return;
    }
    float n = params.x;
    int count = int(n + 0.5);
    float px = params.z;

    float bodyDist = 1e5;
    int topIndex = 1000;

    if (count > 0 && length(p - j2.xy) < CHUNK_REACH) {
        if (count > 2) { float d = segDist(p, j0.zw, j1.xy, halfWidth(1.0, n), halfWidth(2.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 1) topIndex = 1; }
        if (count > 3) { float d = segDist(p, j1.xy, j1.zw, halfWidth(2.0, n), halfWidth(3.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 2) topIndex = 2; }
        if (count > 4) { float d = segDist(p, j1.zw, j2.xy, halfWidth(3.0, n), halfWidth(4.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 3) topIndex = 3; }
        if (count > 5) { float d = segDist(p, j2.xy, j2.zw, halfWidth(4.0, n), halfWidth(5.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 4) topIndex = 4; }
        if (count > 6) { float d = segDist(p, j2.zw, j3.xy, halfWidth(5.0, n), halfWidth(6.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 5) topIndex = 5; }
        if (count > 7) { float d = segDist(p, j3.xy, j3.zw, halfWidth(6.0, n), halfWidth(7.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 6) topIndex = 6; }
        if (count > 8) { float d = segDist(p, j3.zw, j4.xy, halfWidth(7.0, n), halfWidth(8.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 7) topIndex = 7; }
    }
    if (count > 8 && length(p - j6.xy) < CHUNK_REACH) {
        if (count > 9) { float d = segDist(p, j4.xy, j4.zw, halfWidth(8.0, n), halfWidth(9.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 8) topIndex = 8; }
        if (count > 10) { float d = segDist(p, j4.zw, j5.xy, halfWidth(9.0, n), halfWidth(10.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 9) topIndex = 9; }
        if (count > 11) { float d = segDist(p, j5.xy, j5.zw, halfWidth(10.0, n), halfWidth(11.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 10) topIndex = 10; }
        if (count > 12) { float d = segDist(p, j5.zw, j6.xy, halfWidth(11.0, n), halfWidth(12.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 11) topIndex = 11; }
        if (count > 13) { float d = segDist(p, j6.xy, j6.zw, halfWidth(12.0, n), halfWidth(13.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 12) topIndex = 12; }
        if (count > 14) { float d = segDist(p, j6.zw, j7.xy, halfWidth(13.0, n), halfWidth(14.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 13) topIndex = 13; }
        if (count > 15) { float d = segDist(p, j7.xy, j7.zw, halfWidth(14.0, n), halfWidth(15.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 14) topIndex = 14; }
        if (count > 16) { float d = segDist(p, j7.zw, j8.xy, halfWidth(15.0, n), halfWidth(16.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 15) topIndex = 15; }
    }
    if (count > 16 && length(p - j10.xy) < CHUNK_REACH) {
        if (count > 17) { float d = segDist(p, j8.xy, j8.zw, halfWidth(16.0, n), halfWidth(17.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 16) topIndex = 16; }
        if (count > 18) { float d = segDist(p, j8.zw, j9.xy, halfWidth(17.0, n), halfWidth(18.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 17) topIndex = 17; }
        if (count > 19) { float d = segDist(p, j9.xy, j9.zw, halfWidth(18.0, n), halfWidth(19.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 18) topIndex = 18; }
        if (count > 20) { float d = segDist(p, j9.zw, j10.xy, halfWidth(19.0, n), halfWidth(20.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 19) topIndex = 19; }
        if (count > 21) { float d = segDist(p, j10.xy, j10.zw, halfWidth(20.0, n), halfWidth(21.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 20) topIndex = 20; }
        if (count > 22) { float d = segDist(p, j10.zw, j11.xy, halfWidth(21.0, n), halfWidth(22.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 21) topIndex = 21; }
        if (count > 23) { float d = segDist(p, j11.xy, j11.zw, halfWidth(22.0, n), halfWidth(23.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 22) topIndex = 22; }
        if (count > 24) { float d = segDist(p, j11.zw, j12.xy, halfWidth(23.0, n), halfWidth(24.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 23) topIndex = 23; }
    }
    if (count > 24 && length(p - j14.xy) < CHUNK_REACH) {
        if (count > 25) { float d = segDist(p, j12.xy, j12.zw, halfWidth(24.0, n), halfWidth(25.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 24) topIndex = 24; }
        if (count > 26) { float d = segDist(p, j12.zw, j13.xy, halfWidth(25.0, n), halfWidth(26.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 25) topIndex = 25; }
        if (count > 27) { float d = segDist(p, j13.xy, j13.zw, halfWidth(26.0, n), halfWidth(27.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 26) topIndex = 26; }
        if (count > 28) { float d = segDist(p, j13.zw, j14.xy, halfWidth(27.0, n), halfWidth(28.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 27) topIndex = 27; }
        if (count > 29) { float d = segDist(p, j14.xy, j14.zw, halfWidth(28.0, n), halfWidth(29.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 28) topIndex = 28; }
        if (count > 30) { float d = segDist(p, j14.zw, j15.xy, halfWidth(29.0, n), halfWidth(30.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 29) topIndex = 29; }
        if (count > 31) { float d = segDist(p, j15.xy, j15.zw, halfWidth(30.0, n), halfWidth(31.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 30) topIndex = 30; }
        if (count > 32) { float d = segDist(p, j15.zw, j16.xy, halfWidth(31.0, n), halfWidth(32.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 31) topIndex = 31; }
    }
    if (count > 32 && length(p - j18.xy) < CHUNK_REACH) {
        if (count > 33) { float d = segDist(p, j16.xy, j16.zw, halfWidth(32.0, n), halfWidth(33.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 32) topIndex = 32; }
        if (count > 34) { float d = segDist(p, j16.zw, j17.xy, halfWidth(33.0, n), halfWidth(34.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 33) topIndex = 33; }
        if (count > 35) { float d = segDist(p, j17.xy, j17.zw, halfWidth(34.0, n), halfWidth(35.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 34) topIndex = 34; }
        if (count > 36) { float d = segDist(p, j17.zw, j18.xy, halfWidth(35.0, n), halfWidth(36.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 35) topIndex = 35; }
        if (count > 37) { float d = segDist(p, j18.xy, j18.zw, halfWidth(36.0, n), halfWidth(37.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 36) topIndex = 36; }
        if (count > 38) { float d = segDist(p, j18.zw, j19.xy, halfWidth(37.0, n), halfWidth(38.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 37) topIndex = 37; }
        if (count > 39) { float d = segDist(p, j19.xy, j19.zw, halfWidth(38.0, n), halfWidth(39.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 38) topIndex = 38; }
        if (count > 40) { float d = segDist(p, j19.zw, j20.xy, halfWidth(39.0, n), halfWidth(40.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 39) topIndex = 39; }
    }
    if (count > 40 && length(p - j22.xy) < CHUNK_REACH) {
        if (count > 41) { float d = segDist(p, j20.xy, j20.zw, halfWidth(40.0, n), halfWidth(41.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 40) topIndex = 40; }
        if (count > 42) { float d = segDist(p, j20.zw, j21.xy, halfWidth(41.0, n), halfWidth(42.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 41) topIndex = 41; }
        if (count > 43) { float d = segDist(p, j21.xy, j21.zw, halfWidth(42.0, n), halfWidth(43.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 42) topIndex = 42; }
        if (count > 44) { float d = segDist(p, j21.zw, j22.xy, halfWidth(43.0, n), halfWidth(44.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 43) topIndex = 43; }
        if (count > 45) { float d = segDist(p, j22.xy, j22.zw, halfWidth(44.0, n), halfWidth(45.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 44) topIndex = 44; }
        if (count > 46) { float d = segDist(p, j22.zw, j23.xy, halfWidth(45.0, n), halfWidth(46.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 45) topIndex = 45; }
        if (count > 47) { float d = segDist(p, j23.xy, j23.zw, halfWidth(46.0, n), halfWidth(47.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 46) topIndex = 46; }
        if (count > 48) { float d = segDist(p, j23.zw, j24.xy, halfWidth(47.0, n), halfWidth(48.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 47) topIndex = 47; }
    }
    if (count > 48 && length(p - j26.xy) < CHUNK_REACH) {
        if (count > 49) { float d = segDist(p, j24.xy, j24.zw, halfWidth(48.0, n), halfWidth(49.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 48) topIndex = 48; }
        if (count > 50) { float d = segDist(p, j24.zw, j25.xy, halfWidth(49.0, n), halfWidth(50.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 49) topIndex = 49; }
        if (count > 51) { float d = segDist(p, j25.xy, j25.zw, halfWidth(50.0, n), halfWidth(51.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 50) topIndex = 50; }
        if (count > 52) { float d = segDist(p, j25.zw, j26.xy, halfWidth(51.0, n), halfWidth(52.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 51) topIndex = 51; }
        if (count > 53) { float d = segDist(p, j26.xy, j26.zw, halfWidth(52.0, n), halfWidth(53.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 52) topIndex = 52; }
        if (count > 54) { float d = segDist(p, j26.zw, j27.xy, halfWidth(53.0, n), halfWidth(54.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 53) topIndex = 53; }
        if (count > 55) { float d = segDist(p, j27.xy, j27.zw, halfWidth(54.0, n), halfWidth(55.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 54) topIndex = 54; }
        if (count > 56) { float d = segDist(p, j27.zw, j28.xy, halfWidth(55.0, n), halfWidth(56.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 55) topIndex = 55; }
    }
    if (count > 56 && length(p - j30.xy) < CHUNK_REACH) {
        if (count > 57) { float d = segDist(p, j28.xy, j28.zw, halfWidth(56.0, n), halfWidth(57.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 56) topIndex = 56; }
        if (count > 58) { float d = segDist(p, j28.zw, j29.xy, halfWidth(57.0, n), halfWidth(58.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 57) topIndex = 57; }
        if (count > 59) { float d = segDist(p, j29.xy, j29.zw, halfWidth(58.0, n), halfWidth(59.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 58) topIndex = 58; }
        if (count > 60) { float d = segDist(p, j29.zw, j30.xy, halfWidth(59.0, n), halfWidth(60.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 59) topIndex = 59; }
        if (count > 61) { float d = segDist(p, j30.xy, j30.zw, halfWidth(60.0, n), halfWidth(61.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 60) topIndex = 60; }
        if (count > 62) { float d = segDist(p, j30.zw, j31.xy, halfWidth(61.0, n), halfWidth(62.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 61) topIndex = 61; }
        if (count > 63) { float d = segDist(p, j31.xy, j31.zw, halfWidth(62.0, n), halfWidth(63.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 62) topIndex = 62; }
        if (count > 64) { float d = segDist(p, j31.zw, j32.xy, halfWidth(63.0, n), halfWidth(64.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 63) topIndex = 63; }
    }
    if (count > 64 && length(p - j34.xy) < CHUNK_REACH) {
        if (count > 65) { float d = segDist(p, j32.xy, j32.zw, halfWidth(64.0, n), halfWidth(65.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 64) topIndex = 64; }
        if (count > 66) { float d = segDist(p, j32.zw, j33.xy, halfWidth(65.0, n), halfWidth(66.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 65) topIndex = 65; }
        if (count > 67) { float d = segDist(p, j33.xy, j33.zw, halfWidth(66.0, n), halfWidth(67.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 66) topIndex = 66; }
        if (count > 68) { float d = segDist(p, j33.zw, j34.xy, halfWidth(67.0, n), halfWidth(68.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 67) topIndex = 67; }
        if (count > 69) { float d = segDist(p, j34.xy, j34.zw, halfWidth(68.0, n), halfWidth(69.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 68) topIndex = 68; }
        if (count > 70) { float d = segDist(p, j34.zw, j35.xy, halfWidth(69.0, n), halfWidth(70.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 69) topIndex = 69; }
        if (count > 71) { float d = segDist(p, j35.xy, j35.zw, halfWidth(70.0, n), halfWidth(71.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 70) topIndex = 70; }
        if (count > 72) { float d = segDist(p, j35.zw, j36.xy, halfWidth(71.0, n), halfWidth(72.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 71) topIndex = 71; }
    }
    if (count > 72 && length(p - j38.xy) < CHUNK_REACH) {
        if (count > 73) { float d = segDist(p, j36.xy, j36.zw, halfWidth(72.0, n), halfWidth(73.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 72) topIndex = 72; }
        if (count > 74) { float d = segDist(p, j36.zw, j37.xy, halfWidth(73.0, n), halfWidth(74.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 73) topIndex = 73; }
        if (count > 75) { float d = segDist(p, j37.xy, j37.zw, halfWidth(74.0, n), halfWidth(75.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 74) topIndex = 74; }
        if (count > 76) { float d = segDist(p, j37.zw, j38.xy, halfWidth(75.0, n), halfWidth(76.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 75) topIndex = 75; }
        if (count > 77) { float d = segDist(p, j38.xy, j38.zw, halfWidth(76.0, n), halfWidth(77.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 76) topIndex = 76; }
        if (count > 78) { float d = segDist(p, j38.zw, j39.xy, halfWidth(77.0, n), halfWidth(78.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 77) topIndex = 77; }
        if (count > 79) { float d = segDist(p, j39.xy, j39.zw, halfWidth(78.0, n), halfWidth(79.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 78) topIndex = 78; }
        if (count > 80) { float d = segDist(p, j39.zw, j40.xy, halfWidth(79.0, n), halfWidth(80.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 79) topIndex = 79; }
    }
    if (count > 80 && length(p - j42.xy) < CHUNK_REACH) {
        if (count > 81) { float d = segDist(p, j40.xy, j40.zw, halfWidth(80.0, n), halfWidth(81.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 80) topIndex = 80; }
        if (count > 82) { float d = segDist(p, j40.zw, j41.xy, halfWidth(81.0, n), halfWidth(82.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 81) topIndex = 81; }
        if (count > 83) { float d = segDist(p, j41.xy, j41.zw, halfWidth(82.0, n), halfWidth(83.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 82) topIndex = 82; }
        if (count > 84) { float d = segDist(p, j41.zw, j42.xy, halfWidth(83.0, n), halfWidth(84.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 83) topIndex = 83; }
        if (count > 85) { float d = segDist(p, j42.xy, j42.zw, halfWidth(84.0, n), halfWidth(85.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 84) topIndex = 84; }
        if (count > 86) { float d = segDist(p, j42.zw, j43.xy, halfWidth(85.0, n), halfWidth(86.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 85) topIndex = 85; }
        if (count > 87) { float d = segDist(p, j43.xy, j43.zw, halfWidth(86.0, n), halfWidth(87.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 86) topIndex = 86; }
        if (count > 88) { float d = segDist(p, j43.zw, j44.xy, halfWidth(87.0, n), halfWidth(88.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 87) topIndex = 87; }
    }
    if (count > 88 && length(p - j46.xy) < CHUNK_REACH) {
        if (count > 89) { float d = segDist(p, j44.xy, j44.zw, halfWidth(88.0, n), halfWidth(89.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 88) topIndex = 88; }
        if (count > 90) { float d = segDist(p, j44.zw, j45.xy, halfWidth(89.0, n), halfWidth(90.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 89) topIndex = 89; }
        if (count > 91) { float d = segDist(p, j45.xy, j45.zw, halfWidth(90.0, n), halfWidth(91.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 90) topIndex = 90; }
        if (count > 92) { float d = segDist(p, j45.zw, j46.xy, halfWidth(91.0, n), halfWidth(92.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 91) topIndex = 91; }
        if (count > 93) { float d = segDist(p, j46.xy, j46.zw, halfWidth(92.0, n), halfWidth(93.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 92) topIndex = 92; }
        if (count > 94) { float d = segDist(p, j46.zw, j47.xy, halfWidth(93.0, n), halfWidth(94.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 93) topIndex = 93; }
        if (count > 95) { float d = segDist(p, j47.xy, j47.zw, halfWidth(94.0, n), halfWidth(95.0, n)); bodyDist = min(bodyDist, d); if (d < 0.0 && topIndex > 94) topIndex = 94; }
    }

    float tailDist = segDist(p, tail.xy, tail.zw, halfWidth(n - 1.0, n), 0.0);
    bodyDist = min(bodyDist, tailDist);
    if (tailDist < 0.0 && count - 1 < topIndex) topIndex = count - 1;

    float headD = headDist(p);

    if (bodyDist > px && headD > px && params.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float shadow = 0.0;
    if (topIndex < 1000 && topIndex >= 8) {
        float castDist = headD;
        float castWidth = 17.6;
        int limit = topIndex - 10;
    if (limit >= 1 && length(p - j2.xy) < CHUNK_REACH) {
        if (limit >= 1) { float ra = halfWidth(1.0, n); float d = segDist(p, j0.zw, j1.xy, ra, halfWidth(2.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 2) { float ra = halfWidth(2.0, n); float d = segDist(p, j1.xy, j1.zw, ra, halfWidth(3.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 3) { float ra = halfWidth(3.0, n); float d = segDist(p, j1.zw, j2.xy, ra, halfWidth(4.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 4) { float ra = halfWidth(4.0, n); float d = segDist(p, j2.xy, j2.zw, ra, halfWidth(5.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 5) { float ra = halfWidth(5.0, n); float d = segDist(p, j2.zw, j3.xy, ra, halfWidth(6.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 6) { float ra = halfWidth(6.0, n); float d = segDist(p, j3.xy, j3.zw, ra, halfWidth(7.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 7) { float ra = halfWidth(7.0, n); float d = segDist(p, j3.zw, j4.xy, ra, halfWidth(8.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 8 && length(p - j6.xy) < CHUNK_REACH) {
        if (limit >= 8) { float ra = halfWidth(8.0, n); float d = segDist(p, j4.xy, j4.zw, ra, halfWidth(9.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 9) { float ra = halfWidth(9.0, n); float d = segDist(p, j4.zw, j5.xy, ra, halfWidth(10.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 10) { float ra = halfWidth(10.0, n); float d = segDist(p, j5.xy, j5.zw, ra, halfWidth(11.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 11) { float ra = halfWidth(11.0, n); float d = segDist(p, j5.zw, j6.xy, ra, halfWidth(12.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 12) { float ra = halfWidth(12.0, n); float d = segDist(p, j6.xy, j6.zw, ra, halfWidth(13.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 13) { float ra = halfWidth(13.0, n); float d = segDist(p, j6.zw, j7.xy, ra, halfWidth(14.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 14) { float ra = halfWidth(14.0, n); float d = segDist(p, j7.xy, j7.zw, ra, halfWidth(15.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 15) { float ra = halfWidth(15.0, n); float d = segDist(p, j7.zw, j8.xy, ra, halfWidth(16.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 16 && length(p - j10.xy) < CHUNK_REACH) {
        if (limit >= 16) { float ra = halfWidth(16.0, n); float d = segDist(p, j8.xy, j8.zw, ra, halfWidth(17.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 17) { float ra = halfWidth(17.0, n); float d = segDist(p, j8.zw, j9.xy, ra, halfWidth(18.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 18) { float ra = halfWidth(18.0, n); float d = segDist(p, j9.xy, j9.zw, ra, halfWidth(19.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 19) { float ra = halfWidth(19.0, n); float d = segDist(p, j9.zw, j10.xy, ra, halfWidth(20.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 20) { float ra = halfWidth(20.0, n); float d = segDist(p, j10.xy, j10.zw, ra, halfWidth(21.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 21) { float ra = halfWidth(21.0, n); float d = segDist(p, j10.zw, j11.xy, ra, halfWidth(22.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 22) { float ra = halfWidth(22.0, n); float d = segDist(p, j11.xy, j11.zw, ra, halfWidth(23.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 23) { float ra = halfWidth(23.0, n); float d = segDist(p, j11.zw, j12.xy, ra, halfWidth(24.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 24 && length(p - j14.xy) < CHUNK_REACH) {
        if (limit >= 24) { float ra = halfWidth(24.0, n); float d = segDist(p, j12.xy, j12.zw, ra, halfWidth(25.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 25) { float ra = halfWidth(25.0, n); float d = segDist(p, j12.zw, j13.xy, ra, halfWidth(26.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 26) { float ra = halfWidth(26.0, n); float d = segDist(p, j13.xy, j13.zw, ra, halfWidth(27.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 27) { float ra = halfWidth(27.0, n); float d = segDist(p, j13.zw, j14.xy, ra, halfWidth(28.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 28) { float ra = halfWidth(28.0, n); float d = segDist(p, j14.xy, j14.zw, ra, halfWidth(29.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 29) { float ra = halfWidth(29.0, n); float d = segDist(p, j14.zw, j15.xy, ra, halfWidth(30.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 30) { float ra = halfWidth(30.0, n); float d = segDist(p, j15.xy, j15.zw, ra, halfWidth(31.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 31) { float ra = halfWidth(31.0, n); float d = segDist(p, j15.zw, j16.xy, ra, halfWidth(32.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 32 && length(p - j18.xy) < CHUNK_REACH) {
        if (limit >= 32) { float ra = halfWidth(32.0, n); float d = segDist(p, j16.xy, j16.zw, ra, halfWidth(33.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 33) { float ra = halfWidth(33.0, n); float d = segDist(p, j16.zw, j17.xy, ra, halfWidth(34.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 34) { float ra = halfWidth(34.0, n); float d = segDist(p, j17.xy, j17.zw, ra, halfWidth(35.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 35) { float ra = halfWidth(35.0, n); float d = segDist(p, j17.zw, j18.xy, ra, halfWidth(36.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 36) { float ra = halfWidth(36.0, n); float d = segDist(p, j18.xy, j18.zw, ra, halfWidth(37.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 37) { float ra = halfWidth(37.0, n); float d = segDist(p, j18.zw, j19.xy, ra, halfWidth(38.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 38) { float ra = halfWidth(38.0, n); float d = segDist(p, j19.xy, j19.zw, ra, halfWidth(39.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 39) { float ra = halfWidth(39.0, n); float d = segDist(p, j19.zw, j20.xy, ra, halfWidth(40.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 40 && length(p - j22.xy) < CHUNK_REACH) {
        if (limit >= 40) { float ra = halfWidth(40.0, n); float d = segDist(p, j20.xy, j20.zw, ra, halfWidth(41.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 41) { float ra = halfWidth(41.0, n); float d = segDist(p, j20.zw, j21.xy, ra, halfWidth(42.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 42) { float ra = halfWidth(42.0, n); float d = segDist(p, j21.xy, j21.zw, ra, halfWidth(43.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 43) { float ra = halfWidth(43.0, n); float d = segDist(p, j21.zw, j22.xy, ra, halfWidth(44.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 44) { float ra = halfWidth(44.0, n); float d = segDist(p, j22.xy, j22.zw, ra, halfWidth(45.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 45) { float ra = halfWidth(45.0, n); float d = segDist(p, j22.zw, j23.xy, ra, halfWidth(46.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 46) { float ra = halfWidth(46.0, n); float d = segDist(p, j23.xy, j23.zw, ra, halfWidth(47.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 47) { float ra = halfWidth(47.0, n); float d = segDist(p, j23.zw, j24.xy, ra, halfWidth(48.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 48 && length(p - j26.xy) < CHUNK_REACH) {
        if (limit >= 48) { float ra = halfWidth(48.0, n); float d = segDist(p, j24.xy, j24.zw, ra, halfWidth(49.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 49) { float ra = halfWidth(49.0, n); float d = segDist(p, j24.zw, j25.xy, ra, halfWidth(50.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 50) { float ra = halfWidth(50.0, n); float d = segDist(p, j25.xy, j25.zw, ra, halfWidth(51.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 51) { float ra = halfWidth(51.0, n); float d = segDist(p, j25.zw, j26.xy, ra, halfWidth(52.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 52) { float ra = halfWidth(52.0, n); float d = segDist(p, j26.xy, j26.zw, ra, halfWidth(53.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 53) { float ra = halfWidth(53.0, n); float d = segDist(p, j26.zw, j27.xy, ra, halfWidth(54.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 54) { float ra = halfWidth(54.0, n); float d = segDist(p, j27.xy, j27.zw, ra, halfWidth(55.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 55) { float ra = halfWidth(55.0, n); float d = segDist(p, j27.zw, j28.xy, ra, halfWidth(56.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 56 && length(p - j30.xy) < CHUNK_REACH) {
        if (limit >= 56) { float ra = halfWidth(56.0, n); float d = segDist(p, j28.xy, j28.zw, ra, halfWidth(57.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 57) { float ra = halfWidth(57.0, n); float d = segDist(p, j28.zw, j29.xy, ra, halfWidth(58.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 58) { float ra = halfWidth(58.0, n); float d = segDist(p, j29.xy, j29.zw, ra, halfWidth(59.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 59) { float ra = halfWidth(59.0, n); float d = segDist(p, j29.zw, j30.xy, ra, halfWidth(60.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 60) { float ra = halfWidth(60.0, n); float d = segDist(p, j30.xy, j30.zw, ra, halfWidth(61.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 61) { float ra = halfWidth(61.0, n); float d = segDist(p, j30.zw, j31.xy, ra, halfWidth(62.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 62) { float ra = halfWidth(62.0, n); float d = segDist(p, j31.xy, j31.zw, ra, halfWidth(63.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 63) { float ra = halfWidth(63.0, n); float d = segDist(p, j31.zw, j32.xy, ra, halfWidth(64.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 64 && length(p - j34.xy) < CHUNK_REACH) {
        if (limit >= 64) { float ra = halfWidth(64.0, n); float d = segDist(p, j32.xy, j32.zw, ra, halfWidth(65.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 65) { float ra = halfWidth(65.0, n); float d = segDist(p, j32.zw, j33.xy, ra, halfWidth(66.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 66) { float ra = halfWidth(66.0, n); float d = segDist(p, j33.xy, j33.zw, ra, halfWidth(67.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 67) { float ra = halfWidth(67.0, n); float d = segDist(p, j33.zw, j34.xy, ra, halfWidth(68.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 68) { float ra = halfWidth(68.0, n); float d = segDist(p, j34.xy, j34.zw, ra, halfWidth(69.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 69) { float ra = halfWidth(69.0, n); float d = segDist(p, j34.zw, j35.xy, ra, halfWidth(70.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 70) { float ra = halfWidth(70.0, n); float d = segDist(p, j35.xy, j35.zw, ra, halfWidth(71.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 71) { float ra = halfWidth(71.0, n); float d = segDist(p, j35.zw, j36.xy, ra, halfWidth(72.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 72 && length(p - j38.xy) < CHUNK_REACH) {
        if (limit >= 72) { float ra = halfWidth(72.0, n); float d = segDist(p, j36.xy, j36.zw, ra, halfWidth(73.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 73) { float ra = halfWidth(73.0, n); float d = segDist(p, j36.zw, j37.xy, ra, halfWidth(74.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 74) { float ra = halfWidth(74.0, n); float d = segDist(p, j37.xy, j37.zw, ra, halfWidth(75.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 75) { float ra = halfWidth(75.0, n); float d = segDist(p, j37.zw, j38.xy, ra, halfWidth(76.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 76) { float ra = halfWidth(76.0, n); float d = segDist(p, j38.xy, j38.zw, ra, halfWidth(77.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 77) { float ra = halfWidth(77.0, n); float d = segDist(p, j38.zw, j39.xy, ra, halfWidth(78.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 78) { float ra = halfWidth(78.0, n); float d = segDist(p, j39.xy, j39.zw, ra, halfWidth(79.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 79) { float ra = halfWidth(79.0, n); float d = segDist(p, j39.zw, j40.xy, ra, halfWidth(80.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 80 && length(p - j42.xy) < CHUNK_REACH) {
        if (limit >= 80) { float ra = halfWidth(80.0, n); float d = segDist(p, j40.xy, j40.zw, ra, halfWidth(81.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 81) { float ra = halfWidth(81.0, n); float d = segDist(p, j40.zw, j41.xy, ra, halfWidth(82.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 82) { float ra = halfWidth(82.0, n); float d = segDist(p, j41.xy, j41.zw, ra, halfWidth(83.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 83) { float ra = halfWidth(83.0, n); float d = segDist(p, j41.zw, j42.xy, ra, halfWidth(84.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 84) { float ra = halfWidth(84.0, n); float d = segDist(p, j42.xy, j42.zw, ra, halfWidth(85.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 85) { float ra = halfWidth(85.0, n); float d = segDist(p, j42.zw, j43.xy, ra, halfWidth(86.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 86) { float ra = halfWidth(86.0, n); float d = segDist(p, j43.xy, j43.zw, ra, halfWidth(87.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 87) { float ra = halfWidth(87.0, n); float d = segDist(p, j43.zw, j44.xy, ra, halfWidth(88.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
    if (limit >= 88 && length(p - j46.xy) < CHUNK_REACH) {
        if (limit >= 88) { float ra = halfWidth(88.0, n); float d = segDist(p, j44.xy, j44.zw, ra, halfWidth(89.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 89) { float ra = halfWidth(89.0, n); float d = segDist(p, j44.zw, j45.xy, ra, halfWidth(90.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 90) { float ra = halfWidth(90.0, n); float d = segDist(p, j45.xy, j45.zw, ra, halfWidth(91.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 91) { float ra = halfWidth(91.0, n); float d = segDist(p, j45.zw, j46.xy, ra, halfWidth(92.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 92) { float ra = halfWidth(92.0, n); float d = segDist(p, j46.xy, j46.zw, ra, halfWidth(93.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 93) { float ra = halfWidth(93.0, n); float d = segDist(p, j46.zw, j47.xy, ra, halfWidth(94.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
        if (limit >= 94) { float ra = halfWidth(94.0, n); float d = segDist(p, j47.xy, j47.zw, ra, halfWidth(95.0, n)); if (d < castDist) { castDist = d; castWidth = 2.0 * ra; } }
    }
        shadow = params.w * shadowBand(castDist, castWidth);
    }

    float bodyCov = clamp(0.5 - bodyDist / px, 0.0, 1.0);
    vec3 bodyColor = fillColor.rgb * (1.0 - shadow);
    vec4 result = vec4(bodyColor * bodyCov, bodyCov);

    if (params.y > 0.0) {
        float t = min(segDist(p, tongueA.xy, tongueA.zw, 0.7, 0.7),
                  min(segDist(p, tongueA.zw, tongueB.xy, 0.7, 0.7),
                      segDist(p, tongueA.zw, tongueB.zw, 0.7, 0.7)));
        float tongueCov = clamp(0.5 - t / px, 0.0, 1.0) * params.y;
        result = vec4(fillColor.rgb * tongueCov, tongueCov) + result * (1.0 - tongueCov);
    }

    float headCov = clamp(0.5 - headD / px, 0.0, 1.0);
    result = vec4(fillColor.rgb * headCov, headCov) + result * (1.0 - headCov);

    fragColor = result * fillColor.a * qt_Opacity;
}
