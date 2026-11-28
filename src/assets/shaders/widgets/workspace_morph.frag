#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float shapeFrom;
    float shapeTo;
    float shapeBlend;
    float angleRad;
    float hoverAmt;
    float activeAmt;
    float glassMode;
    vec4 fillColor;
    vec4 rimColor;
};

const float PI = 3.141592653589793;

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float sdRegularPoly(vec2 p, float r, float n, float cornerR) {
    float scale = (n < 3.5) ? 1.18 : ((n < 5.5) ? 1.04 : 1.0);
    float innerR = max(0.5, r * scale - cornerR);
    float an = PI / n;
    float en = cos(an);
    float len = length(p);
    if (len < 0.0001) {
        return -innerR * en - cornerR;
    }
    float bn = mod(atan(p.x, p.y) + 2.0 * PI + an, 2.0 * an) - an;
    vec2 q = len * vec2(cos(bn), abs(sin(bn)));
    q -= innerR * vec2(en, sin(an));
    q.y += clamp(-q.y, 0.0, innerR * sin(an));
    return length(q) * sign(q.x) - cornerR;
}

mat2 rot2(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

float sdClover(vec2 p, float base, float n, float ringR, float petalR, float coreR, float k) {
    float r = length(p);
    if (r < 0.0001) {
        return -coreR;
    }
    float sector = 2.0 * PI / n;
    float a = atan(p.y, p.x);
    float fa = mod(a + PI + sector * 0.5, sector) - sector * 0.5;
    vec2 lp = r * vec2(cos(fa), sin(fa));
    float d0 = length(lp - vec2(ringR, 0.0)) - petalR;
    vec2 neighbor = ringR * vec2(cos(sector), sin(sector));
    float d1 = length(vec2(lp.x, abs(lp.y)) - neighbor) - petalR;
    float dPetals = smin(d0, d1, k);
    float dCore = r - coreR;
    return smin(dPetals, dCore, k * 0.5);
}

float evalShape(int id, vec2 rp, float base, float hoverBoost) {
    if (id == 0) {
        return length(rp) - base * 0.34 * hoverBoost;
    }
    if (id == 1) {
        float b = base * 0.345 * hoverBoost;
        return sdRoundedBox(rp, vec2(b), b * 0.62);
    }
    if (id == 2) {
        vec2 b = vec2(base * 0.39, base * 0.305) * hoverBoost;
        return sdRoundedBox(rp, b, b.y);
    }
    if (id == 3) {
        return sdRegularPoly(rp, base * 0.355 * hoverBoost, 6.0, base * 0.135);
    }
    if (id == 4) {
        float b = base * 0.365 * hoverBoost;
        return sdRoundedBox(rp, vec2(b), b * 0.25);
    }
    if (id == 5) {
        float b = base * 0.335 * hoverBoost;
        return sdRoundedBox(rot2(0.78539816) * rp, vec2(b), b * 0.26);
    }
    if (id == 6) {
        vec2 fp = vec2(rp.x, -rp.y);
        return sdRegularPoly(fp, base * 0.38 * hoverBoost, 5.0, base * 0.075);
    }
    if (id == 7) {
        float r = base * 0.39 * hoverBoost;
        float cr = base * 0.085;
        vec2 fp = vec2(rp.x, -rp.y - (r * 1.18 - cr) * 0.25);
        return sdRegularPoly(fp, r, 3.0, cr);
    }
    if (id == 8) {
        return sdClover(rp, base, 4.0, base * 0.235, base * 0.22, base * 0.225, base * 0.065);
    }
    if (id == 9) {
        return sdClover(rp, base, 5.0, base * 0.26, base * 0.195, base * 0.245, base * 0.055);
    }
    if (id == 10) {
        return sdClover(rp, base, 6.0, base * 0.28, base * 0.175, base * 0.265, base * 0.048);
    }
    return sdClover(rp, base, 7.0, base * 0.295, base * 0.16, base * 0.28, base * 0.042);
}

void main() {
    float base = min(itemSize.x, itemSize.y) / 1.24;
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    vec2 rp = rot2(-angleRad) * p;

    float hoverBoost = 1.0 + 0.045 * hoverAmt;

    int idA = int(shapeFrom + 0.5);
    int idB = int(shapeTo + 0.5);
    float dA = evalShape(idA, rp, base, hoverBoost);
    float dB = evalShape(idB, rp, base, hoverBoost);

    float t = clamp(shapeBlend, -0.1, 1.12);
    float tc = clamp(t, 0.0, 1.0);
    float st = smoothstep(0.0, 1.0, tc) + (t - tc);
    float d = mix(dA, dB, st);

    float transit = sin(tc * PI);
    float theta = atan(rp.y, rp.x);
    d -= base * 0.014 * transit * cos(4.0 * theta + angleRad * 2.0);

    float edgeAlpha = clamp(0.5 - d, 0.0, 1.0);

    vec3 rgb = fillColor.rgb;
    float a = fillColor.a;

    if (glassMode > 0.5) {
        vec2 dir = length(p) > 0.001 ? normalize(p) : vec2(0.0, -1.0);
        float topLight = clamp(dot(dir, vec2(-0.55, -0.835)) * 0.5 + 0.5, 0.0, 1.0);
        float innerRim = smoothstep(-2.0, -0.25, d) * edgeAlpha;
        a = mix(a * 0.54, a * 0.70, activeAmt);
        rgb = mix(rgb, rimColor.rgb, (0.12 + 0.18 * topLight) * innerRim + 0.06 * topLight * activeAmt);
        a = clamp(a + 0.22 * innerRim * (0.45 + 0.55 * topLight), 0.0, 1.0);
    }

    float outA = edgeAlpha * a * qt_Opacity;
    fragColor = vec4(rgb * outA, outA);
}
