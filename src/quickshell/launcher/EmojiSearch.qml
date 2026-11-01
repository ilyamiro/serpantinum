import QtQuick
import "./EmojiData.js" as EmojiData

QtObject {
    function search(query, limit) {
        return EmojiData.search(query, limit);
    }
}
