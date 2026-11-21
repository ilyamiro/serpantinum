pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// State of the `sudo -A` password dialog, alive for the shell's lifetime so
// the IPC calls are always answered; Askpass.qml (the window) is loaded only
// while a request is open. bin/serpantinum-askpass (SUDO_ASKPASS) creates a
// FIFO, calls ask() and prints the line written to the FIFO: the password,
// or an empty line when the dialog is cancelled.
Item {
    id: root

    readonly property bool isActive: root.fifo !== ""
    property string fifo: ""
    property string prompt: ""
    property string title: ""
    property string message: ""
    property bool retry: false

    signal requestStarted()

    IpcHandler {
        target: "askpass"

        // prompt: sudo's own prompt, shown as the placeholder; title and
        // message fall back to the polkit texts; retry marks a wrong password
        function ask(fifo: string, prompt: string, title: string, message: string, retry: bool): void {
            // A newer request replaces an unanswered one: its reader gets EOF
            if (root.isActive) root.answer("");
            root.prompt = prompt;
            root.title = title;
            root.message = message;
            root.retry = retry;
            root.fifo = fifo;
            root.requestStarted();
        }

        // The helper gave up (sudo interrupted or timed out): close quietly
        function cancel(fifo: string): void {
            if (root.fifo === fifo) root.fifo = "";
        }
    }

    // Hands the answer to the waiting helper; an empty answer means cancel.
    // timeout: the open blocks if the helper is gone and nobody reads
    function answer(text) {
        if (root.fifo === "") return;
        const proc = writerComponent.createObject(root, {
            command: ["timeout", "10", "sh", "-c", 'cat > "$1"', "serpantinum-askpass", root.fifo],
            payload: text
        });
        root.fifo = "";
        proc.running = true;
    }

    function cancel() {
        root.answer("");
    }

    Component {
        id: writerComponent
        Process {
            property string payload: ""
            stdinEnabled: true
            onStarted: {
                write(payload + "\n");
                payload = "";
                stdinEnabled = false;
            }
            onExited: destroy()
        }
    }
}
