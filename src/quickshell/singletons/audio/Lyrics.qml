pragma Singleton
import QtQuick
import "../../"

// Shared lyrics for the globally selected player. Popups selecting a different
// player use their own provider, without changing this singleton's source.
LyricsProvider {}
