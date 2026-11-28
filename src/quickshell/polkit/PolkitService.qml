pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "../"

Item {
    id: root

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.errorMessage = "";
            root.requestStarted();
        }
    }

    readonly property bool isActive: agent.isActive
    readonly property bool isRegistered: agent.isRegistered
    readonly property var flow: agent.flow
    property string errorMessage: ""

    signal requestStarted()
    signal requestCancelled()
    signal authenticationFailed()
    signal authenticationSucceeded()

    function submit(response) {
        if (agent.flow && typeof agent.flow.submit === "function") {
            agent.flow.submit(response);
        }
    }

    function cancel() {
        if (agent.flow && typeof agent.flow.cancelAuthenticationRequest === "function") {
            agent.flow.cancelAuthenticationRequest();
        }
        root.errorMessage = "";
    }

    Connections {
        target: agent.flow

        function onAuthenticationFailed() {
            if (agent.flow && agent.flow.supplementaryMessage) {
                root.errorMessage = agent.flow.supplementaryMessage;
            } else {
                root.errorMessage = typeof I18n !== "undefined" ? I18n.t("polkit.error_failed") : "Authentication failed. Please try again.";
            }
            root.authenticationFailed();
        }

        function onAuthenticationSucceeded() {
            root.errorMessage = "";
            root.authenticationSucceeded();
        }

        function onAuthenticationRequestCancelled() {
            root.errorMessage = "";
            root.requestCancelled();
        }

        function onSupplementaryMessageChanged() {
            if (agent.flow && agent.flow.supplementaryIsError && agent.flow.supplementaryMessage) {
                root.errorMessage = agent.flow.supplementaryMessage;
            }
        }
    }
}
