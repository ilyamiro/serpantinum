.pragma library

var KINDS = {
    low: { level: 0.2, a: "#7a3a12", b: "#ffa23a", glow: "#ff8226", fluid: "#ffa23a", strength: 0.26, pulse: true, bolt: false },
    critical: { level: 0.06, a: "#6e1a22", b: "#ff5a5a", glow: "#ff3d3d", fluid: "#ff4d4d", strength: 0.32, pulse: true, bolt: false },
    full: { level: 1.0, a: "#17613f", b: "#7fe3a6", glow: "#4ade80", fluid: "#4ade80", strength: 0.24, pulse: false, bolt: true }
};

function resolve(kind) {
    return KINDS[kind] || KINDS.low;
}
