import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/buttons"
import "../singletons"

Item {
    id: root

    property string searchFilter: ""
    property string activeCategory: "All"
    property string activeSource: "merged" // "merged" | "native" | "hyprland"
    property var allKeybinds: []
    property string copiedAction: ""

    readonly property var fallbackNativeBinds: [
        { keys: "SUPER + ?", action: "serpantinum msg toggle keybinds", description: "Keybindings Cheatsheet", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + D", action: "serpantinum msg toggle launcher", description: "Application Launcher", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + C", action: "serpantinum msg toggle clipboard", description: "Clipboard Manager", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + H", action: "serpantinum msg toggle settings", description: "Serpantinum Settings & Guide", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + W", action: "serpantinum msg toggle wallpaper", description: "Wallpaper Picker", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + S", action: "serpantinum msg toggle calendar", description: "Calendar & Clock", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + M", action: "serpantinum msg toggle music", description: "Media Player", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + N", action: "serpantinum msg toggle network", description: "Network Settings", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + V", action: "serpantinum msg toggle volume", description: "Volume & Audio Popup", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + B", action: "serpantinum msg toggle system", description: "System Panel & Power Menu", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + A", action: "serpantinum msg bar autohide", description: "Toggle Bar Autohide", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + R", action: "serpantinum reload", description: "Reload Shell", category: "Serpantinum", source: "Serpantinum" },
        { keys: "SUPER + RETURN", action: "kitty", description: "Open Terminal", category: "Apps", source: "Serpantinum" },
        { keys: "SUPER + E", action: "ski", description: "Open File Manager", category: "Apps", source: "Serpantinum" },
        { keys: "SUPER + F", action: "firefox", description: "Open Web Browser", category: "Apps", source: "Serpantinum" },
        { keys: "SUPER + L", action: "serpantinum lock", description: "Lock Screen", category: "System", source: "Serpantinum" },
        { keys: "XF86PowerOff", action: "serpantinum lock", description: "Lock Screen (Power Button)", category: "System", source: "Serpantinum" },
        { keys: "Print", action: "serpantinum screenshot", description: "Area Screenshot", category: "Screenshots", source: "Serpantinum" },
        { keys: "SHIFT + Print", action: "serpantinum screenshot --edit", description: "Area Screenshot & Edit", category: "Screenshots", source: "Serpantinum" },
        { keys: "SUPER + Print", action: "serpantinum screenshot --full", description: "Fullscreen Screenshot", category: "Screenshots", source: "Serpantinum" },
        { keys: "SUPER + SHIFT + Print", action: "serpantinum screenshot --full --edit", description: "Fullscreen Screenshot & Edit", category: "Screenshots", source: "Serpantinum" },
        { keys: "SUPER + SPACE", action: "playerctl play-pause", description: "Play / Pause Media", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioPlay", action: "playerctl play-pause", description: "Play / Pause Audio", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioNext", action: "playerctl next", description: "Next Track", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioPrev", action: "playerctl previous", description: "Previous Track", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioRaiseVolume", action: "serpantinum volume raise", description: "Volume Up", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioLowerVolume", action: "serpantinum volume lower", description: "Volume Down", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioMute", action: "serpantinum volume mute-toggle", description: "Mute / Unmute Audio", category: "Media", source: "Serpantinum" },
        { keys: "XF86AudioMicMute", action: "serpantinum volume mic-toggle", description: "Mute / Unmute Microphone", category: "Media", source: "Serpantinum" },
        { keys: "XF86MonBrightnessUp", action: "serpantinum brightness raise", description: "Screen Brightness Up", category: "Media", source: "Serpantinum" },
        { keys: "XF86MonBrightnessDown", action: "serpantinum brightness lower", description: "Screen Brightness Down", category: "Media", source: "Serpantinum" },
        { keys: "SUPER + Q", action: "closewindow", description: "Close Active Window", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + SHIFT + F", action: "togglefloating", description: "Toggle Window Floating", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + ALT + F", action: "fullscreen", description: "Toggle Fullscreen / Maximize", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + Arrows", action: "movefocus", description: "Focus Window (Left / Right / Up / Down)", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + CTRL + Arrows", action: "movewindow", description: "Move Window (Left / Right / Up / Down)", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + SHIFT + Arrows", action: "resizeactive", description: "Resize Window (+/- 50px)", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + Mouse LMB", action: "movewindow (drag)", description: "Drag Window with Mouse", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + Mouse RMB", action: "resizewindow (drag)", description: "Resize Window with Mouse", category: "Windows", source: "Serpantinum" },
        { keys: "SUPER + 1..0", action: "serpantinum msg workspace <n>", description: "Switch to Workspace 1..10", category: "Workspaces", source: "Serpantinum" },
        { keys: "SUPER + SHIFT + 1..0", action: "serpantinum msg workspace <n> move", description: "Move Window to Workspace 1..10", category: "Workspaces", source: "Serpantinum" }
    ]

    function getScriptPath() {
        if (typeof Caching !== "undefined" && Caching.serpantinumDir) {
            return Caching.serpantinumDir + "/scripts/keybinds.py";
        }
        return "scripts/keybinds.py";
    }

    function reloadKeybinds() {
        keybindsProc.running = false;
        let comp = (typeof Compositor !== "undefined" && Compositor.name) ? Compositor.name : "";
        let cmd = ["python3", root.getScriptPath(), "--mode", root.activeSource];
        if (comp && comp !== "unknown") {
            cmd.push("--compositor", comp);
        }
        keybindsProc.command = cmd;
        keybindsProc.running = true;
    }

    function filterModel() {
        filteredModel.clear();
        let list = (root.allKeybinds && root.allKeybinds.length > 0) ? root.allKeybinds : root.fallbackNativeBinds;
        let query = root.searchFilter.trim().toLowerCase();
        let cat = root.activeCategory;

        for (let i = 0; i < list.length; i++) {
            let item = list[i];
            let itemCat = item.category || "Other";
            if (cat !== "All" && itemCat !== cat) {
                continue;
            }
            if (query !== "") {
                let matchKey = (item.keys || "").toLowerCase().indexOf(query) !== -1;
                let matchDesc = (item.description || "").toLowerCase().indexOf(query) !== -1;
                let matchAct = (item.action || "").toLowerCase().indexOf(query) !== -1;
                let matchCategory = itemCat.toLowerCase().indexOf(query) !== -1;
                if (!matchKey && !matchDesc && !matchAct && !matchCategory) {
                    continue;
                }
            }
            filteredModel.append({
                keys: item.keys || "",
                action: item.action || "",
                description: item.description || "",
                category: itemCat,
                source: item.source || "Serpantinum"
            });
        }
    }

    onActiveSourceChanged: reloadKeybinds()
    onSearchFilterChanged: filterModel()
    onActiveCategoryChanged: filterModel()

    Component.onCompleted: {
        root.allKeybinds = root.fallbackNativeBinds;
        root.filterModel();
        root.reloadKeybinds();
    }

    Process {
        id: keybindsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim().length > 0) {
                    try {
                        let parsed = JSON.parse(this.text);
                        if (parsed && parsed.length > 0) {
                            root.allKeybinds = parsed;
                            root.filterModel();
                        }
                    } catch(e) {}
                }
            }
        }
    }

    ListModel {
        id: filteredModel
    }

    Timer {
        id: copyTimer
        interval: 2000
        repeat: false
        onTriggered: root.copiedAction = ""
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (typeof switchWidget === "function") {
                switchWidget("hidden", "");
            }
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        border.color: Qt.alpha(ThemeBackend.surface1, 0.7)
        border.width: 1

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            topLeftRadius: parent.radius
            topRightRadius: parent.radius
            bottomLeftRadius: parent.radius
            bottomRightRadius: parent.radius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: Qt.alpha(ThemeBackend.primary, 0.15)
                    border.color: Qt.alpha(ThemeBackend.primary, 0.3)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 18
                        color: ThemeBackend.primary
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: (typeof I18n !== "undefined" && typeof I18n.t === "function") 
                              ? I18n.t("widgets.keybinds.title", "Keybindings Cheatsheet") 
                              : "Keybindings Cheatsheet"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                        color: ThemeBackend.text
                    }

                    Text {
                        text: filteredModel.count + " " + ((filteredModel.count === 1) ? "shortcut" : "shortcuts")
                              + (root.copiedAction !== "" ? " • " + root.copiedAction : "")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 11
                        color: root.copiedAction !== "" ? ThemeBackend.green : ThemeBackend.subtext0
                    }
                }

                // Source selector: Merged | Serpantinum | Hyprland
                Row {
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "merged", label: "Merged" },
                            { id: "native", label: "Serpantinum" },
                            { id: "hyprland", label: "Hyprland" }
                        ]

                        Rectangle {
                            width: sourceLabel.implicitWidth + 18
                            height: 28
                            radius: 6
                            color: root.activeSource === modelData.id 
                                   ? ThemeBackend.primary 
                                   : Qt.alpha(ThemeBackend.surface0, 0.8)
                            border.color: root.activeSource === modelData.id 
                                          ? ThemeBackend.primary 
                                          : Qt.alpha(ThemeBackend.surface1, 0.6)
                            border.width: 1

                            Text {
                                id: sourceLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                font.bold: root.activeSource === modelData.id
                                color: root.activeSource === modelData.id ? ThemeBackend.base : ThemeBackend.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeSource = modelData.id
                            }
                        }
                    }
                }

                CloseButton {
                    onClicked: {
                        if (typeof switchWidget === "function") {
                            switchWidget("hidden", "");
                        }
                    }
                }
            }

            // Search Bar & Clear
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: Qt.alpha(ThemeBackend.surface0, 0.7)
                border.color: searchTextInput.activeFocus ? ThemeBackend.primary : Qt.alpha(ThemeBackend.surface1, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "󰍉"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 14
                        color: ThemeBackend.subtext0
                    }

                    TextInput {
                        id: searchTextInput
                        Layout.fillWidth: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        color: ThemeBackend.text
                        clip: true
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        Text {
                            anchors.fill: parent
                            visible: !searchTextInput.text && !searchTextInput.activeFocus
                            text: (typeof I18n !== "undefined" && typeof I18n.t === "function")
                                  ? I18n.t("widgets.keybinds.search", "Search shortcut or action...")
                                  : "Search shortcut or action..."
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 13
                            color: ThemeBackend.subtext0
                            verticalAlignment: Text.AlignVCenter
                        }

                        onTextChanged: root.searchFilter = text
                    }

                    Text {
                        visible: searchTextInput.text.length > 0
                        text: "󰅖"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        color: ThemeBackend.subtext0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchTextInput.text = "";
                                root.searchFilter = "";
                            }
                        }
                    }
                }
            }

            // Category Filter Pills
            Flickable {
                Layout.fillWidth: true
                height: 30
                contentWidth: categoryRow.width
                flickableDirection: Flickable.HorizontalFlick
                clip: true

                Row {
                    id: categoryRow
                    spacing: 6

                    Repeater {
                        model: ["All", "Serpantinum", "Apps", "Windows", "Workspaces", "Media", "Screenshots", "System", "Other"]

                        Rectangle {
                            width: catText.implicitWidth + 16
                            height: 26
                            radius: 6
                            color: root.activeCategory === modelData 
                                   ? Qt.alpha(ThemeBackend.primary, 0.25)
                                   : Qt.alpha(ThemeBackend.surface0, 0.6)
                            border.color: root.activeCategory === modelData 
                                          ? ThemeBackend.primary 
                                          : Qt.alpha(ThemeBackend.surface1, 0.4)
                            border.width: 1

                            Text {
                                id: catText
                                anchors.centerIn: parent
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                font.bold: root.activeCategory === modelData
                                color: root.activeCategory === modelData ? ThemeBackend.primary : ThemeBackend.subtext0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeCategory = modelData
                            }
                        }
                    }
                }
            }

            // Keybindings List
            ListView {
                id: keybindsListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: filteredModel
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: keybindsListView.moving || keybindsListView.contentHeight > keybindsListView.height
                    width: 6
                }

                delegate: Rectangle {
                    id: itemDelegate
                    width: keybindsListView.width
                    height: 52
                    radius: 8
                    color: itemMouse.containsMouse 
                           ? Qt.alpha(ThemeBackend.surface1, 0.45) 
                           : Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.color: itemMouse.containsMouse 
                                  ? Qt.alpha(ThemeBackend.primary, 0.4) 
                                  : Qt.alpha(ThemeBackend.surface1, 0.25)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Physical Keycaps
                        Row {
                            spacing: 4
                            Layout.preferredWidth: 230

                            Repeater {
                                model: {
                                    let raw = (model.keys || "").split("+");
                                    let res = [];
                                    for (let j = 0; j < raw.length; j++) {
                                        let trimmed = raw[j].trim();
                                        if (trimmed.length > 0) res.push(trimmed);
                                    }
                                    return res;
                                }

                                Row {
                                    spacing: 4
                                    Rectangle {
                                        height: 24
                                        width: Math.max(26, keyCapText.implicitWidth + 12)
                                        radius: 5
                                        color: Qt.alpha(ThemeBackend.surface1, 0.9)
                                        border.color: Qt.alpha(ThemeBackend.surface2, 0.8)
                                        border.width: 1

                                        Text {
                                            id: keyCapText
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: ThemeBackend.text
                                        }
                                    }

                                    Text {
                                        visible: index < (model.keys.split("+").length - 1)
                                        text: "+"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeBackend.subtext0
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Description and Action
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: model.description || model.action
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: model.action
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 10
                                color: ThemeBackend.subtext0
                                elide: Text.ElideRight
                            }
                        }

                        // Category Pill
                        Rectangle {
                            height: 20
                            width: catBadgeText.implicitWidth + 10
                            radius: 4
                            color: model.source === "Serpantinum" 
                                   ? Qt.alpha(ThemeBackend.blue, 0.15) 
                                   : Qt.alpha(ThemeBackend.mauve, 0.15)

                            Text {
                                id: catBadgeText
                                anchors.centerIn: parent
                                text: model.category
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: model.source === "Serpantinum" ? ThemeBackend.blue : ThemeBackend.mauve
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (model.action) {
                                Quickshell.execDetached(["wl-copy", model.action]);
                                root.copiedAction = "Copied \"" + model.action + "\" to clipboard";
                                copyTimer.restart();
                            }
                        }
                    }
                }
            }

            // Empty state when search produces 0 results
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: filteredModel.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰍉"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 32
                        color: ThemeBackend.subtext0
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (typeof I18n !== "undefined" && typeof I18n.t === "function")
                              ? I18n.t("widgets.keybinds.no_results", "No matching shortcuts found")
                              : "No matching shortcuts found"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        color: ThemeBackend.subtext0
                    }
                }
            }
        }
    }
}
