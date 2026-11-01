.pragma library

var DEFAULT_ID = "google";

var PROVIDERS = [
    { id: "google", name: "Google", url: "https://www.google.com/search?q=" },
    { id: "duckduckgo", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
    { id: "bing", name: "Bing", url: "https://www.bing.com/search?q=" },
    { id: "brave", name: "Brave Search", url: "https://search.brave.com/search?q=" },
    { id: "startpage", name: "Startpage", url: "https://www.startpage.com/do/search?q=" },
    { id: "ecosia", name: "Ecosia", url: "https://www.ecosia.org/search?q=" },
    { id: "qwant", name: "Qwant", url: "https://www.qwant.com/?q=" },
    { id: "yandex", name: "Yandex", url: "https://yandex.com/search/?text=" },
    { id: "kagi", name: "Kagi", url: "https://kagi.com/search?q=" },
    { id: "wikipedia", name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=" },
    { id: "youtube", name: "YouTube", url: "https://www.youtube.com/results?search_query=" }
];

function find(id) {
    for (var i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].id === id) return PROVIDERS[i];
    }
    return PROVIDERS[0];
}

function indexOf(id) {
    for (var i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].id === id) return i;
    }
    return 0;
}

function names() {
    return PROVIDERS.map(function (p) { return p.name; });
}

function urlFor(id, query) {
    return find(id).url + encodeURIComponent(query);
}
