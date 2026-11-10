import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property bool vertical: false

    implicitWidth: vertical ? window.s(380) : window.s(1080)
    implicitHeight: vertical ? window.s(980) : window.s(420)

    readonly property real panelRadius: Math.min(ThemeBackend.borderRadius, window.s(28))
    property color backgroundColor: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
    property real cornerTopLeft: panelRadius
    property real cornerTopRight: panelRadius
    property real cornerBottomLeft: panelRadius
    property real cornerBottomRight: panelRadius

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    Shortcut {
        sequence: "Left"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return ThemeBackend.peach;
        if (h >= 12 && h < 17) return ThemeBackend.sapphire;
        if (h >= 17 && h < 21) return ThemeBackend.mauve;
        return ThemeBackend.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return ThemeBackend.yellow;
        if (h >= 12 && h < 17) return ThemeBackend.teal;
        if (h >= 17 && h < 21) return ThemeBackend.pink;
        return ThemeBackend.mauve;
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(ThemeBackend.text, 0.35))

    property bool startupComplete: false
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    function resetState() {
        introAnim.stop();
        dayFadeAnim.stop();
        calendarTransitionAnim.stop();
        startupComplete = false;
        introAmbient = 0;
        introClock = 0;
        introCalendar = 0;
        introWeather = 0;
        dayOpacity = 1.0;
        dayOffset = 0.0;
        calendarContentOpacity = 1.0;
        calendarContentOffset = 0.0;
    }

    onVisibleChanged: {
        if (visible) {
            resetState();
            forceActiveFocus();
            focusTimer.restart();
            window.gridDay = DateTime.now.getDate();
            updateCalendarGrid();
            Weather.refresh(false);
            introAnim.restart();
        } else {
            resetState();
        }
    }

    SequentialAnimation {
        id: introAnim

        ParallelAnimation {
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 700; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 90 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 170 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 560; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 170 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 560; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    property var currentTime: DateTime.now
    property int gridDay: -1

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    Connections {
        target: DateTime
        enabled: window.visible
        function onNowChanged() {
            window.secondPulse = 1.02;
            pulseReset.start();

            let day = DateTime.now.getDate();
            if (day !== window.gridDay) {
                window.gridDay = day;
                window.updateCalendarGrid();
            }
        }
    }

    readonly property var weatherData: Weather.data
    readonly property var forecastList: weatherData && weatherData.forecast ? weatherData.forecast : []
    readonly property bool offline: !!(weatherData && weatherData.offline)

    property int weatherView: 0
    property int targetWeatherView: 0
    property real dayOpacity: 1.0
    property real dayOffset: 0.0
    property int dayAnimDirection: 1

    readonly property var dayData: forecastList[weatherView] || null
    readonly property var targetDayData: forecastList[targetWeatherView] || null
    readonly property var todayData: forecastList[0] || null

    property real targetTemp: {
        if (!window.weatherData || window.offline) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.targetDayData) return Number(window.targetDayData.max);
        return 0;
    }

    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return ThemeBackend.text;
        if (window.targetTemp > window.displayedTemp) return ThemeBackend.red;
        if (window.targetTemp < window.displayedTemp) return ThemeBackend.blue;
        return ThemeBackend.text;
    }

    readonly property string heroIcon: {
        if (!window.weatherData) return "";
        if (window.weatherView === 0 && window.weatherData.current_icon) return window.weatherData.current_icon;
        return window.dayData ? window.dayData.icon : "";
    }

    readonly property color heroHex: {
        if (!window.weatherData) return ThemeBackend.mauve;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        return window.dayData && window.dayData.hex ? window.dayData.hex : ThemeBackend.mauve;
    }

    readonly property string cityName: (typeof Location !== "undefined" && Location.city && Location.city !== "") ? Location.city : (window.weatherData && window.weatherData.city ? window.weatherData.city : "")

    readonly property int hourCount: window.vertical ? 6 : 8

    readonly property var stripDays: window.forecastList.slice(0, 5)
    readonly property var stripSlots: {
        let out = [];
        for (let i = 0; i < window.stripDays.length; i++) {
            out = out.concat((window.stripDays[i].hourly || []).slice(0, 8));
        }
        return out;
    }
    readonly property var stripDayStarts: {
        let starts = [];
        let n = 0;
        for (let i = 0; i < window.stripDays.length; i++) {
            starts.push(n);
            n += Math.min(8, (window.stripDays[i].hourly || []).length);
        }
        return starts;
    }
    readonly property int liveHourIndex: {
        let day0 = window.stripDays.length > 0 ? (window.stripDays[0].hourly || []).slice(0, 8) : [];
        if (day0.length === 0) return -1;
        let ch = window.currentTime.getHours();
        let bestIdx = 0;
        let minDiff = 999;
        for (let i = 0; i < day0.length; i++) {
            let c = window.parseClock(day0[i].time);
            let diff = Math.abs((c ? c.h : 0) - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx;
    }
    readonly property int stripStart: {
        let t = window.targetWeatherView;
        let base = window.stripDayStarts[t] !== undefined ? window.stripDayStarts[t] : 0;
        let start = t === 0 ? Math.max(0, window.liveHourIndex - 1) : base;
        return Math.max(0, Math.min(start, window.stripSlots.length - window.hourCount));
    }

    property real stripPos: stripStart
    Behavior on stripPos {
        NumberAnimation { duration: 650; easing.type: Easing.OutCubic }
    }
    readonly property real focusStrength: Math.max(0, Math.min(1, 1 - window.stripPos / Math.max(1, window.stripDayStarts[1] || 8)))
    readonly property real stripSpin: Math.max(-28, Math.min(28, (window.stripStart - window.stripPos) * 9))

    function parseClock(str) {
        if (!str) return null;
        let clockPart = String(str).trim().split(" ");
        clockPart = clockPart.length > 1 && clockPart[0].indexOf("-") !== -1 ? clockPart[1] : clockPart[0];
        let p = clockPart.split(":");
        let h = parseInt(p[0]);
        let m = parseInt(p[1] || "0");
        if (isNaN(h) || isNaN(m)) return null;
        return { h: h, m: m };
    }

    function fmtClock(str) {
        let c = window.parseClock(str);
        if (!c) return "";
        return DateTime.format(DateTime.timeFormat.replace(/[:.]s{1,2}/, ""), new Date(2000, 0, 1, c.h, c.m));
    }

    function clockMinutes(str) {
        let c = window.parseClock(str);
        return c ? c.h * 60 + c.m : -1;
    }

    readonly property real sunriseMin: window.todayData ? window.clockMinutes(window.todayData.sunrise) : -1
    readonly property real sunsetMin: window.todayData ? window.clockMinutes(window.todayData.sunset) : -1
    readonly property bool hasSun: !window.offline && sunriseMin >= 0 && sunsetMin > sunriseMin

    readonly property real rangeMin: {
        let v = Infinity;
        for (let i = 0; i < window.forecastList.length; i++) {
            let n = Number(window.forecastList[i].min);
            if (!isNaN(n) && n < v) v = n;
        }
        return v;
    }

    readonly property real rangeMax: {
        let v = -Infinity;
        for (let i = 0; i < window.forecastList.length; i++) {
            let n = Number(window.forecastList[i].max);
            if (!isNaN(n) && n > v) v = n;
        }
        return v;
    }

    SequentialAnimation {
        id: dayFadeAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "dayOpacity"; to: 0.0; duration: 180; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "dayOffset"; to: -window.s(24) * window.dayAnimDirection; duration: 180; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.weatherView = window.targetWeatherView;
                window.dayOffset = window.s(24) * window.dayAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "dayOpacity"; to: 1.0; duration: 320; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "dayOffset"; to: 0.0; duration: 320; easing.type: Easing.OutQuart }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || idx >= window.forecastList.length) return;
        if (idx === window.targetWeatherView) return;

        if (dayFadeAnim.running) {
            dayFadeAnim.stop();
            window.weatherView = window.targetWeatherView;
            window.dayOpacity = 1.0;
            window.dayOffset = 0.0;
        }

        window.dayAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        dayFadeAnim.start();
    }

    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: -window.s(20) * calendarAnimDirection; duration: 250; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
            window.calendarContentOpacity = 1.0;
            window.calendarContentOffset = 0.0;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        let monthLoc = Qt.locale(I18n.qtLocaleName);
        let monthName = monthLoc.standaloneMonthName(d.getMonth(), Locale.LongFormat);
        window.targetMonthName = monthName.charAt(0).toUpperCase() + monthName.slice(1) + " " + d.getFullYear();

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            Weather.refresh(false);
            introAnim.restart();
        }
    }

    component Blob: Rectangle {
        id: blob
        property real fx: 0.5
        property real fy: 0.5
        property real sizeFactor: 0.5
        property real strength: 0.01
        property real rangeX: 0
        property real rangeY: 0
        property int period: 30000

        width: parent.width * sizeFactor
        height: width
        radius: width / 2
        x: parent.width * fx - width / 2
        y: parent.height * fy - height / 2
        opacity: strength * window.introAmbient
        Behavior on color { ColorAnimation { duration: 1000 } }

        transform: Translate {
            SequentialAnimation on x {
                loops: Animation.Infinite
                running: window.visible
                NumberAnimation { from: blob.rangeX; to: -blob.rangeX; duration: blob.period; easing.type: Easing.InOutSine }
                NumberAnimation { from: -blob.rangeX; to: blob.rangeX; duration: blob.period; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
                loops: Animation.Infinite
                running: window.visible
                NumberAnimation { from: -blob.rangeY; to: blob.rangeY; duration: blob.period * 0.75; easing.type: Easing.InOutSine }
                NumberAnimation { from: blob.rangeY; to: -blob.rangeY; duration: blob.period * 0.75; easing.type: Easing.InOutSine }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: window.panelRadius
        topLeftRadius: window.cornerTopLeft
        topRightRadius: window.cornerTopRight
        bottomLeftRadius: window.cornerBottomLeft
        bottomRightRadius: window.cornerBottomRight
        color: window.backgroundColor
        clip: true

        Blob {
            fx: 0.75; fy: 0.3; sizeFactor: 0.5; strength: 0.012
            rangeX: window.s(260); rangeY: window.s(150); period: 30000
            color: window.heroHex
        }

        Blob {
            fx: 0.25; fy: 0.7; sizeFactor: 0.6; strength: 0.01
            rangeX: window.s(220); rangeY: window.s(180); period: 37500
            color: window.timeColor
        }

        Blob {
            fx: 0.5; fy: 0.5; sizeFactor: 0.45; strength: 0.007
            rangeX: window.s(300); rangeY: window.s(240); period: 25000
            color: window.timeAccent
        }

        Text {
            anchors.centerIn: parent
            text: window.heroIcon
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(400)
            color: window.heroHex
            opacity: 0.015 * window.introAmbient * window.dayOpacity
            Behavior on color { ColorAnimation { duration: 1500 } }

            transform: [
                Translate {
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { to: -window.s(8); duration: 6000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                    }
                },
                Translate { x: window.dayOffset * 2 }
            ]
        }

        GridLayout {
            anchors.fill: parent
            anchors.margins: window.vertical ? window.s(20) : window.s(28)
            columns: window.vertical ? 1 : 3
            rowSpacing: window.s(16)
            columnSpacing: window.s(24)

            Rectangle {
                id: calendarRect
                Layout.row: window.vertical ? 2 : 0
                Layout.column: 0
                Layout.fillWidth: window.vertical
                Layout.preferredWidth: window.s(270)
                Layout.preferredHeight: window.vertical ? window.s(290) : window.s(330)
                Layout.alignment: Qt.AlignVCenter
                color: calendarGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.2)
                radius: ThemeBackend.borderRadius

                opacity: window.introCalendar
                transform: Translate { x: -window.s(40) * (1.0 - window.introCalendar) }

                GlassFill {
                    id: calendarGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.25
                }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: window.s(12)
                    anchors.bottomMargin: window.s(12)
                    anchors.leftMargin: window.s(14)
                    anchors.rightMargin: window.s(14)
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: window.s(12)
                        layoutDirection: I18n.layoutDirection

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: "󰃭"
                            iconFontSize: window.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            opacity: window.targetMonthOffset !== 0 ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            onClicked: { if (window.targetMonthOffset !== 0) window.setMonthOffset(0) }
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(14)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: ThemeBackend.text
                            horizontalAlignment: Text.AlignHCenter

                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset + 1)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: window.s(4)
                        spacing: 0
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: [I18n.t("calendar.days.mo"), I18n.t("calendar.days.tu"), I18n.t("calendar.days.we"), I18n.t("calendar.days.th"), I18n.t("calendar.days.fr"), I18n.t("calendar.days.sa"), I18n.t("calendar.days.su")]
                            Text {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: window.s(11.5)
                                color: ThemeBackend.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: window.s(2)
                        columnSpacing: window.s(3)
                        layoutDirection: I18n.layoutDirection

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            ClickButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 1
                                enabled: false
                                buttonText: dayNum
                                textFontSize: window.s(11.5)
                                cornerRadius: window.s(5)
                                horizontalPadding: 0
                                accentColor: isToday ? window.textAccent : ((ThemeBackend.liquidGlass && !isCurrentMonth) ? ThemeBackend.surface0 : "transparent")
                                glassTintScale: isToday ? 2.6 : 1.0
                                textColor: ThemeBackend.liquidGlass ? (isCurrentMonth ? ThemeBackend.text : ThemeBackend.subtext0) : (isToday ? ThemeBackend.base : (isCurrentMonth ? ThemeBackend.text : ThemeBackend.surface0))
                            }
                        }
                    }
                }
            }

            Item {
                id: centralHub
                Layout.row: 0
                Layout.column: window.vertical ? 0 : 1
                Layout.fillWidth: true
                Layout.fillHeight: !window.vertical
                Layout.preferredHeight: window.vertical ? window.s(290) : -1

                opacity: window.introClock
                scale: 0.85 + (0.15 * window.introClock)
                transform: Translate { y: window.s(25) * (1.0 - window.introClock) }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: window.s(14)

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(window.s(340), centralHub.width)
                        Layout.preferredHeight: window.s(190)

                        SunArc {
                            anchors.fill: parent
                            anchors.topMargin: window.vertical ? window.s(8) : -window.s(16)
                            anchors.leftMargin: window.vertical ? window.s(8) : -window.s(12)
                            anchors.rightMargin: window.vertical ? window.s(8) : -window.s(12)
                            revealed: window.introClock > 0.3
                            opacity: window.hasSun ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 400 } }
                            sunriseMin: window.sunriseMin
                            sunsetMin: window.sunsetMin
                            nowMin: window.currentTime.getHours() * 60 + window.currentTime.getMinutes()
                            sunriseText: window.todayData ? window.fmtClock(window.todayData.sunrise) : ""
                            sunsetText: window.todayData ? window.fmtClock(window.todayData.sunset) : ""
                            trackColor: Qt.alpha(window.textAccent, 0.3)
                            progressColor: window.textAccent
                            labelColor: ThemeBackend.overlay1
                        }

                        ColumnLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: window.s(24)
                            spacing: 0
                            scale: 0.98 + (0.02 * window.secondPulse)

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: DateTime.time
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: {
                                    let baseSize = window.s(70);
                                    let len = (DateTime.time || "").length;
                                    if (len <= 5) return baseSize;
                                    let scaleFactor = Math.min(1.0, Math.pow(5 / len, 0.7));
                                    return Math.round(Math.max(window.s(32), baseSize * scaleFactor));
                                }
                                color: ThemeBackend.text
                                style: Text.Outline
                                styleColor: Qt.alpha(ThemeBackend.crust, 0.4)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: DateTime.fullDate
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: window.s(15)
                                color: ThemeBackend.subtext0
                                opacity: 0.9
                            }
                        }
                    }

                    Item {
                        id: hourStrip
                        readonly property real pad: window.s(4)
                        readonly property real pillStep: window.s(46) + window.s(6)

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: window.s(98)
                        Layout.preferredWidth: window.hourCount * pillStep - window.s(6) + 2 * pad
                        clip: true

                    Row {
                        id: hourRow
                        y: Math.round((parent.height - height) / 2)
                        x: hourStrip.pad - window.stripPos * hourStrip.pillStep
                        spacing: window.s(6)

                        Repeater {
                            model: window.stripSlots

                            delegate: Item {
                                id: hourPill
                                readonly property bool isHighlighted: index === window.liveHourIndex

                                property real hoverScale: hrMa.containsMouse && !isHighlighted ? 1.04 : 1.0
                                Behavior on hoverScale { NumberAnimation { duration: 150 } }

                                anchors.verticalCenter: parent.verticalCenter
                                width: window.s(46)
                                height: window.s(78)
                                z: isHighlighted ? 1 : 0
                                readonly property real arc: Math.max(-1.3, Math.min(1.3,
                                    (x + width / 2 - (window.stripPos * hourStrip.pillStep + (hourStrip.width / 2 - hourStrip.pad))) / (hourStrip.width / 2)))
                                readonly property real emphasis: Math.max(0, 1 - Math.abs(index - window.liveHourIndex) / 5)
                                scale: (isHighlighted ? 1.08 + 0.12 * window.focusStrength : 1.0 - (1.0 - (0.72 + 0.26 * emphasis)) * window.focusStrength) * hoverScale
                                opacity: isHighlighted ? 1.0 : 0.85 - (0.85 - (0.35 + 0.5 * emphasis)) * window.focusStrength
                                rotation: -arc * 9 + window.stripSpin
                                transform: Translate { y: (0.5 - hourPill.arc * hourPill.arc) * window.s(14) }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(window.s(16), ThemeBackend.borderRadius * 1.25)
                                    color: hourGlass.active ? "transparent" : (hourPill.isHighlighted ? window.textAccent : (hrMa.containsMouse ? Qt.lighter(ThemeBackend.surface0, 1.12) : ThemeBackend.surface0))
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    GlassFill {
                                        id: hourGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        forceClear: true
                                        tintColor: hourPill.isHighlighted ? window.textAccent : ThemeBackend.surface0
                                        tintAmount: hourPill.isHighlighted ? 0.4 : 0.2
                                        tintStrength: 1.0
                                        press: hrMa.pressed ? 0.8 : (hrMa.containsMouse ? 0.25 : 0)
                                        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: window.s(3)

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData ? modelData.time : ""
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(10.5)
                                            color: (hourPill.isHighlighted && !hourGlass.active) ? ThemeBackend.base : (hrMa.containsMouse || hourPill.isHighlighted ? ThemeBackend.text : ThemeBackend.overlay1)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData ? (modelData.icon || (window.dayData ? window.dayData.icon : "")) : ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: window.s(16)
                                            color: (hourPill.isHighlighted && !hourGlass.active) ? ThemeBackend.base : (modelData ? (modelData.hex || ThemeBackend.text) : ThemeBackend.text)
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData ? (modelData.temp + "°") : ""
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Black
                                            font.pixelSize: window.s(12)
                                            color: (hourPill.isHighlighted && !hourGlass.active) ? ThemeBackend.base : ThemeBackend.text
                                        }
                                    }
                                }

                                MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                    }
                }
            }

            Item {
                id: weatherContainer
                Layout.row: window.vertical ? 1 : 0
                Layout.column: window.vertical ? 0 : 2
                Layout.fillWidth: window.vertical
                Layout.fillHeight: true
                Layout.preferredWidth: window.s(260)
                Layout.preferredHeight: window.vertical ? window.s(330) : -1

                opacity: window.introWeather
                transform: Translate { x: window.s(40) * (1.0 - window.introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: window.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(10)
                        layoutDirection: I18n.layoutDirection

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(12)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : ThemeBackend.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: window.dayData && window.dayData.day_full ? window.dayData.day_full.toUpperCase() : I18n.t("calendar.loading")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(14)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: ThemeBackend.text
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(12)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : ThemeBackend.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.alignment: window.vertical ? Qt.AlignHCenter : Qt.AlignRight
                            text: (window.offline ? "--" : window.displayedTemp.toFixed(1)) + (Weather.unitSym || "°")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(58)
                            color: window.tempGlowColor
                            style: Text.Outline
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(ThemeBackend.crust, 0.4)

                            Behavior on color { ColorAnimation { duration: 250 } }
                            Behavior on styleColor { ColorAnimation { duration: 250 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: window.vertical ? Text.AlignHCenter : Text.AlignRight
                            text: window.cityName
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: window.s(14)
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: window.s(2)
                            horizontalAlignment: window.vertical ? Text.AlignHCenter : Text.AlignRight
                            text: window.dayData ? window.dayData.desc : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: window.s(13)
                            elide: Text.ElideRight
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            opacity: window.dayOpacity
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(70)
                        spacing: window.s(4)
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: window.forecastList.slice(0, 5)

                            Rectangle {
                                id: dayCell
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1

                                readonly property bool selected: index === window.targetWeatherView
                                readonly property real dMin: Number(modelData.min)
                                readonly property real dMax: Number(modelData.max)
                                readonly property bool hasRange: !window.offline && !isNaN(dMin) && !isNaN(dMax) && isFinite(window.rangeMin) && isFinite(window.rangeMax)
                                readonly property real span: Math.max(0.0001, window.rangeMax - window.rangeMin)

                                radius: window.s(9)
                                color: selected ? Qt.alpha(window.textAccent, 0.2) : (dayMa.containsMouse ? Qt.alpha(ThemeBackend.surface0, 0.6) : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: window.s(4)
                                    spacing: window.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.day || ""
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(10.5)
                                        color: dayCell.selected ? ThemeBackend.text : ThemeBackend.overlay1
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.icon || ""
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: window.s(15)
                                        color: modelData.hex || ThemeBackend.text
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: window.s(4)
                                        Layout.leftMargin: window.s(4)
                                        Layout.rightMargin: window.s(4)

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: Qt.alpha(ThemeBackend.overlay0, 0.3)
                                        }

                                        Rectangle {
                                            visible: dayCell.hasRange
                                            height: parent.height
                                            radius: height / 2
                                            x: (dayCell.dMin - window.rangeMin) / dayCell.span * (parent.width - width)
                                            width: Math.max(parent.height, (dayCell.dMax - dayCell.dMin) / dayCell.span * parent.width)
                                            color: modelData.hex || window.textAccent
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: dayCell.hasRange ? Math.round(dayCell.dMax) + "°" : "--"
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: window.s(10.5)
                                        color: ThemeBackend.text
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: dayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.setWeatherView(index)
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: window.s(8)
                        columnSpacing: window.s(8)
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: 4

                            ClickButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: window.s(40)
                                cornerRadius: window.s(9)
                                horizontalPadding: window.s(8)

                                buttonIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                buttonText: window.offline ? "--" : window.targetDayData ? (
                                    index === 0 ? window.targetDayData.wind + (Weather.unit === "imperial" ? "mph" : "m/s") :
                                    index === 1 ? window.targetDayData.humidity + "%" :
                                    index === 2 ? window.targetDayData.pop + "%" :
                                    window.targetDayData.feels_like + "°"
                                ) : ""
                                subText: index === 0 ? I18n.t("calendar.weather.wind") : index === 1 ? I18n.t("calendar.weather.humid") : index === 2 ? I18n.t("calendar.weather.rain") : I18n.t("calendar.weather.feels")

                                iconFontSize: window.s(14)
                                textFontSize: window.s(11.5)

                                accentColor: ThemeBackend.surface0
                                textColor: isHoveredOrHighlighted ? window.textAccent : ThemeBackend.overlay0
                            }
                        }
                    }
                }
            }
        }
    }
}
