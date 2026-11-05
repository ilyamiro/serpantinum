import QtQuick

Item {
    property int activeIndex: 0
    property var activeIndicesByOutput: ({})
    property var occupiedMap: ({})

    function activeIndexFor(outputName) {
        if (outputName && activeIndicesByOutput && activeIndicesByOutput[outputName] !== undefined) {
            return activeIndicesByOutput[outputName];
        }
        return activeIndex;
    }
}
