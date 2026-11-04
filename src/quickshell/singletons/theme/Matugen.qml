pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property bool isRunning: matugenProcess.running
    property string lastWallpaper: ""
    property string matugenBaseDir: {
        let dir = "";
        if (typeof Caching !== "undefined" && Caching.qsDir) {
            dir = Caching.serpantinumDir + "/assets/matugen";
        } else if (typeof Caching !== "undefined" && Caching.serpantinumDir) {
            dir = Caching.serpantinumDir + "/src/assets/matugen";
        } else {
            dir = Quickshell.env("HOME") + "/.local/share/serpantinum/src/assets/matugen";
        }
        return dir;
    }
    property string configPath: matugenBaseDir + "/config.toml"
    readonly property string stateDir: (typeof Caching !== "undefined" && Caching.stateDir) ? Caching.stateDir : (Quickshell.env("HOME") + "/.local/state/serpantinum")
    readonly property string palettePath: stateDir + "/matugen/palette.json"

    property var _pendingRequest: null
    property string _currentReqType: ""
    property string _currentImagePath: ""
    property string _currentMode: ""
    property string _currentSchemeType: ""
    property string _currentStaticJson: ""

    property string _lastGeneratedReqType: ""
    property string _lastGeneratedImagePath: ""
    property string _lastGeneratedMode: ""
    property string _lastGeneratedSchemeType: ""
    property string _lastGeneratedStaticJson: ""
    property bool _hasGeneratedSuccessfully: false

    signal generationStarted()
    signal generationFinished(bool success)

    IpcHandler {
        target: "matugen"

        function generate(imagePath: string, mode: string, schemeType: string): bool {
            return root.generate(imagePath, mode, schemeType);
        }

        function generateImage(imagePath: string): bool {
            return root.generate(imagePath);
        }

        function generateFromStatic(colorsJson: string, mode: string): bool {
            try {
                let parsed = JSON.parse(colorsJson);
                return root.generateFromStatic(parsed, mode);
            } catch(e) {
                return false;
            }
        }
    }

    function isMatugenTheme() {
        let themeConfig = Config.getSetting("theme", { "matugen": true, "activePreset": "Matugen" });

        if (themeConfig.matugen !== undefined) {
            return themeConfig.matugen === true;
        }

        return themeConfig.theme === "matugen"
            || themeConfig.name === "matugen"
            || themeConfig.currentTheme === "matugen"
            || themeConfig.current === "matugen"
            || themeConfig.activePreset === "Matugen"
            || themeConfig.activePreset === undefined;
    }

    function toMd3(colorsObj) {
        let lum = function(hex) {
            if (!hex || typeof hex !== "string") return 0;
            let c = hex.replace("#", "");
            if (c.length === 3) {
                c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
            }
            let r = parseInt(c.substr(0, 2), 16) / 255;
            let g = parseInt(c.substr(2, 2), 16) / 255;
            let b = parseInt(c.substr(4, 2), 16) / 255;
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        };

        let onColorFor = function(hex) {
            let crustHex = (colorsObj.crust !== undefined) ? colorsObj.crust.toString() : "#11111b";
            let textHex = (colorsObj.text !== undefined) ? colorsObj.text.toString() : "#cdd6f4";
            return lum(hex ? hex.toString() : "") > 0.5 ? crustHex : textHex;
        };

        let wrap = function(hex) {
            let val = hex ? hex.toString() : "#000000";
            return {
                default: { hex: val, color: val },
                dark: { hex: val, color: val },
                light: { hex: val, color: val }
            };
        };

        let md3 = {
            surface_container_lowest: colorsObj.base,
            surface_container_low:    colorsObj.mantle,
            surface:                  colorsObj.crust,
            surface_container:        colorsObj.surface0,
            surface_container_high:   colorsObj.surface1,
            surface_container_highest:colorsObj.surface2,
            surface_variant:          colorsObj.surface1,
            on_surface:               colorsObj.text,
            on_surface_variant:       colorsObj.subtext0,
            outline:                  colorsObj.subtext1,
            inverse_surface:          colorsObj.overlay0,
            inverse_on_surface:       colorsObj.crust,
            background:               colorsObj.crust,
            on_background:            colorsObj.text,
            surface_dim:              colorsObj.crust,
            surface_bright:           colorsObj.surface1,
            outline_variant:          colorsObj.surface2,
            shadow:                   "#000000",
            scrim:                    "#000000",
            surface_tint:             colorsObj.blue,
            source_color:             colorsObj.blue,

            primary:             colorsObj.blue,
            primary_container:   colorsObj.sapphire,
            secondary:           colorsObj.green,
            secondary_container: colorsObj.yellow,
            tertiary:            colorsObj.peach,
            tertiary_container:  colorsObj.pink,
            error:               colorsObj.red,
            error_container:     colorsObj.maroon,

            primary_fixed:       colorsObj.sapphire,
            secondary_fixed:     colorsObj.yellow,
            tertiary_fixed:      colorsObj.pink,
            primary_fixed_dim:   colorsObj.blue,
            secondary_fixed_dim: colorsObj.green,
            tertiary_fixed_dim:  colorsObj.peach,
            inverse_primary:     colorsObj.mauve
        };

        let roles = ["primary", "secondary", "tertiary", "error"];
        for (let i = 0; i < roles.length; i++) {
            let role = roles[i];
            md3["on_" + role] = onColorFor(md3[role]);
            md3["on_" + role + "_container"] = onColorFor(md3[role + "_container"]);
        }
        let fixedRoles = ["primary", "secondary", "tertiary"];
        for (let i = 0; i < fixedRoles.length; i++) {
            let role = fixedRoles[i];
            md3["on_" + role + "_fixed"] = onColorFor(md3[role + "_fixed"]);
            md3["on_" + role + "_fixed_variant"] = onColorFor(md3[role + "_fixed_dim"]);
        }

        let out = { colors: {} };
        let keys = Object.keys(md3);
        for (let i = 0; i < keys.length; i++) {
            let k = keys[i];
            out.colors[k] = wrap(md3[k]);
        }
        return out;
    }

    function generate(imagePath, mode, schemeType) {
        if (!imagePath || imagePath.trim() === "") {
            return false;
        }
        if (!root.isMatugenTheme()) {
            return false;
        }

        let cleanPath = imagePath.startsWith("file://") ? imagePath.substring(7) : imagePath;
        let themeConfig = Config.getSetting("theme", {});
        let selectedMode = mode || themeConfig.mode || "dark";
        let selectedType = schemeType || themeConfig.schemeType || "scheme-tonal-spot";

        if (root._hasGeneratedSuccessfully
            && root._lastGeneratedReqType === "image"
            && root._lastGeneratedImagePath === cleanPath
            && root._lastGeneratedMode === selectedMode
            && root._lastGeneratedSchemeType === selectedType
            && !root.isRunning) {
            return true;
        }

        if (root.isRunning) {
            if (root._currentReqType === "image"
                && root._currentImagePath === cleanPath
                && root._currentMode === selectedMode
                && root._currentSchemeType === selectedType) {
                return true;
            }
            if (root._pendingRequest
                && root._pendingRequest.type === "image"
                && root._pendingRequest.imagePath === cleanPath
                && root._pendingRequest.mode === selectedMode
                && root._pendingRequest.schemeType === selectedType) {
                return true;
            }
            root._pendingRequest = { type: "image", imagePath: cleanPath, mode: selectedMode, schemeType: selectedType };
            return false;
        }

        root._startImageGenerate(cleanPath, selectedMode, selectedType);
        return true;
    }

    function _startImageGenerate(cleanPath, selectedMode, selectedType) {
        root.lastWallpaper = cleanPath;
        root._currentReqType = "image";
        root._currentImagePath = cleanPath;
        root._currentMode = selectedMode;
        root._currentSchemeType = selectedType;
        root._currentStaticJson = "";

        matugenProcess.reqType = "image";
        matugenProcess.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname \"$5\")\" || exit 1; " +
            "tmp=\"$5.tmp.$$\"; " +
            "if nice -n 15 matugen image \"$1\" -c \"$4\" -m \"$2\" -t \"$3\" --source-color-index 0 -j hex > \"$tmp\"; " +
            "then mv -f \"$tmp\" \"$5\"; else rm -f \"$tmp\"; exit 1; fi",
            "_", cleanPath, selectedMode, selectedType, root.configPath, root.palettePath
        ];
        root.generationStarted();
        matugenProcess.running = true;
    }

    function generateFromStatic(colorsObj, mode) {
        if (!colorsObj) {
            return false;
        }

        let themeConfig = Config.getSetting("theme", {});
        let selectedMode = mode || themeConfig.mode || "dark";
        let rawJson = JSON.stringify(colorsObj);

        if (root._hasGeneratedSuccessfully
            && root._lastGeneratedReqType === "static"
            && root._lastGeneratedStaticJson === rawJson
            && root._lastGeneratedMode === selectedMode
            && !root.isRunning) {
            return true;
        }

        if (root.isRunning) {
            if (root._currentReqType === "static"
                && root._currentStaticJson === rawJson
                && root._currentMode === selectedMode) {
                return true;
            }
            if (root._pendingRequest
                && root._pendingRequest.type === "static"
                && root._pendingRequest.rawJson === rawJson
                && root._pendingRequest.mode === selectedMode) {
                return true;
            }
            root._pendingRequest = { type: "static", colorsObj: colorsObj, rawJson: rawJson, mode: selectedMode };
            return false;
        }

        root._startStaticGenerate(colorsObj, rawJson, selectedMode);
        return true;
    }

    function _startStaticGenerate(colorsObj, rawJson, selectedMode) {
        root._currentReqType = "static";
        root._currentImagePath = "";
        root._currentMode = selectedMode;
        root._currentSchemeType = "";
        root._currentStaticJson = rawJson;

        let md3Obj = root.toMd3(colorsObj);
        md3Obj.mode = selectedMode === "light" ? "light" : "dark";
        md3Obj.is_dark_mode = md3Obj.mode === "dark";
        let md3Json = JSON.stringify(md3Obj);

        matugenProcess.reqType = "static";
        matugenProcess.command = [
            "bash", "-c",
            "mkdir -p \"$1\" \"$(dirname \"$4\")\" || exit 1; " +
            "printf '%s\\n' \"$2\" > \"$1/qs_colors.json.tmp.$$\" && mv -f \"$1/qs_colors.json.tmp.$$\" \"$1/qs_colors.json\" && " +
            "printf '%s\\n' \"$3\" > \"$4.tmp.$$\" && mv -f \"$4.tmp.$$\" \"$4\"",
            "_", root.stateDir, rawJson, md3Json, root.palettePath
        ];
        root.generationStarted();
        matugenProcess.running = true;
    }

    Process {
        id: matugenProcess
        running: false
        property string reqType: ""

        onExited: (exitCode) => {
            let success = (exitCode === 0);

            if (success) {
                root._hasGeneratedSuccessfully = true;
                root._lastGeneratedReqType = root._currentReqType;
                root._lastGeneratedImagePath = root._currentImagePath;
                root._lastGeneratedMode = root._currentMode;
                root._lastGeneratedSchemeType = root._currentSchemeType;
                root._lastGeneratedStaticJson = root._currentStaticJson;

                if (matugenProcess.reqType === "image") {
                    Quickshell.execDetached(["bash", "-c", "cp -f \"$1/qs_colors.json\" \"$1/qs_matugen_colors.json\" 2>/dev/null || true", "_", root.stateDir]);
                }
                AppTheming.apply();
            }

            root._currentReqType = "";
            root._currentImagePath = "";
            root._currentMode = "";
            root._currentSchemeType = "";
            root._currentStaticJson = "";

            root.generationFinished(success);

            if (root._pendingRequest) {
                let req = root._pendingRequest;
                root._pendingRequest = null;

                let isRedundant = false;
                if (success) {
                    if (req.type === "image"
                        && root._lastGeneratedReqType === "image"
                        && root._lastGeneratedImagePath === req.imagePath
                        && root._lastGeneratedMode === req.mode
                        && root._lastGeneratedSchemeType === req.schemeType) {
                        isRedundant = true;
                    } else if (req.type === "static"
                        && root._lastGeneratedReqType === "static"
                        && root._lastGeneratedStaticJson === req.rawJson
                        && root._lastGeneratedMode === req.mode) {
                        isRedundant = true;
                    }
                }

                if (!isRedundant) {
                    if (req.type === "image") {
                        root._startImageGenerate(req.imagePath, req.mode, req.schemeType);
                    } else {
                        root._startStaticGenerate(req.colorsObj, req.rawJson, req.mode);
                    }
                }
            }
        }
    }
}
