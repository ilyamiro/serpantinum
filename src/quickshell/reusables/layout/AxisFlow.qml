import QtQuick

Grid {
    property bool vertical: false

    flow: Grid.LeftToRight
    rows: vertical ? -1 : 1
    columns: vertical ? 1 : -1

    onVerticalChanged: {
        rows = -1;
        columns = -1;
        if (vertical) columns = 1;
        else rows = 1;
    }
}
