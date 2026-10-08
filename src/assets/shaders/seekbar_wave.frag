// Wavy progress fill for reusables/media/WavySeekBar.qml.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o seekbar_wave.frag.qsb seekbar_wave.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 waveColor;
    vec2 itemSize;
    float pad;
    float cy;
    float endX;
    float strokeWidth;
    float amplitude;
    float trackAlpha;
    float startTaper;
    float phase;
    // Per wave layer: x = amp, y = alpha, z = end taper length, w = wavelength
    vec4 shape0;
    vec4 shape1;
    // Per wave layer: x = phase multiplier, y = offset, z = swell offset
    vec4 motion0;
    vec4 motion1;
};

const float TWO_PI = 6.2831853;

float easeQuintic(float t) {
    t = clamp(t, 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Premultiplied source-over.
vec4 over(vec4 dst, vec4 src) {
    return src + dst * (1.0 - src.a);
}

// Coverage of a horizontal line from x0 to x1 at cy with round caps.
float capsule(vec2 p, float x0, float x1) {
    float d = length(p - vec2(clamp(p.x, x0, x1), cy)) - strokeWidth * 0.5;
    return clamp(0.5 - d, 0.0, 1.0);
}

vec4 waveLayer(vec2 p, vec4 shape, vec4 motion) {
    float a = amplitude * shape.x;
    if (a < 0.3 || p.x < pad || p.x > endX) return vec4(0.0);

    float k = TWO_PI / shape.w;
    float n = sin(k * p.x - phase * motion.x + motion.y);
    float swell = sin(k / 6.0 * p.x - phase * motion.x * 0.5 + motion.z);
    float h = 0.5 * (1.0 + n) * (0.8 + 0.2 * swell);
    float env = easeQuintic((p.x - pad) / startTaper) * easeQuintic((endX - p.x) / shape.z);

    float top = cy - strokeWidth * 0.5;
    float yWave = top - h * a * env;
    float coverage = clamp(p.y - yWave + 0.5, 0.0, 1.0) * clamp(cy - p.y + 0.5, 0.0, 1.0);

    // Vertical gradient from a0 at the crest height to a1 at the line.
    float a1 = shape.y;
    float a0 = a1 >= 1.0 ? 1.0 : a1 * 0.55;
    float alpha = mix(a0, a1, clamp((p.y - (top - a)) / a, 0.0, 1.0));
    return vec4(waveColor.rgb, 1.0) * alpha * coverage;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec4 rgb = vec4(waveColor.rgb, 1.0);

    vec4 c = rgb * trackAlpha * capsule(p, endX, itemSize.x - pad);
    c = over(c, waveLayer(p, shape0, motion0));
    c = over(c, waveLayer(p, shape1, motion1));
    c = over(c, rgb * capsule(p, pad, endX));

    fragColor = c * qt_Opacity;
}
