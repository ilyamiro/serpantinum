import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

WallpaperTabState {
    id: wallpaperTabRoot
    deferredStages: 2

    property alias wpDirDropdown: wallpaperDirRow.wpDirDropdown

    onVisibleChanged: {
        if (!visible && wpDirDropdown.isOpen) wpDirDropdown.closePopup();
    }

    GuideScrollView {
        rootObj: wallpaperTabRoot.rootObj

        WallpaperPreview { tab: wallpaperTabRoot }

        WallpaperDirRow { id: wallpaperDirRow; tab: wallpaperTabRoot }

        Loader {
            Layout.fillWidth: true
            active: wallpaperTabRoot.deferredStage >= 1
            sourceComponent: TransitionModeRow { tab: wallpaperTabRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: wallpaperTabRoot.deferredStage >= 2
            sourceComponent: TransitionEffectsSection { tab: wallpaperTabRoot }
        }
    }
}
