.pragma library

var cachedOutputs = [];
var cachedInputs = [];
var cachedApps = [];

function arraysEqual(a, b) {
    if (!a || !b) return false;
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
        if (a[i] !== b[i]) return false;
    }
    return true;
}

function updateOutputs(arr) {
    if (arraysEqual(arr, cachedOutputs)) return cachedOutputs;
    cachedOutputs = arr;
    return arr;
}

function updateInputs(arr) {
    if (arraysEqual(arr, cachedInputs)) return cachedInputs;
    cachedInputs = arr;
    return arr;
}

function updateApps(arr) {
    if (arraysEqual(arr, cachedApps)) return cachedApps;
    cachedApps = arr;
    return arr;
}
