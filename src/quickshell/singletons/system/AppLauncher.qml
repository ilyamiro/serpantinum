pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    // The shell's Qt/QML paths belong to its own Qt build; apps it starts must not inherit them.
    property Process proc: Process {
        environment: ({ QT_PLUGIN_PATH: null, QML2_IMPORT_PATH: null, NIXPKGS_QT6_QML_IMPORT_PATH: null })
    }

    // Same as DesktopEntry.execute(), without the shell's Qt environment.
    function launch(entry) {
        proc.command = entry.command;
        proc.workingDirectory = entry.workingDirectory;
        proc.startDetached();
    }
}
