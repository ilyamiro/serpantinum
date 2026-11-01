.pragma library

function nestLevel(item, stopAt, countBackdrops) {
    let count = 0;
    let a = item.parent;
    let depth = 0;
    while (a && a !== stopAt && depth < 48) {
        const kids = a.children;
        if (kids) {
            for (let i = 0; i < kids.length; i++) {
                const k = kids[i];
                if (k && k !== item && ((countBackdrops && k.isGlassBackdrop === true && k.standalone !== true) || (k.isGlassFill === true && k.allowed === true))) {
                    count++;
                    break;
                }
            }
        }
        a = a.parent;
        depth++;
    }
    return count;
}
