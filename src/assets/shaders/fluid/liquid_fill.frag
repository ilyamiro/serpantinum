#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    float fillLevel;
    float waveAmp;
    vec2 itemSize;
    float phase;
    float bodyAlpha;
    vec4 color1;
    vec4 color2;
};

const vec2 lightDir = vec2(-0.55, -0.83);

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float surfaceX(float y) {
    float t = clamp(y / max(itemSize.y, 1.0), 0.0, 1.0);
    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;
    float offset = waveAmp * (b2 * sin(phase) - b1 * cos(phase));
    return itemSize.x * fillLevel + offset;
}

void main() {
    if (fillLevel <= 0.0001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    vec2 pc = p - halfSize;
    float clampedR = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float dBox = sdRoundedBox(pc, halfSize, clampedR);
    float boxAlpha = clamp(0.5 - dBox, 0.0, 1.0);
    if (boxAlpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float sd = 1000.0;
    float slope = 0.0;
    if (fillLevel < 0.999) {
        float sx = surfaceX(p.y);
        slope = (surfaceX(p.y + 1.0) - surfaceX(p.y - 1.0)) * 0.5;
        sd = (sx - p.x) * inversesqrt(1.0 + slope * slope);
    }
    float fluidAlpha = clamp(0.5 + sd, 0.0, 1.0);
    if (fluidAlpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float depth = max(sd, 0.0);
    vec2 sg = normalize(vec2(1.0, -slope));
    float sFacing = dot(sg, normalize(lightDir));
    float sSpec = 0.45 + 0.55 * pow(max(-sFacing, 0.0), 1.4);

    float hair = exp(-depth / 1.1);
    float wide = exp(-depth / 6.5);
    float lens = exp(-pow((depth - 8.0) / 5.5, 2.0));
    float trough = exp(-pow((depth - 17.0) / 8.0, 2.0));
    float meniscus = hair * (0.35 + 0.65 * sSpec) * 0.95 + wide * 0.22 * sSpec + lens * 0.16;

    float tb = max(-dBox, 0.0);
    vec2 e = vec2(0.75, 0.0);
    vec2 bg = vec2(
        sdRoundedBox(pc + e.xy, halfSize, clampedR) - sdRoundedBox(pc - e.xy, halfSize, clampedR),
        sdRoundedBox(pc + e.yx, halfSize, clampedR) - sdRoundedBox(pc - e.yx, halfSize, clampedR));
    vec2 g = length(bg) > 0.0001 ? normalize(bg) : vec2(0.0, -1.0);
    float facing = dot(g, normalize(lightDir));
    float spec = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);
    float boxRim = (exp(-tb / 1.1) * (0.18 + 0.7 * spec) + exp(-tb / 5.0) * 0.08) * smoothstep(0.0, 6.0, depth + 1.0);

    float ty = clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0);
    float sheen = (1.0 - ty) * 0.07 + exp(-pow((ty - 0.18) / 0.10, 2.0)) * 0.05;

    float tx = clamp(p.x / max(itemSize.x, 1.0), 0.0, 1.0);
    vec3 base = mix(color1.rgb, color2.rgb, tx);
    float bodyA = (bodyAlpha > 0.0 ? bodyAlpha : 0.5) * mix(1.1, 0.8, ty);
    float inner = 0.09 * smoothstep(0.0, 22.0, depth) * (1.0 - ty);
    float pool = smoothstep(14.0, 60.0, depth);
    float caustic = 0.035 * (0.5 + 0.5 * sin(p.x * 0.11 + phase * 1.3 + p.y * 0.05)) * pool * (1.0 - 0.5 * ty);

    float light = meniscus + boxRim + sheen + inner + caustic;
    vec3 rgb = base * bodyA * (1.0 - 0.18 * trough) + vec3(light);
    float a = clamp(bodyA * (1.0 - 0.25 * pool) + light * 0.85, 0.0, 1.0);

    float k = boxAlpha * fluidAlpha * qt_Opacity;
    fragColor = vec4(rgb * k, a * k);
}
