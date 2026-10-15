.pragma library

var keyToId = {};
var entryById = {};
var resolveCache = {};
var dirty = true;

function markDirty() {
    dirty = true;
    resolveCache = {};
}

function isDirty() {
    return dirty;
}

function getCached(key) {
    return resolveCache[key];
}

function setCached(key, val) {
    resolveCache[key] = val;
    return val;
}

function setTables(byId, map) {
    entryById = byId;
    keyToId = map;
    resolveCache = {};
    dirty = false;
}

function getEntry(cid) {
    return entryById[cid] || null;
}

function lookupKey(key, cidKey, tail) {
    var id = keyToId[key] || keyToId[cidKey];
    if (id === undefined && tail && tail !== cidKey) {
        id = keyToId[tail];
    }
    return id;
}
