.pragma library

var ALL_ID = "All";
var FAVORITES_ID = "Favorites";

// Freedesktop main categories, in the default display order.
var CATEGORIES = [
    { id: "AudioVideo", icon: "󰎆", label: "Multimedia" },
    { id: "Development", icon: "󰅩", label: "Development" },
    { id: "Education", icon: "󰑴", label: "Education" },
    { id: "Game", icon: "󰊴", label: "Games" },
    { id: "Graphics", icon: "󰏘", label: "Graphics" },
    { id: "Network", icon: "󰖟", label: "Internet" },
    { id: "Office", icon: "󰈙", label: "Office" },
    { id: "Science", icon: "󰂓", label: "Science" },
    { id: "Settings", icon: "󰒓", label: "Settings" },
    { id: "System", icon: "󰍹", label: "System" },
    { id: "Utility", icon: "󰓅", label: "Utilities" },
    { id: "Other", icon: "󰋖", label: "Other" }
];

var ALL = { id: ALL_ID, icon: "󰀻", label: "All apps" };
var FAVORITES = { id: FAVORITES_ID, icon: "󰓎", label: "Favorites" };

function get(id) {
    if (id === ALL_ID) return ALL;
    if (id === FAVORITES_ID) return FAVORITES;
    for (var i = 0; i < CATEGORIES.length; i++) {
        if (CATEGORIES[i].id === id) return CATEGORIES[i];
    }
    return null;
}

function allIds() {
    var ids = [ALL_ID, FAVORITES_ID];
    for (var i = 0; i < CATEGORIES.length; i++) {
        ids.push(CATEGORIES[i].id);
    }
    return ids;
}

function defaultOrder() {
    return allIds();
}

// Keeps a user-defined order, drops unknown entries and appends categories
// added by newer versions so they never silently disappear.
function normalizeOrder(order) {
    var valid = allIds();
    var result = [];
    if (Array.isArray(order)) {
        for (var i = 0; i < order.length; i++) {
            if (valid.indexOf(order[i]) !== -1 && result.indexOf(order[i]) === -1) {
                result.push(order[i]);
            }
        }
    }
    for (var j = 0; j < valid.length; j++) {
        if (result.indexOf(valid[j]) === -1) {
            result.push(valid[j]);
        }
    }
    return result;
}

function normalizeHidden(hidden) {
    var valid = allIds();
    var result = [];
    if (Array.isArray(hidden)) {
        for (var i = 0; i < hidden.length; i++) {
            if (hidden[i] !== ALL_ID && valid.indexOf(hidden[i]) !== -1 && result.indexOf(hidden[i]) === -1) {
                result.push(hidden[i]);
            }
        }
    }
    return result;
}

// Maps DesktopEntry.categories to the categories shown in the launcher.
// Apps without a known main category (or with no Categories at all) land in Other.
function categoriesFor(appCategories) {
    var found = [];
    if (appCategories) {
        if (Array.isArray(appCategories)) {
            found = appCategories;
        } else if (typeof appCategories.length === "number") {
            for (var i = 0; i < appCategories.length; i++) found.push(appCategories[i]);
        }
    }

    var result = [];
    for (var j = 0; j < CATEGORIES.length; j++) {
        if (CATEGORIES[j].id === "Other") continue;
        if (found.indexOf(CATEGORIES[j].id) !== -1) {
            result.push(CATEGORIES[j].id);
        }
    }
    if (result.length === 0) result.push("Other");
    return result;
}
