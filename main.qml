import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects 1.0

ApplicationWindow {
    id: window
    width: 1280
    height: 800
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    title: { var _ = i18n.language; return i18n.t("app_title") + " — " + i18n.t("app_subtitle"); }

    // ========== RTL / LTR ==========
    property bool rtl: i18n.language === "ar"
    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true

    // ========== RESPONSIVE ==========
    property bool isCompact: window.width < 1024
    property int gridCols: mainContent.width < 620 ? 1 : 2
    property real sideW: isCompact ? Math.round(72 * fs) : Math.round(116 * fs)

    // ========== THEME ==========
    property color accentColor: {
        var _ = cyberLogic.themeId + cyberLogic.highContrast;
        if (cyberLogic.themeId === "soft") return "#7dd3fc";
        if (cyberLogic.themeId === "contrast" || cyberLogic.highContrast) return "#ffea00";
        return "#00e5ff";
    }
    property color accentDim: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
    property color glassSurface: cyberLogic.highContrast ? Qt.rgba(0.08, 0.08, 0.08, 0.92) : Qt.rgba(0.08, 0.09, 0.14, 0.68)
    property color glassBorder: cyberLogic.highContrast ? Qt.rgba(1,1,1,0.55) : Qt.rgba(1, 1, 1, 0.13)
    property color glassHighlight: Qt.rgba(1, 1, 1, cyberLogic.highContrast ? 0.0 : 0.06)
    property color panelColor: cyberLogic.highContrast ? "#1a1a1a" : Qt.rgba(1, 1, 1, 0.06)
    property color bgColor: {
        if (!cyberLogic.darkMode) return "#141824";
        return (cyberLogic.highContrast || cyberLogic.themeId === "contrast") ? "#000000" : "#050508";
    }
    property int bdr: cyberLogic.highContrast ? 12 : 20
    property bool isMagnifierActive: false
    property real fs: cyberLogic.fontScale
    property string clockStr: "00:00:00"
    property int animSpeed: cyberLogic.reduceMotion ? 0 : 220

    // ========== HELPERS ==========
    function tr(k) { var _l = i18n.language; return i18n.t(k); }
    function floatActLabel(id) {
        var m = { "click":"float_act_click","doubleclick":"float_act_doubleclick","drag":"float_act_drag","drop":"float_act_drop","screenshot":"float_act_screenshot","scroll_up":"float_act_scroll_up","scroll_down":"float_act_scroll_down","scroll_left":"float_act_scroll_left","scroll_right":"float_act_scroll_right","pause":"float_act_pause" };
        return tr(m[id] || "float_act_click");
    }
    function ic(name, col) {
        var s = icons[name]; if (!s) return "";
        return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(s.replace(/currentColor/g, col));
    }

    // ========== NAV MODEL ==========
    property var navModel: [
        { id: "dashboard", icon: "home",     key: "nav_dashboard" },
        { id: "tracking",  icon: "target",   key: "nav_tracking" },
        { id: "keyboard",  icon: "keyboard", key: "nav_keyboard" },
        { id: "info",      icon: "info",     key: "nav_info" },
        { id: "settings",  icon: "settings", key: "nav_settings" }
    ]

    // =====================================================
    //  REUSABLE COMPONENTS
    // =====================================================

    // ===== GLASS CARD =====
    component GlassCard: Item {
        id: gcRoot
        property int cardRadius: window.bdr
        property real cardPadding: Math.round(16 * window.fs)
        property alias content: gcContent.data

        DropShadow {
            anchors.fill: gcBg
            source: gcBg
            horizontalOffset: 0; verticalOffset: 4
            radius: 24; samples: 28
            color: Qt.rgba(0, 0.25, 0.7, cyberLogic.highContrast ? 0 : 0.18)
            spread: 0.05
        }
        Rectangle {
            id: gcBg
            anchors.fill: parent
            radius: gcRoot.cardRadius
            color: window.glassSurface
            border.width: 1
            border.color: window.glassBorder
        }
        // Top-edge light refraction
        Rectangle {
            width: gcBg.width - 2; height: Math.min(gcBg.height * 0.45, 70)
            x: 1; y: 1
            radius: gcRoot.cardRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: window.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Item {
            id: gcContent
            anchors.fill: gcBg
            anchors.margins: gcRoot.cardPadding
        }
    }

    // ===== ICON + LABEL HEADER =====
    component IconLabel: RowLayout {
        property string iconName: ""
        property string labelKey: ""
        property real sz: Math.round(17 * window.fs)
        spacing: 10
        Image {
            source: ic(iconName, accentColor)
            width: Math.round(24 * window.fs); height: width
            sourceSize.width: width; sourceSize.height: height
        }
        Label {
            text: tr(labelKey)
            font.pixelSize: sz; font.bold: true; color: accentColor
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
    }

    // ===== ACTION BAR (Save/Cancel/Defaults) =====
    component ActionBar: RowLayout {
        property string group: ""
        Layout.fillWidth: true; spacing: 10
        Repeater {
            model: [
                { key: "btn_save",     action: "save" },
                { key: "btn_cancel",   action: "cancel" },
                { key: "btn_defaults", action: "defaults" }
            ]
            delegate: Button {
                Layout.fillWidth: true
                implicitHeight: Math.round(48 * fs); flat: true
                background: Rectangle {
                    radius: 12
                    color: {
                        if (modelData.action === "save") return parent.pressed ? Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.4) : accentDim;
                        return parent.pressed ? Qt.rgba(1,1,1,0.12) : panelColor;
                    }
                    border.color: modelData.action === "save" ? accentColor : glassBorder
                    border.width: modelData.action === "save" ? 2 : 1
                }
                contentItem: Label {
                    text: tr(modelData.key)
                    color: "white"; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Math.round(12 * fs)
                }
                onClicked: {
                    if (modelData.action === "save") { cyberLogic.saveSettingsGroup(group); cyberLogic.notify(tr("notif_settings_saved"),"info"); }
                    else if (modelData.action === "cancel") cyberLogic.cancelSettingsGroup(group);
                    else cyberLogic.resetSettingsGroupDefaults(group);
                }
            }
        }
    }

    // ===== GLASS SLIDER ROW =====
    component SliderCard: GlassCard {
        property string label: ""
        property int val: 50
        property int lo: 0
        property int hi: 100
        signal moved(int v)
        Layout.fillWidth: true; Layout.minimumHeight: Math.round(110 * fs)
        content: [
        ColumnLayout {
            anchors.fill: parent; spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Label { text: label; color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                Label { text: val + " %"; color: accentColor; font.bold: true; font.pixelSize: Math.round(15 * fs) }
            }
            Slider {
                from: lo; to: hi; stepSize: 1; value: val
                onMoved: parent.parent.parent.parent.parent.moved(Math.round(value))
                Layout.fillWidth: true
            }
        } ]
    }

    // =====================================================
    //  CLOCK & CONNECTIONS
    // =====================================================
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clockStr = Qt.formatDateTime(new Date(), "hh:mm:ss") }
    Connections { target: cyberLogic; function onCalibrationFinished() { cyberLogic.notify(tr("notif_cal_done"), "info"); } }

    color: cyberLogic.mainUIVisible ? bgColor : "transparent"

    // =====================================================
    //  BACKGROUND — ambient orbs for glass depth
    // =====================================================
    Item {
        id: bgLayer
        anchors.fill: parent; z: 0; visible: cyberLogic.mainUIVisible
        Rectangle { anchors.fill: parent; color: bgColor }
        Rectangle {
            id: orb1
            width: 520; height: 520; radius: 260
            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.035)
            x: -120; y: -80
            SequentialAnimation on x {
                running: !cyberLogic.reduceMotion; loops: Animation.Infinite
                NumberAnimation { to: 180; duration: 20000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -120; duration: 20000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            width: 400; height: 400; radius: 200
            color: Qt.rgba(0.45, 0.15, 0.85, 0.025)
            x: parent.width - 280; y: parent.height - 320
            SequentialAnimation on y {
                running: !cyberLogic.reduceMotion; loops: Animation.Infinite
                NumberAnimation { to: parent.parent.height - 180; duration: 16000; easing.type: Easing.InOutSine }
                NumberAnimation { to: parent.parent.height - 320; duration: 16000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            width: 300; height: 300; radius: 150
            color: Qt.rgba(0.1, 0.6, 0.9, 0.02)
            x: parent.width * 0.4; y: parent.height * 0.3
        }
    }

    // =====================================================
    //  HEADER — glass bar
    // =====================================================
    Rectangle {
        id: header
        width: parent.width; height: Math.round(80 * fs); color: Qt.rgba(0.04, 0.04, 0.07, 0.88); border.color: glassBorder; border.width: 1; z: 20
        visible: cyberLogic.mainUIVisible
        Rectangle { width: parent.width; height: 1; y: 0; color: Qt.rgba(1, 1, 1, 0.08) }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(20 * fs); anchors.rightMargin: Math.round(20 * fs); spacing: Math.round(14 * fs)
            Rectangle { 
                width: Math.round(48 * fs); height: Math.round(48 * fs); radius: 14; color: accentColor
                Image { anchors.centerIn: parent; width: 26; height: 26; source: ic("eye", "#080808"); sourceSize.width: 26; sourceSize.height: 26 }
            }
            ColumnLayout {
                spacing: 2; Layout.fillWidth: true
                Label { text: tr("app_title"); font.pixelSize: Math.round(20 * fs); font.bold: true; color: "white"; wrapMode: Text.WordWrap; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
                Label { text: tr("app_subtitle"); font.pixelSize: Math.round(11 * fs); color: Qt.rgba(1, 1, 1, 0.5); wrapMode: Text.WordWrap; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1; visible: !isCompact }
            }
            // Hide App UI Button
            Button {
                implicitHeight: Math.round(40 * fs); implicitWidth: Math.round(120 * fs)
                onClicked: cyberLogic.mainUIVisible = false
                background: Rectangle { radius: 12; color: accentDim; border.color: accentColor; border.width: 2 }
                contentItem: Label { text: tr("btn_hide_ui"); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                id: langBtn; implicitHeight: Math.round(44 * fs); implicitWidth: isCompact ? Math.round(54 * fs) : Math.round(130 * fs); flat: true
                onClicked: { i18n.toggleLanguage(); cyberLogic.appLanguage = i18n.language; }
                background: Rectangle { radius: 12; color: langBtn.hovered ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04); border.color: glassBorder; border.width: 1 }
                contentItem: RowLayout {
                    spacing: 8
                    Image { source: ic("globe", accentColor); width: 20; height: 20; sourceSize.width: 20; sourceSize.height: 20 }
                    Label { text: tr("lang_toggle"); color: "white"; font.pixelSize: Math.round(13 * fs); font.bold: true; visible: !isCompact }
                }
            }
            Label { text: clockStr; font.pixelSize: Math.round(isCompact ? 18 : 24 * fs); font.family: "Consolas"; color: accentColor }
        }
    }

    // =====================================================
    //  SIDEBAR — glass panel
    // =====================================================
    Rectangle {
        id: sidebar; width: sideW; anchors.top: header.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left
        color: Qt.rgba(0.03, 0.03, 0.06, 0.72); border.color: glassBorder; border.width: 1; z: 15
        visible: cyberLogic.mainUIVisible

        // Glass edge highlight
        Rectangle {
            width: 1; height: parent.height
            x: rtl ? 0 : parent.width - 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Math.round(22 * fs)
            anchors.bottomMargin: Math.round(16 * fs)
            spacing: Math.round(14 * fs)

            Repeater {
                model: navModel
                delegate: Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    property bool sel: cyberLogic.screen === modelData.id

                    Rectangle {
                        width: Math.round((isCompact ? 52 : 66) * fs)
                        height: width
                        radius: Math.round(16 * fs)
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: sel ? accentDim : (navMA.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
                        border.color: sel ? accentColor : (navMA.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                        border.width: sel ? 2.5 : 1

                        Behavior on color { ColorAnimation { duration: animSpeed } }
                        Behavior on border.color { ColorAnimation { duration: animSpeed } }

                        Image {
                            anchors.centerIn: parent
                            width: Math.round(26 * fs); height: width
                            source: ic(modelData.icon, sel || navMA.containsMouse ? accentColor : "#cccccc")
                            sourceSize.width: width; sourceSize.height: height
                        }
                        MouseArea {
                            id: navMA
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cyberLogic.triggerAction(modelData.id)
                        }
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tr(modelData.key)
                        font.pixelSize: Math.round(10 * fs); font.bold: true
                        color: "white"
                        opacity: sel ? 1.0 : 0.5
                        visible: !isCompact
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // =====================================================
    //  MAIN CONTENT
    // =====================================================
    Item {
        id: mainContent; anchors.top: header.bottom; anchors.bottom: parent.bottom; anchors.left: sidebar.right; anchors.right: parent.right; anchors.margins: Math.round(18 * fs); z: 8
        visible: cyberLogic.mainUIVisible

        // =================== DASHBOARD ===================
        Item {
            anchors.fill: parent
            visible: cyberLogic.screen === "dashboard"
            ColumnLayout {
                anchors.fill: parent; spacing: Math.round(16 * fs)
                Label { text: tr("nav_dashboard"); font.pixelSize: Math.round(20 * fs); font.bold: true; color: accentColor }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    columns: gridCols
                    rowSpacing: Math.round(16 * fs); columnSpacing: Math.round(16 * fs)

                    // Camera
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumHeight: Math.round(200 * fs)
                        radius: bdr; color: "#000"
                        border.color: accentColor; border.width: 2
                        clip: true
                        Image {
                            id: camImg
                            anchors.fill: parent; anchors.margins: 3
                            fillMode: Image.PreserveAspectCrop
                            source: "image://camera/feed"; cache: false; asynchronous: true
                            function refresh() { source = "image://camera/feed?" + Math.random(); }
                        }
                        Connections { target: cyberLogic; function onCameraFrameUpdated() { camImg.refresh(); } }
                        // Scan line
                        Rectangle {
                            width: parent.width - 6; height: 2; color: accentColor
                            visible: !cyberLogic.reduceMotion; y: 3
                            SequentialAnimation on y {
                                running: !cyberLogic.reduceMotion && cyberLogic.screen === "dashboard"; loops: Animation.Infinite
                                NumberAnimation { from: 3; to: camImg.height - 6; duration: 2800; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: camImg.height - 6; to: 3; duration: 2800; easing.type: Easing.InOutQuad }
                            }
                        }
                        // Header overlay
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: Math.round(40 * fs); color: Qt.rgba(0,0,0,0.6); radius: bdr
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 8
                                Image { source: ic("camera", accentColor); width: 20; height: 20 }
                                Label { text: tr("dashboard_camera"); color: "white"; font.pixelSize: Math.round(13 * fs); font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 1 }
                            }
                        }
                        Label {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 10
                            text: tr("dashboard_camera_hint"); wrapMode: Text.WordWrap; color: "white"; font.pixelSize: Math.round(11 * fs); opacity: 0.85
                        }
                        // Calibration overlay
                        Rectangle {
                            visible: cyberLogic.calibrationActive
                            anchors.fill: parent; color: Qt.rgba(0,0,0,0.85); z: 60; radius: bdr
                            ColumnLayout {
                                anchors.centerIn: parent; width: parent.width - 40; spacing: 12
                                Label { text: tr("cal_overlay_title"); font.pixelSize: Math.round(17 * fs); font.bold: true; color: accentColor; Layout.alignment: Qt.AlignHCenter }
                                ProgressBar { from: 0; to: 100; value: cyberLogic.calibrationProgress; Layout.fillWidth: true }
                                Label { text: tr("cal_overlay_point").replace("%1", String(Math.min(cyberLogic.calibrationStep+1,6))); color: "white"; font.pixelSize: Math.round(13 * fs); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                        }
                    }

                    // Status
                    GlassCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumHeight: Math.round(200 * fs)
                        content: [
                        ColumnLayout {
                            anchors.fill: parent; spacing: 10
                            IconLabel { iconName: "activity"; labelKey: "dashboard_status" }
                            ColumnLayout {
                                id: pipe; Layout.fillWidth: true; spacing: 8
                                property bool ok: cyberLogic.cameraConnected && !cyberLogic.trackingPaused
                                Label { text: tr("metric_eye"); color: "white"; font.pixelSize: Math.round(12 * fs); font.bold: true; opacity: 0.85 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 8; radius: 4; color: Qt.rgba(1,1,1,0.08)
                                    Rectangle { width: pipe.ok ? parent.width*0.88 : parent.width*0.25; height: parent.height; radius: 4; color: pipe.ok ? accentColor : Qt.rgba(1,1,1,0.2); Behavior on width { NumberAnimation { duration: animSpeed } } }
                                }
                                Label { text: pipe.ok ? tr("metric_ready") : tr("metric_off"); color: pipe.ok ? accentColor : "#888"; font.pixelSize: Math.round(11 * fs) }
                                Label { text: tr("metric_precision"); color: "white"; font.pixelSize: Math.round(12 * fs); font.bold: true; opacity: 0.85 }
                                ProgressBar { from: 0; to: 100; value: cyberLogic.trackingQuality; Layout.fillWidth: true }
                                Label { text: cyberLogic.trackingQuality + " %"; color: accentColor; font.pixelSize: Math.round(11 * fs) }
                                Label { text: tr("metric_stability"); color: "white"; font.pixelSize: Math.round(12 * fs); font.bold: true; opacity: 0.85 }
                                ProgressBar { from: 0; to: 100; value: cyberLogic.stabilityScore; Layout.fillWidth: true }
                                Label { text: cyberLogic.stabilityScore + " %"; color: accentColor; font.pixelSize: Math.round(11 * fs) }
                            }
                        } ]
                    }

                    // Quick actions
                    GlassCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumHeight: Math.round(200 * fs)
                        content: [
                        ColumnLayout {
                            anchors.fill: parent; spacing: 10
                            IconLabel { iconName: "hand"; labelKey: "dashboard_quick" }
                            GridLayout {
                                Layout.fillWidth: true; columns: 2; rowSpacing: 10; columnSpacing: 10
                                Repeater {
                                    model: [
                                        { key: "action_calibrate", icon: "crosshair", act: "cal" },
                                        { key: "action_dwell",     icon: "dwell_dots", act: "dwell" }
                                    ]
                                    delegate: Button {
                                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(50 * fs); flat: true
                                        background: Rectangle { radius: 12; color: parent.pressed ? Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.3) : Qt.rgba(1,1,1,0.05); border.color: accentColor; border.width: 2 }
                                        contentItem: RowLayout {
                                            spacing: 8
                                            Image { source: ic(modelData.icon, accentColor); width: 20; height: 20 }
                                            Label { text: tr(modelData.key); color: "white"; font.pixelSize: Math.round(12 * fs); font.bold: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                        }
                                        onClicked: {
                                            if (modelData.act === "cal") { cyberLogic.notify(tr("notif_cal_started"),"info"); cyberLogic.startCalibration(); }
                                            else cyberLogic.notify(tr("notif_dwell_test"),"info");
                                        }
                                    }
                                }
                                Button {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(50 * fs); Layout.columnSpan: 2; flat: true
                                    property bool paused: cyberLogic.trackingPaused
                                    background: Rectangle { radius: 12; color: parent.pressed ? Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.3) : Qt.rgba(1,1,1,0.05); border.color: accentColor; border.width: 2 }
                                    contentItem: RowLayout {
                                        spacing: 8
                                        Image { source: ic(parent.parent.paused ? "play" : "pause", accentColor); width: 20; height: 20 }
                                        Label { text: parent.parent.paused ? tr("action_resume") : tr("action_pause"); color: "white"; font.pixelSize: Math.round(12 * fs); font.bold: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    }
                                    onClicked: cyberLogic.toggleTrackingPause()
                                }
                            }
                        } ]
                    }

                    // Help
                    GlassCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumHeight: Math.round(200 * fs)
                        content: [
                        ColumnLayout {
                            anchors.fill: parent; spacing: 8
                            IconLabel { iconName: "book"; labelKey: "dashboard_help" }
                            Repeater {
                                model: ["help_1","help_2","help_3"]
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Label { text: "•"; color: accentColor; font.pixelSize: Math.round(14 * fs) }
                                    Label { text: tr(modelData); color: "#e8e8e8"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                            }
                        } ]
                    }
                }
            }
        }

        // =================== KEYBOARD ===================
        Item {
            anchors.fill: parent
            visible: cyberLogic.screen === "keyboard"
            ColumnLayout {
                anchors.fill: parent; spacing: Math.round(14 * fs)
                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Label { text: tr("keyboard_screen_title"); font.pixelSize: Math.round(20 * fs); font.bold: true; color: accentColor }
                        Label { text: tr("keyboard_screen_hint"); font.pixelSize: Math.round(11 * fs); color: "#bbb"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{ code: "en", key: "keyboard_layout_en" }, { code: "ar", key: "keyboard_layout_ar" }]
                            delegate: Button {
                                implicitHeight: Math.round(42 * fs); implicitWidth: Math.round(100 * fs); flat: true
                                background: Rectangle { radius: 10; color: cyberLogic.keyboardLayout === modelData.code ? accentDim : panelColor; border.color: accentColor; border.width: 2 }
                                contentItem: Label { text: tr(modelData.key); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: "white"; font.bold: true; font.pixelSize: Math.round(12 * fs) }
                                onClicked: cyberLogic.keyboardLayout = modelData.code
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; height: Math.round(90 * fs)
                    radius: bdr; color: glassSurface; border.color: accentColor; border.width: 2
                    ScrollView {
                        anchors.fill: parent; anchors.margins: 10; clip: true
                        Label { text: cyberLogic.keyboardText.length ? cyberLogic.keyboardText : "…"; color: "white"; font.pixelSize: Math.round(24 * fs); font.bold: true; wrapMode: Text.Wrap; width: parent.width }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    columns: cyberLogic.keyboardLayout === "en" ? 10 : 11
                    rowSpacing: Math.round(8 * fs); columnSpacing: Math.round(8 * fs)
                    Repeater {
                        model: cyberLogic.keyboardLayout === "en"
                               ? ["Q","W","E","R","T","Y","U","I","O","P","A","S","D","F","G","H","J","K","L","Z","X","C","V","B","N","M","1","2","3","4","5","6","7","8","9","0","SPACE","BACK","CLEAR"]
                               : ["ض","ص","ث","ق","ف","غ","ع","ه","خ","ح","ج","ش","س","ي","ب","ل","ا","ت","ن","م","ك","ط","ئ","ء","ؤ","ر","ى","ة","و","ز","ظ","ذ","د","1","2","3","4","5","6","7","8","9","0","SPACE","BACK","CLEAR"]
                        delegate: Button {
                            id: kb
                            implicitWidth: Math.round((cyberLogic.keyboardLayout === "en" ? 68 : 58) * fs)
                            implicitHeight: Math.round(56 * fs); flat: true
                            background: Rectangle { radius: 10; color: kb.pressed ? Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.3) : Qt.rgba(1,1,1,0.06); border.color: accentColor; border.width: 1.5 }
                            contentItem: Label {
                                text: modelData === "SPACE" ? tr("key_space") : (modelData === "CLEAR" ? tr("key_clear") : (modelData === "BACK" ? tr("key_back") : modelData))
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                color: "white"; font.bold: true
                                font.pixelSize: Math.round((modelData.length > 3 ? 10 : 14) * fs)
                                wrapMode: Text.WordWrap
                            }
                            onClicked: {
                                if (modelData === "SPACE") cyberLogic.addKeyboardChar(" ");
                                else if (modelData === "CLEAR") cyberLogic.clearKeyboard();
                                else if (modelData === "BACK") cyberLogic.backspaceKeyboard();
                                else cyberLogic.addKeyboardChar(modelData);
                            }
                        }
                    }
                }
            }
        }

        // =================== TRACKING ===================
        Item {
            anchors.fill: parent
            visible: cyberLogic.screen === "tracking"
            ScrollView {
                anchors.fill: parent; clip: true
                ColumnLayout {
                    width: mainContent.width - 8; spacing: Math.round(16 * fs)
                    Label { text: tr("tracking_screen_title"); font.pixelSize: Math.round(22 * fs); font.bold: true; color: accentColor }
                    Label { text: tr("tracking_screen_subtitle"); font.pixelSize: Math.round(12 * fs); color: "#bbb"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: gridCols; columnSpacing: Math.round(16 * fs); rowSpacing: Math.round(16 * fs)
                        GlassCard {
                            Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                            content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                Label { text: tr("tracking_quality_label"); color: "white"; font.bold: true; font.pixelSize: Math.round(13 * fs) }
                                ProgressBar { from: 0; to: 100; value: cyberLogic.trackingQuality; Layout.fillWidth: true }
                                Label { text: cyberLogic.trackingQuality + " %"; color: accentColor; font.pixelSize: Math.round(26 * fs); font.bold: true }
                            } ]
                        }
                        GlassCard {
                            Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                            content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                Label { text: tr("tracking_stability_label"); color: "white"; font.bold: true; font.pixelSize: Math.round(13 * fs) }
                                ProgressBar { from: 0; to: 100; value: cyberLogic.stabilityScore; Layout.fillWidth: true }
                                Label { text: cyberLogic.stabilityScore + " %"; color: accentColor; font.pixelSize: Math.round(26 * fs); font.bold: true }
                            } ]
                        }
                    }
                    GlassCard {
                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(72 * fs)
                        content: [ RowLayout { anchors.fill: parent; spacing: 12
                            Image { source: ic("camera", accentColor); width: 28; height: 28 }
                            ColumnLayout { spacing: 2; Layout.fillWidth: true
                                Label { text: tr("tracking_camera_label"); color: "white"; font.bold: true; font.pixelSize: Math.round(13 * fs) }
                                Label { text: cyberLogic.cameraConnected ? tr("metric_ready") : tr("metric_off"); color: cyberLogic.cameraConnected ? accentColor : "#888"; font.pixelSize: Math.round(12 * fs) }
                            }
                        } ]
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: Math.round(16 * fs)
                        Label { text: tr("tracking_dwell_label") + ": " + cyberLogic.dwellTimeMs + " ms"; color: "#ddd"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Label { text: tr("tracking_speed_label") + ": " + cyberLogic.cursorSpeed + " %"; color: "#ddd"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                    Button {
                        id: tCalBtn; Layout.fillWidth: true; implicitHeight: Math.round(50 * fs); flat: true
                        background: Rectangle { radius: 12; color: tCalBtn.pressed ? Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.35) : accentDim; border.color: accentColor; border.width: 2 }
                        contentItem: RowLayout {
                            spacing: 10
                            Image { source: ic("crosshair", accentColor); width: 22; height: 22 }
                            Label { text: tr("tracking_recalibrate"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                        }
                        onClicked: { cyberLogic.notify(tr("notif_cal_started"),"info"); cyberLogic.startCalibration(); }
                    }
                    GlassCard {
                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(60 * fs)
                        content: [ Label { anchors.fill: parent; text: tr("tracking_hint"); color: "#ccc"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap } ]
                    }
                }
            }
        }

        // =================== INFO ===================
        Item {
            anchors.fill: parent
            visible: cyberLogic.screen === "info"
            ScrollView {
                anchors.fill: parent; clip: true
                ColumnLayout {
                    width: mainContent.width - 8; spacing: Math.round(16 * fs)
                    Label { text: tr("info_title"); font.pixelSize: Math.round(22 * fs); font.bold: true; color: accentColor }
                    Repeater {
                        model: [
                            { icon: "eye",        title: "info_welcome",      body: "info_welcome_body" },
                            { icon: "target",     title: "info_how_tracking", body: "info_how_tracking_body" },
                            { icon: "dwell_dots", title: "info_dwell_title",  body: "info_dwell_body" }
                        ]
                        delegate: GlassCard {
                            Layout.fillWidth: true
                            Layout.minimumHeight: Math.round(100 * fs)
                            content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                IconLabel { iconName: modelData.icon; labelKey: modelData.title }
                                Label { text: tr(modelData.body); color: "#ddd"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            } ]
                        }
                    }
                    GlassCard {
                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                        content: [ ColumnLayout { anchors.fill: parent; spacing: 6
                            IconLabel { iconName: "crosshair"; labelKey: "info_calibration" }
                            Repeater {
                                model: ["info_cal_step1","info_cal_step2","info_cal_step3","info_cal_step4","info_cal_step5","info_cal_step6"]
                                delegate: Label { text: tr(modelData); color: "#ccc"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                        } ]
                    }
                    GlassCard {
                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(120 * fs)
                        content: [ ColumnLayout { anchors.fill: parent; spacing: 6
                            IconLabel { iconName: "sparkles"; labelKey: "info_features_title" }
                            Repeater {
                                model: ["info_feature_1","info_feature_2","info_feature_3","info_feature_4","info_feature_5","info_feature_6"]
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Label { text: "★"; color: accentColor; font.pixelSize: Math.round(13 * fs) }
                                    Label { text: tr(modelData); color: "#ddd"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                            }
                        } ]
                    }
                    GlassCard {
                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(100 * fs)
                        content: [ ColumnLayout { anchors.fill: parent; spacing: 6
                            IconLabel { iconName: "help_circle"; labelKey: "info_tips_title" }
                            Repeater {
                                model: ["info_tip_1","info_tip_2","info_tip_3","info_tip_4"]
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Label { text: "→"; color: accentColor; font.pixelSize: Math.round(13 * fs) }
                                    Label { text: tr(modelData); color: "#ddd"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                            }
                        } ]
                    }
                }
            }
        }

        // =================== SETTINGS ===================
        Item {
            anchors.fill: parent
            visible: cyberLogic.screen === "settings"
            onVisibleChanged: { if (visible) cyberLogic.beginSettingsEdit(cyberLogic.settingsTab); }
            ColumnLayout {
                anchors.fill: parent; spacing: Math.round(12 * fs)
                Label { text: tr("settings_title"); font.pixelSize: Math.round(22 * fs); font.bold: true; color: accentColor }

                // Tab bar
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [
                            { id: "motion", key: "tab_motion", icon: "gauge" },
                            { id: "click",  key: "tab_click",  icon: "hand" },
                            { id: "system", key: "tab_system", icon: "cpu" },
                            { id: "appearance", key: "tab_appearance", icon: "sliders" },
                            { id: "floating", key: "tab_floating", icon: "grid" }
                        ]
                        delegate: Button {
                            Layout.fillWidth: true; Layout.minimumHeight: Math.round(44 * fs); flat: true
                            property bool active: cyberLogic.settingsTab === modelData.id
                            background: Rectangle {
                                radius: 12
                                color: active ? accentDim : Qt.rgba(1,1,1,0.03)
                                border.color: active ? accentColor : glassBorder
                                border.width: active ? 2 : 1
                                Behavior on color { ColorAnimation { duration: animSpeed } }
                            }
                            contentItem: RowLayout {
                                spacing: 4
                                Image { source: ic(modelData.icon, accentColor); width: 16; height: 16; sourceSize.width: 16; sourceSize.height: 16 }
                                Label {
                                    text: tr(modelData.key); color: "white"; font.bold: true
                                    font.pixelSize: Math.round((isCompact ? 9 : 11) * fs)
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    elide: Text.ElideRight; maximumLineCount: 1
                                }
                            }
                            onClicked: { cyberLogic.settingsTab = modelData.id; cyberLogic.beginSettingsEdit(modelData.id); }
                        }
                    }
                }

                // Settings content
                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ColumnLayout {
                        width: mainContent.width - 20; spacing: Math.round(16 * fs)

                        // === MOTION ===
                        ColumnLayout {
                            visible: cyberLogic.settingsTab === "motion"; Layout.fillWidth: true; spacing: 14
                            Label { text: tr("motion_panel_title"); color: accentColor; font.bold: true; font.pixelSize: Math.round(16 * fs) }
                            GridLayout {
                                Layout.fillWidth: true; columns: gridCols; columnSpacing: 14; rowSpacing: 14
                                SliderCard { label: tr("motion_horiz"); val: cyberLogic.motionHorizontal; lo: 5; hi: 100; onMoved: function(v) { cyberLogic.motionHorizontal = v } }
                                SliderCard { label: tr("motion_vert"); val: cyberLogic.motionVertical; lo: 5; hi: 100; onMoved: function(v) { cyberLogic.motionVertical = v } }
                                SliderCard { label: tr("motion_accel"); val: cyberLogic.motionAcceleration; lo: 10; hi: 100; onMoved: function(v) { cyberLogic.motionAcceleration = v } }
                                SliderCard { label: tr("motion_smooth"); val: cyberLogic.motionSmoothness; lo: 0; hi: 100; onMoved: function(v) { cyberLogic.motionSmoothness = v } }
                                SliderCard { label: tr("motion_thresh"); val: cyberLogic.motionThreshold; lo: 0; hi: 100; Layout.columnSpan: gridCols; onMoved: function(v) { cyberLogic.motionThreshold = v } }
                            }
                            ActionBar { group: "motion" }
                        }

                        // === CLICK ===
                        ColumnLayout {
                            visible: cyberLogic.settingsTab === "click"; Layout.fillWidth: true; spacing: 14
                            Label { text: tr("click_panel_title"); color: accentColor; font.bold: true; font.pixelSize: Math.round(16 * fs) }
                            GridLayout {
                                Layout.fillWidth: true; columns: gridCols; columnSpacing: 14; rowSpacing: 14
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(150 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 10
                                        RowLayout { Layout.fillWidth: true
                                            Label { text: tr("click_dwell_enable"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                            Switch { checked: cyberLogic.dwellClickEnabled; onToggled: cyberLogic.dwellClickEnabled = checked }
                                        }
                                        RowLayout { Layout.fillWidth: true
                                            Label { text: tr("click_dwell_ms"); color: "white"; font.pixelSize: Math.round(12 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap; opacity: cyberLogic.dwellClickEnabled ? 1 : 0.35 }
                                            Label { text: cyberLogic.dwellTimeMs + " ms"; color: accentColor; font.bold: true; opacity: cyberLogic.dwellClickEnabled ? 1 : 0.35 }
                                        }
                                        Slider { enabled: cyberLogic.dwellClickEnabled; from: 400; to: 2200; stepSize: 50; value: cyberLogic.dwellTimeMs; onMoved: cyberLogic.dwellTimeMs = Math.round(value); Layout.fillWidth: true }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(150 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 10
                                        Label { text: tr("click_panel_title"); color: accentColor; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                                        RowLayout { Layout.fillWidth: true
                                            Label { text: tr("click_blink_left"); color: "white"; font.pixelSize: Math.round(12 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                            Switch { checked: cyberLogic.blinkLeftClickEnabled; onToggled: cyberLogic.blinkLeftClickEnabled = checked }
                                        }
                                        RowLayout { Layout.fillWidth: true
                                            Label { text: tr("click_blink_right"); color: "white"; font.pixelSize: Math.round(12 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                            Switch { checked: cyberLogic.blinkRightClickEnabled; onToggled: cyberLogic.blinkRightClickEnabled = checked }
                                        }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(80 * fs)
                                    content: [ RowLayout { anchors.fill: parent
                                        Label { text: tr("click_sound"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                        Switch { checked: cyberLogic.clickSoundEnabled; onToggled: cyberLogic.clickSoundEnabled = checked }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(80 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                        Label { text: tr("click_hud_title"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                                        RowLayout { Layout.fillWidth: true; spacing: 8
                                            Repeater {
                                                model: [{ v: "normal", k: "click_hud_normal" }, { v: "slim", k: "click_hud_slim" }]
                                                delegate: Button {
                                                    Layout.fillWidth: true; implicitHeight: Math.round(40 * fs)
                                                    onClicked: cyberLogic.clickHudStyle = modelData.v
                                                    background: Rectangle { radius: 10; color: cyberLogic.clickHudStyle === modelData.v ? accentDim : panelColor; border.color: accentColor; border.width: 2 }
                                                    contentItem: Label { text: tr(modelData.k); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                }
                                            }
                                        }
                                    } ]
                                }
                            }
                            ActionBar { group: "click" }
                        }

                        // === SYSTEM ===
                        ColumnLayout {
                            visible: cyberLogic.settingsTab === "system"; Layout.fillWidth: true; spacing: 14
                            Label { text: tr("sys_panel_title"); color: accentColor; font.bold: true; font.pixelSize: Math.round(16 * fs) }
                            GridLayout {
                                Layout.fillWidth: true; columns: gridCols; columnSpacing: 14; rowSpacing: 14
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 10
                                        Label { text: tr("sys_icon_refresh"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs); wrapMode: Text.WordWrap }
                                        Label { text: tr("sys_icon_hint"); color: "#aaa"; font.pixelSize: Math.round(11 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                        Button {
                                            Layout.fillWidth: true; implicitHeight: Math.round(42 * fs)
                                            onClicked: { cyberLogic.refreshWindowsIcons(); cyberLogic.notify(tr("notif_icons_refreshed"),"info"); }
                                            background: Rectangle { radius: 12; color: parent.pressed ? Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.3) : accentDim; border.color: accentColor; border.width: 2 }
                                            contentItem: Label { text: tr("sys_icon_refresh"); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap }
                                        }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 10
                                        RowLayout { Layout.fillWidth: true
                                            Label { text: tr("sys_autostart"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                            Switch { checked: cyberLogic.autoStartOnBoot; onToggled: cyberLogic.autoStartOnBoot = checked }
                                        }
                                        Label { text: tr("about_version") + " 2.6"; color: accentColor; font.pixelSize: Math.round(13 * fs); font.bold: true }
                                        Label { text: tr("about_body"); color: "#bbb"; font.pixelSize: Math.round(11 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    } ]
                                }
                            }
                            ActionBar { group: "system" }
                        }

                        // === APPEARANCE ===
                        ColumnLayout {
                            visible: cyberLogic.settingsTab === "appearance"; Layout.fillWidth: true; spacing: 14
                            Label { text: tr("appearance_panel_title"); color: accentColor; font.bold: true; font.pixelSize: Math.round(16 * fs) }
                            GridLayout {
                                Layout.fillWidth: true; columns: gridCols; columnSpacing: 14; rowSpacing: 14
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(120 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                        Label { text: tr("theme_label"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                                        Flow { spacing: 8; Layout.fillWidth: true
                                            Repeater {
                                                model: [{ v:"cyber",k:"theme_cyber" },{ v:"soft",k:"theme_soft" },{ v:"contrast",k:"theme_contrast" }]
                                                delegate: Button {
                                                    implicitHeight: Math.round(38 * fs); implicitWidth: Math.round(88 * fs)
                                                    onClicked: cyberLogic.themeId = modelData.v
                                                    background: Rectangle { radius: 10; color: cyberLogic.themeId === modelData.v ? accentDim : panelColor; border.color: accentColor; border.width: 2 }
                                                    contentItem: Label { text: tr(modelData.k); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: Math.round(11 * fs) }
                                                }
                                            }
                                        }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(120 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                        Label { text: tr("set_language"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                                        Flow { spacing: 8; Layout.fillWidth: true
                                            Repeater {
                                                model: [{ code:"en", label:"English" },{ code:"ar", label:"العربية" }]
                                                delegate: Button {
                                                    implicitHeight: Math.round(40 * fs); implicitWidth: Math.round(100 * fs)
                                                    onClicked: { i18n.setLanguage(modelData.code); cyberLogic.appLanguage = modelData.code; }
                                                    background: Rectangle { radius: 10; color: i18n.language === modelData.code ? accentDim : panelColor; border.color: accentColor; border.width: 2 }
                                                    contentItem: Label { text: modelData.label; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                }
                                            }
                                        }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 10
                                        Repeater {
                                            model: [
                                                { k: "dark_mode", on: cyberLogic.darkMode },
                                                { k: "motion_effects", on: !cyberLogic.reduceMotion },
                                                { k: "set_high_contrast", on: cyberLogic.highContrast }
                                            ]
                                            delegate: RowLayout { Layout.fillWidth: true
                                                Label { text: tr(modelData.k); color: "white"; font.pixelSize: Math.round(13 * fs); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                                Switch {
                                                    checked: modelData.on
                                                    onToggled: {
                                                        if (modelData.k === "dark_mode") cyberLogic.darkMode = checked;
                                                        else if (modelData.k === "motion_effects") cyberLogic.reduceMotion = !checked;
                                                        else cyberLogic.highContrast = checked;
                                                    }
                                                }
                                            }
                                        }
                                    } ]
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(140 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                        Label { text: tr("set_text_size"); color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                                        Flow { spacing: 8; Layout.fillWidth: true
                                            Repeater {
                                                model: [{ k:"size_normal",v:1.0 },{ k:"size_large",v:1.2 },{ k:"size_xlarge",v:1.4 }]
                                                delegate: Button {
                                                    implicitHeight: Math.round(40 * fs); implicitWidth: Math.round(90 * fs)
                                                    onClicked: cyberLogic.fontScale = modelData.v
                                                    background: Rectangle { radius: 10; color: Math.abs(cyberLogic.fontScale - modelData.v) < 0.05 ? accentDim : panelColor; border.color: accentColor; border.width: 2 }
                                                    contentItem: Label { text: tr(modelData.k); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: Math.round(11 * fs) }
                                                }
                                            }
                                        }
                                    } ]
                                }
                            }
                            ActionBar { group: "appearance" }
                        }

                        // === FLOATING ===
                        ColumnLayout {
                            visible: cyberLogic.settingsTab === "floating"; Layout.fillWidth: true; spacing: 14
                            Label { text: tr("float_panel_title"); color: accentColor; font.bold: true; font.pixelSize: Math.round(16 * fs) }
                            Label { text: tr("float_intro"); color: "#ccc"; font.pixelSize: Math.round(11 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            GridLayout {
                                Layout.fillWidth: true; columns: gridCols; columnSpacing: 14; rowSpacing: 14
                                Repeater {
                                    model: cyberLogic.floatingActionsModel
                                    delegate: GlassCard {
                                        Layout.fillWidth: true; Layout.minimumHeight: Math.round(64 * fs)
                                        content: [ RowLayout { anchors.fill: parent
                                            Label { text: floatActLabel(modelData.id); color: "white"; font.pixelSize: Math.round(13 * fs); font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                            Switch { checked: modelData.enabled; onToggled: cyberLogic.setFloatingActionEnabled(modelData.id, checked) }
                                        } ]
                                    }
                                }
                                GlassCard {
                                    Layout.fillWidth: true; Layout.minimumHeight: Math.round(80 * fs)
                                    content: [ ColumnLayout { anchors.fill: parent; spacing: 8
                                        Label { text: tr("fab_panel_global_title") ; color: "white"; font.bold: true; font.pixelSize: Math.round(14 * fs) }
                                        Button {
                                            Layout.fillWidth: true; implicitHeight: Math.round(42 * fs)
                                            onClicked: cyberLogic.fabEnabled = !cyberLogic.fabEnabled
                                            background: Rectangle { radius: 12; color: accentDim; border.color: accentColor; border.width: 2 }
                                            contentItem: Label { text: cyberLogic.fabEnabled ? tr("fab_visibility_toggle_off") : tr("fab_visibility_toggle_on"); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                    } ]
                                }
                            }
                            ActionBar { group: "floating" }
                        }
                    }
                }
            }
        }
    }

    // =====================================================
    //  NOTIFICATIONS
    // =====================================================
    Column {
        anchors.top: header.bottom
        anchors.right: parent.right
        anchors.margins: 14; spacing: 8; z: 120
        width: Math.min(340, parent.width * 0.35)
        Repeater {
            model: cyberLogic.notifications
            delegate: Rectangle {
                width: parent.width; height: Math.round(50 * fs); radius: 12
                color: glassSurface
                border.color: modelData.type === "error" ? "#ff4444" : accentColor; border.width: 2
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Image { source: ic("bell", accentColor); width: 20; height: 20 }
                    Label { text: modelData.message; color: "white"; font.pixelSize: Math.round(12 * fs); wrapMode: Text.WordWrap; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2 }
                }
            }
        }
    }

    // =====================================================
    //  MAGNIFIER
    // =====================================================
    Rectangle {
        visible: isMagnifierActive
        width: Math.round(200 * fs); height: Math.round(200 * fs)
        radius: width / 2; color: "transparent"
        border.color: "white"; border.width: 3; z: 2000
        x: Math.min(Math.max(8, hT.mouseX - width/2), window.width - width - 8)
        y: Math.min(Math.max(header.height + 8, hT.mouseY - height/2), window.height - height - 8)
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(1,1,1,0.1); border.color: accentColor; border.width: 2 }
        Label { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 10; text: tr("mag_overlay"); color: "white"; font.pixelSize: Math.round(10 * fs); font.bold: true; opacity: 0.7 }
    }

    // =====================================================
    //  GAZE TRAIL
    // =====================================================
    Rectangle {
        width: Math.round(44 * fs); height: width
        radius: width / 2; color: "transparent"
        border.color: Qt.rgba(accentColor.r,accentColor.g,accentColor.b,0.5); border.width: 2.5; z: 1000
        x: hT.mouseX - width/2; y: hT.mouseY - height/2
        visible: !cyberLogic.trackingPaused
        Rectangle {
            anchors.centerIn: parent; width: Math.round(10 * fs); height: width
            radius: width / 2; color: accentColor
            SequentialAnimation on opacity {
                running: !cyberLogic.reduceMotion; loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.3; duration: 700 }
                NumberAnimation { from: 0.3; to: 1; duration: 700 }
            }
        }
    }

    MouseArea {
        id: hT; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
        propagateComposedEvents: true; z: 4000
        onPressed: function(m) { m.accepted = false }
        onReleased: function(m) { m.accepted = false }
        onClicked: function(m) { m.accepted = false }
        onDoubleClicked: function(m) { m.accepted = false }
    }

    // =====================================================
    //  GLOBAL FLOATING ACTION WINDOW
    // =====================================================
    Window {
        id: fabWin
        visible: cyberLogic.fabEnabled
        width: fab.fabOpen ? fab.orbR2 * 2 + 100 : Math.round(80 * fs)
        height: width
        x: fab.posX - width / 2; y: fab.posY - height / 2
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.ToolTip
        transientParent: null

        Item {
            id: fab; anchors.fill: parent
            property bool fabOpen: false
            property int hovIdx: -1
            property bool dragging: false
            
            // Screen relative position (stored globally)
            property real posX: Screen.desktopAvailableWidth - 100
            property real posY: Screen.desktopAvailableHeight - 150
            property real orbR: Math.round(150 * fs)
            property real orbR2: Math.round(230 * fs)

            // Center in window
            property real cx: width / 2
            property real cy: height / 2

            property var items: [
                { label: "fab_click", icon: "pointer_click", sub: [
                    { label: "fab_single_click", icon: "pointer_click", action: "click" },
                    { label: "fab_double_click", icon: "pointer_click", action: "doubleclick" },
                    { label: "fab_left_click", icon: "mouse_pointer", action: "left_click" },
                    { label: "fab_right_click", icon: "mouse_pointer", action: "right_click" },
                    { label: "fab_drag", icon: "drag", action: "drag" },
                    { label: "fab_drop", icon: "download", action: "drop" }
                ]},
                { label: "fab_magnifier", icon: "search", sub: [], action: "magnifier" },
                { label: "fab_keyboard", icon: "keyboard", sub: [], action: "keyboard" },
                { label: "fab_settings", icon: "settings", sub: [], action: "settings" },
                { label: "fab_screenshot", icon: "screenshot", sub: [
                    { label: "fab_screenshot_image", icon: "image", action: "screenshot_image" },
                    { label: "fab_screenshot_video", icon: "video", action: "screenshot_video" }
                ]},
                { label: "fab_scroll", icon: "scroll", sub: [
                    { label: "fab_scroll_left", icon: "chevron_left", action: "scroll_left" },
                    { label: "fab_scroll_right", icon: "chevron_right", action: "scroll_right" },
                    { label: "fab_scroll_up", icon: "chevron_up", action: "scroll_up" },
                    { label: "fab_scroll_down", icon: "chevron_down", action: "scroll_down" }
                ]}
            ]

            Rectangle {
                anchors.fill: parent; radius: parent.width/2
                color: Qt.rgba(0,0,0,0.6); visible: fab.fabOpen
                border.color: accentColor; border.width: 1; opacity: 0.4
            }
            
            // Restore UI button (visible only when FAB is closed and UI is hidden)
            Rectangle {
                width: 32; height: 32; radius: 16; color: accentDim; border.color: accentColor
                anchors.right: fabBtn.left; anchors.rightMargin: 10; anchors.verticalCenter: fabBtn.verticalCenter
                visible: !fab.fabOpen && !cyberLogic.mainUIVisible
                Image { anchors.centerIn: parent; width: 18; height: 18; source: ic("eye", "#fff"); sourceSize.width: 18; sourceSize.height: 18 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cyberLogic.mainUIVisible = true }
            }

            // Orbit Rings
            Rectangle {
                width: fab.orbR * 2; height: width; radius: width / 2; x: fab.cx - fab.orbR; y: fab.cy - fab.orbR
                color: "transparent"; border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3); border.width: 1.5
                visible: fab.fabOpen; opacity: fab.fabOpen ? 1 : 0; scale: fab.fabOpen ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: 400 } }
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
            }
            Rectangle {
                width: fab.orbR2 * 2; height: width; radius: width / 2; x: fab.cx - fab.orbR2; y: fab.cy - fab.orbR2
                color: "transparent"; border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15); border.width: 1
                visible: fab.fabOpen; opacity: fab.fabOpen ? 1 : 0; scale: fab.fabOpen ? 1 : 0.9
                Behavior on opacity { NumberAnimation { duration: 600 } }
                Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
            }

            // Radial items Repeater
            Repeater {
                model: fab.items
                delegate: Item {
                    id: fd
                    property int idx: index
                    property var itm: modelData
                    property real ang: -Math.PI + (Math.PI * index / 5)
                    property real tx: fab.cx + fab.orbR * Math.cos(ang)
                    property real ty: fab.cy + fab.orbR * Math.sin(ang)
                    
                    visible: fab.fabOpen
                    x: tx - 32; y: ty - 32; width: 64; height: 64; z: 5000

                    Rectangle {
                        id: fBg; anchors.fill: parent; radius: 32
                        color: fab.hovIdx === index ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.5) : Qt.rgba(0.04, 0.05, 0.1, 0.88)
                        border.color: fab.hovIdx === index ? "#fff" : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.4)
                        border.width: fab.hovIdx === index ? 2.5 : 1.2
                        scale: fab.fabOpen ? 1 : 0.4; opacity: fab.fabOpen ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: animSpeed; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Image {
                            anchors.centerIn: parent; width: 32; height: 32
                            source: ic(fd.itm.icon, "#fff")
                            sourceSize.width: 32; sourceSize.height: 32
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: fab.hovIdx = fd.idx
                            onExited: function() { if (fd.itm.sub.length === 0) fab.hovIdx = -1; }
                            onClicked: {
                                if (fd.itm.sub && fd.itm.sub.length === 0) {
                                    cyberLogic.triggerAction(fd.itm.action);
                                    fab.fabOpen = false; fab.hovIdx = -1;
                                } else {
                                    fab.hovIdx = (fab.hovIdx === fd.idx) ? -1 : fd.idx;
                                }
                            }
                        }
                    }
                    // Label
                    Rectangle {
                        visible: fab.fabOpen; anchors.horizontalCenter: fBg.horizontalCenter; y: -26
                        width: fL.implicitWidth + 14; height: 22; radius: 6; color: Qt.rgba(0,0,0,0.9); z: 5001
                        Label { id: fL; anchors.centerIn: parent; text: tr(fd.itm.label); color: "white"; font.pixelSize: 11; font.bold: true }
                    }

                    // Sub-items
                    Repeater {
                        model: fd.itm.sub
                        delegate: Item {
                            id: smRoot
                            property var sd: modelData
                            property real subAng: {
                                var c = fd.itm.sub.length; var spread = Math.PI * 0.65; var b = fd.ang;
                                return c <= 1 ? b : b - spread/2 + spread * index / (c-1);
                            }
                            property real gx: fab.cx + fab.orbR2 * Math.cos(subAng)
                            property real gy: fab.cy + fab.orbR2 * Math.sin(subAng)
                            
                            visible: fab.hovIdx === fd.idx; x: gx - fd.x - 27; y: gy - fd.y - 27; width: 54; height: 54

                            Rectangle {
                                anchors.fill: parent; radius: 27
                                color: sm.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.5) : Qt.rgba(0, 0, 0, 0.9)
                                border.color: sm.containsMouse ? "#fff" : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.4)
                                border.width: sm.containsMouse ? 2.5 : 1
                                scale: fab.hovIdx === fd.idx ? 1 : 0.3
                                opacity: fab.hovIdx === fd.idx ? 1 : 0
                                Image { anchors.centerIn: parent; width: 24; height: 24; source: ic(smRoot.sd.icon, "#fff"); sourceSize.width: 24; sourceSize.height: 24 }
                                MouseArea {
                                    id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { cyberLogic.triggerAction(smRoot.sd.action); fab.fabOpen = false; fab.hovIdx = -1; }
                                }
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter; y: -18
                                width: sl.implicitWidth + 12; height: 18; radius: 5; color: Qt.rgba(0,0,0,0.9); visible: sm.containsMouse
                                Label { id: sl; anchors.centerIn: parent; text: tr(smRoot.sd.label); color: "white"; font.pixelSize: 10; font.bold: true }
                            }
                        }
                    }
                }
            }

            // Central FAB button
            Rectangle {
                id: fabBtn; width: Math.round(64 * fs); height: width; radius: width / 2
                anchors.centerIn: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: fab.fabOpen ? "#9333EA" : "#7C3AED" }
                    GradientStop { position: 1; color: fab.fabOpen ? "#A855F7" : "#6D28D9" }
                }
                border.width: 2; border.color: Qt.rgba(1,1,1, fab.fabOpen ? 0.35 : 0.2)
                Image {
                    anchors.centerIn: parent; width: 28; height: 28
                    source: ic(fab.fabOpen ? "x" : "plus", "#fff"); sourceSize.width: 28; sourceSize.height: 28
                    rotation: fab.fabOpen ? 45 : 0; Behavior on rotation { NumberAnimation { duration: animSpeed } }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    property point startPos
                    onPressed: function(mouse) { startPos = Qt.point(mouse.x, mouse.y); fab.dragging = false; }
                    onPositionChanged: function(mouse) {
                        var dx = mouse.x - startPos.x; var dy = mouse.y - startPos.y;
                        if (!fab.dragging && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) fab.dragging = true;
                        if (fab.dragging) { fab.posX += dx; fab.posY += dy; }
                    }
                    onReleased: { if (!fab.dragging) fab.fabOpen = !fab.fabOpen; fab.dragging = false; }
                }
            }
        }
    }
}
