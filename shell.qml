// A small, self-contained Quickshell bar for Hyprland.
//
// Installed as the default config: ~/.config/quickshell/shell.qml
// Run it with: qs
//
// A copy of this file, the README and screenshots live in:
//     /tmp/opencode/quickshell-demo
//
// Autostart it from Hyprland (hyprland.lua):
//     hl.on("hyprland.start", function()
//       hl.exec_cmd("qs -d -n")
//     end)
//
// What's here:
//   left   - workspaces (filled = has windows, accent = current, red = urgent)
//   center - focused window title
//   right  - network menu, volume, battery %, date + time
//
// Super+A opens the app launcher: type to filter, Up/Down to pick,
// Enter to launch, Esc or a click outside to close.
//
// Network menu: click the wifi icon. Click an open/known network to connect,
// or type the password for a new secured one. The little switch toggles wifi.
//
// Everything is in one file on purpose, so you can copy/back it up easily.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: bar

    // Flush with the top edge, full width.
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 26
    color: "transparent"

    // ---------------------------------------------------------------- palette
    // Dark grey, monochrome. Change these to taste.
    readonly property color bg: "#2b2b2b"
    readonly property color surface: "#3a3a3a"
    readonly property color text: "#e6e6e6"
    readonly property color subtext: "#a0a0a0"
    readonly property color accent: "#d4d4d4"
    readonly property color red: "#e06c75"
    readonly property color yellow: "#e5c07b"

    readonly property string fontFamily: "CaskaydiaCove Nerd Font"
    readonly property int fontSize: 11

    // Handy for testing the menu: `qs ipc call bar toggleNetworkMenu`
    IpcHandler {
        target: "bar"

        function toggleNetworkMenu(): void {
            launcher.visible = false;
            volumePopup.visible = false;
            networkPopup.visible = !networkPopup.visible;
        }

        function toggleVolumeMenu(): void {
            launcher.visible = false;
            networkPopup.visible = false;
            volumePopup.visible = !volumePopup.visible;
        }

        function toggleLauncher(): void {
            launcher.toggle();
        }
    }

    // ------------------------------------------------------------- networking
    readonly property var wifiDevice: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi)
                return d;
        return null;
    }

    // Connected first, then saved networks, then strongest signal.
    readonly property var wifiNetworks: {
        if (!wifiDevice)
            return [];

        const list = wifiDevice.networks.values.slice();
        list.sort((a, b) => (b.connected - a.connected)
                          || (b.known - a.known)
                          || (b.signalStrength - a.signalStrength));
        return list;
    }

    readonly property var connectedNetwork: {
        for (const n of wifiNetworks)
            if (n.connected)
                return n;
        return null;
    }

    function networkColor() {
        if (!Networking.wifiEnabled)
            return subtext;
        return connectedNetwork ? text : subtext;
    }

    // ---------------------------------------------------------------- audio
    // PwObjectTracker keeps the audio properties updating. Without it the
    // volume would only be read once and never change.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property int volumePercent: audio ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio ? audio.muted : false
    readonly property real maxVolume: 1.5

    function setVolume(v) {
        if (!audio)
            return;
        audio.volume = Math.max(0, Math.min(maxVolume, v));
        if (audio.muted)
            audio.muted = false;
    }

    function volumeIcon() {
        if (muted)
            return "\uF025"; // muted
        if (volumePercent === 0)
            return "\uF026";
        if (volumePercent < 34)
            return "\uF026";
        if (volumePercent < 67)
            return "\uF027";
        return "\uF028";
    }

    // ---------------------------------------------------------------- battery
    // Percentage is 0..1 here. State comes from UPowerDeviceState.
    function batteryIcon() {
        const d = UPower.displayDevice;
        if (!d.isPresent)
            return "";
        if (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge)
            return "\uF0E7"; // bolt
        const p = d.percentage;
        if (p >= 0.9) return "\uF240";
        if (p >= 0.65) return "\uF241";
        if (p >= 0.4) return "\uF242";
        if (p >= 0.15) return "\uF243";
        return "\uF244";
    }

    function batteryColor() {
        const p = UPower.displayDevice.percentage;
        if (p <= 0.15) return red;
        if (p <= 0.3) return yellow;
        return text;
    }

    // ---------------------------------------------------------------- clock
    property var now: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: bar.now = new Date()
    }

    // ---------------------------------------------------------- window title
    function windowTitle() {
        // activeToplevel is the proper API, but it can stay empty on some
        // Hyprland/Quickshell version combos. lastwindowtitle is a good fallback.
        if (Hyprland.activeToplevel && Hyprland.activeToplevel.title)
            return Hyprland.activeToplevel.title;

        const ws = Hyprland.focusedWorkspace;
        if (ws && ws.lastIpcObject && ws.lastIpcObject.lastwindowtitle)
            return ws.lastIpcObject.lastwindowtitle;

        return "";
    }

    // ------------------------------------------------------------- background
    Rectangle {
        anchors.fill: parent
        color: bar.bg
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: bar.surface
    }

    // ------------------------------------------------------------ workspaces
    Row {
        id: workspaceRow

        anchors {
            left: parent.left
            leftMargin: 6
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Repeater {
            model: Hyprland.workspaces

            delegate: Rectangle {
                id: wsPill

                required property HyprlandWorkspace modelData

                readonly property bool occupied: modelData.toplevels
                                                 && modelData.toplevels.values.length > 0

                width: Math.max(18, wsLabel.implicitWidth + 8)
                height: 16
                radius: 4

                color: modelData.urgent ? bar.red
                     : modelData.active ? bar.accent
                     : occupied ? bar.surface
                     : wsMouse.containsMouse ? bar.surface
                     : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    id: wsLabel

                    anchors.centerIn: parent
                    text: wsPill.modelData.name
                    color: wsPill.modelData.active || wsPill.modelData.urgent ? bar.bg : bar.text
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize
                    font.bold: wsPill.modelData.active
                }

                MouseArea {
                    id: wsMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsPill.modelData.id)
                }
            }
        }
    }

    // ---------------------------------------------------------- window title
    Text {
        anchors.centerIn: parent

        width: bar.width * 0.4
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight

        text: bar.windowTitle()
        color: bar.subtext
        font.family: bar.fontFamily
        font.pixelSize: bar.fontSize
    }

    // ------------------------------------------------------------ status area
    Row {
        anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        // --- network ---
        Item {
            id: networkButton

            implicitWidth: networkText.implicitWidth
            implicitHeight: 16

            Text {
                id: networkText

                anchors.centerIn: parent
                text: "\uF1EB" // wifi
                color: networkMouse.containsMouse || networkPopup.visible
                       ? bar.accent : bar.networkColor()
                font.family: bar.fontFamily
                font.pixelSize: 11
            }

            MouseArea {
                id: networkMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    launcher.visible = false;
                    volumePopup.visible = false;
                    networkPopup.visible = !networkPopup.visible;
                }
            }
        }

        // --- volume ---
        Item {
            implicitWidth: volumeText.implicitWidth
            implicitHeight: 16

            Text {
                id: volumeText

                anchors.centerIn: parent
                text: bar.volumeIcon() + "  " + bar.volumePercent + "%"
                color: volumeMouse.containsMouse ? bar.accent : bar.text
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize
            }

            MouseArea {
                id: volumeMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (bar.audio)
                            bar.audio.muted = !bar.audio.muted;
                    } else {
                        launcher.visible = false;
                        networkPopup.visible = false;
                        volumePopup.visible = !volumePopup.visible;
                    }
                }

                onWheel: wheel => {
                    if (!bar.audio)
                        return;
                    const step = 0.02;
                    const delta = wheel.angleDelta.y > 0 ? step : -step;
                    bar.setVolume(bar.audio.volume + delta);
                }
            }
        }

        // --- battery (hidden on desktops without a battery) ---
        Text {
            visible: UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
            text: bar.batteryIcon() + "  " + Math.round(UPower.displayDevice.percentage * 100) + "%"
            color: bar.batteryColor()
            font.family: bar.fontFamily
            font.pixelSize: bar.fontSize
        }

        // --- date + time ---
        Item {
            width: dateText.implicitWidth + 4 + timeText.implicitWidth
            height: timeText.implicitHeight

            Text {
                id: dateText

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                text: Qt.formatDateTime(bar.now, "ddd dd MMM")
                color: bar.subtext
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize - 1
            }

            Text {
                id: timeText

                anchors {
                    left: dateText.right
                    leftMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                text: Qt.formatDateTime(bar.now, "HH:mm")
                color: bar.text
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize + 1
                font.bold: true
            }
        }
    }

    // ---------------------------------------------------------- network menu
    // This is a layer-shell window rather than a PopupWindow on purpose: a
    // layer-shell bar cannot host a keyboard-grabbing xdg_popup, and we need
    // keyboard input for the wifi password field.
    PanelWindow {
        id: networkPopup

        property var pendingNetwork: null

        anchors {
            top: true
            right: true
        }
        margins {
            top: 32
            right: 8
        }
        implicitWidth: 260
        implicitHeight: menuColumn.implicitHeight + 18
        color: "transparent"
        visible: false

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-network-menu"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Hyprland's focus grab closes the menu when you click elsewhere.
        HyprlandFocusGrab {
            active: networkPopup.visible
            windows: [networkPopup]
            onCleared: networkPopup.visible = false
        }

        onVisibleChanged: {
            if (visible) {
                if (bar.wifiDevice)
                    bar.wifiDevice.scannerEnabled = true;
            } else {
                pendingNetwork = null;
                if (bar.wifiDevice)
                    bar.wifiDevice.scannerEnabled = false;
            }
        }

        function isSecured(net) {
            return net.security !== WifiSecurityType.Open
                && net.security !== WifiSecurityType.Owe;
        }

        function selectNetwork(net) {
            if (!net || net.connected)
                return;

            if (!isSecured(net) || net.known) {
                pendingNetwork = null;
                net.connect();
            } else {
                pendingNetwork = net;
                pskInput.text = "";
                pskInput.forceActiveFocus();
            }
        }

        function connectPending() {
            if (!pendingNetwork)
                return;
            pendingNetwork.connectWithPsk(pskInput.text);
            pendingNetwork = null;
            pskInput.text = "";
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: bar.bg
            border.width: 1
            border.color: bar.surface
        }

        Column {
            id: menuColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 6

            // Header: title + wifi on/off switch
            Item {
                width: menuColumn.width
                height: 18

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Network"
                    color: bar.text
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize + 1
                    font.bold: true
                }

                Rectangle {
                    id: wifiSwitch

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: 30
                    height: 18
                    radius: 9
                    color: Networking.wifiEnabled ? bar.accent : bar.surface

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: bar.bg
                        anchors.verticalCenter: parent.verticalCenter
                        x: Networking.wifiEnabled ? parent.width - width - 3 : 3

                        Behavior on x {
                            NumberAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
            }

            // Current connection
            Item {
                width: menuColumn.width
                height: 18
                visible: bar.connectedNetwork !== null

                Row {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uF00C"
                        color: bar.accent
                        font.family: bar.fontFamily
                        font.pixelSize: bar.fontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.connectedNetwork ? bar.connectedNetwork.name : ""
                        color: bar.text
                        font.family: bar.fontFamily
                        font.pixelSize: bar.fontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.connectedNetwork
                              ? Math.round(bar.connectedNetwork.signalStrength * 100) + "%" : ""
                        color: bar.subtext
                        font.family: bar.fontFamily
                        font.pixelSize: bar.fontSize
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Disconnect"
                    color: disconnectMouse.containsMouse ? bar.red : bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize - 1

                    MouseArea {
                        id: disconnectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (bar.connectedNetwork)
                                bar.connectedNetwork.disconnect();
                        }
                    }
                }
            }

            Rectangle {
                width: menuColumn.width
                height: 1
                color: bar.surface
            }

            Text {
                text: "Available networks"
                color: bar.subtext
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize - 1
            }

            Text {
                visible: !Networking.wifiEnabled
                text: "Wi-Fi is off"
                color: bar.subtext
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize
            }

            Text {
                visible: Networking.wifiEnabled && bar.wifiNetworks.length === 0
                text: "Scanning..."
                color: bar.subtext
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize
            }

            // Network list (scrolls if it gets long)
            Flickable {
                id: networkList

                width: menuColumn.width
                height: Math.min(networkColumn.implicitHeight, 180)
                contentHeight: networkColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: Networking.wifiEnabled && bar.wifiNetworks.length > 0

                Column {
                    id: networkColumn

                    width: networkList.width
                    spacing: 2

                    Repeater {
                        model: bar.wifiNetworks

                        delegate: Rectangle {
                            id: netRow

                            required property var modelData

                            width: networkColumn.width
                            height: 26
                            radius: 5
                            color: netMouse.containsMouse ? bar.surface
                                 : modelData.connected ? bar.surface
                                 : "transparent"

                            Row {
                                anchors {
                                    left: parent.left
                                    leftMargin: 6
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: netRow.modelData.connected
                                          ? "\uF00C"
                                          : networkPopup.isSecured(netRow.modelData)
                                            ? "\uF023" : ""
                                    color: netRow.modelData.connected ? bar.accent : bar.subtext
                                    font.family: bar.fontFamily
                                    font.pixelSize: bar.fontSize - 1
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 155
                                    elide: Text.ElideRight
                                    text: netRow.modelData.name
                                    color: bar.text
                                    font.family: bar.fontFamily
                                    font.pixelSize: bar.fontSize
                                }
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text: Math.round(netRow.modelData.signalStrength * 100) + "%"
                                color: bar.subtext
                                font.family: bar.fontFamily
                                font.pixelSize: bar.fontSize - 1
                            }

                            MouseArea {
                                id: netMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: networkPopup.selectNetwork(netRow.modelData)
                            }
                        }
                    }
                }
            }

            // Password prompt for a new secured network
            Column {
                width: menuColumn.width
                spacing: 4
                visible: networkPopup.pendingNetwork !== null

                Text {
                    text: "Password for " + (networkPopup.pendingNetwork
                                              ? networkPopup.pendingNetwork.name : "")
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize - 1
                }

                Row {
                    id: pskRow

                    width: menuColumn.width
                    spacing: 6

                    Rectangle {
                        width: pskRow.width - pskConnect.width - pskRow.spacing
                        height: 24
                        radius: 5
                        color: bar.surface

                        TextInput {
                            id: pskInput

                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: bar.text
                            selectionColor: bar.accent
                            selectedTextColor: bar.bg
                            font.family: bar.fontFamily
                            font.pixelSize: bar.fontSize
                            clip: true
                            onAccepted: networkPopup.connectPending()
                        }

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            visible: pskInput.text.length === 0
                            text: "Password"
                            color: bar.subtext
                            font.family: bar.fontFamily
                            font.pixelSize: bar.fontSize
                        }
                    }

                    Rectangle {
                        id: pskConnect

                        width: 60
                        height: 24
                        radius: 5
                        color: pskMouse.containsMouse ? bar.accent : bar.surface

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: pskMouse.containsMouse ? bar.bg : bar.text
                            font.family: bar.fontFamily
                            font.pixelSize: bar.fontSize
                        }

                        MouseArea {
                            id: pskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: networkPopup.connectPending()
                        }
                    }
                }
            }
        }
    }

    // ----------------------------------------------------------- volume menu
    PanelWindow {
        id: volumePopup

        anchors {
            top: true
            right: true
        }
        margins {
            top: 32
            right: 8
        }
        implicitWidth: 240
        implicitHeight: volumeColumn.implicitHeight + 18
        color: "transparent"
        visible: false

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-volume-menu"

        HyprlandFocusGrab {
            active: volumePopup.visible
            windows: [volumePopup]
            onCleared: volumePopup.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: bar.bg
            border.width: 1
            border.color: bar.surface
        }

        Column {
            id: volumeColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 6

            Item {
                width: volumeColumn.width
                height: 18

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sound"
                    color: bar.text
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize + 1
                    font.bold: true
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: bar.muted ? "\uF026" : bar.volumeIcon()
                    color: muteMouse.containsMouse ? bar.accent
                         : bar.muted ? bar.red : bar.text
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize + 1

                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (bar.audio)
                                bar.audio.muted = !bar.audio.muted;
                        }
                    }
                }
            }

            Text {
                width: volumeColumn.width
                elide: Text.ElideRight
                text: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.description : ""
                color: bar.subtext
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize - 1
            }

            Item {
                width: volumeColumn.width
                height: 18

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: bar.muted ? "Muted" : "Volume"
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize - 1
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: bar.volumePercent + "%"
                    color: bar.muted ? bar.subtext : bar.text
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize
                    font.bold: true
                }
            }

            Item {
                id: volumeSlider

                width: volumeColumn.width
                height: 14

                readonly property real fill: Math.min(1, Math.max(0,
                    (bar.audio ? bar.audio.volume : 0) / bar.maxVolume))

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: bar.surface
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: volumeSlider.width * volumeSlider.fill
                    height: 4
                    radius: 2
                    color: bar.muted ? bar.subtext
                         : (bar.audio && bar.audio.volume > 1 ? bar.yellow : bar.accent)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(volumeSlider.width - width,
                                             volumeSlider.width * volumeSlider.fill - width / 2))
                    width: 12
                    height: 12
                    radius: 6
                    color: bar.text
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function setFromX(x) {
                        bar.setVolume((x / width) * bar.maxVolume);
                    }

                    onPressed: mouse => setFromX(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed)
                            setFromX(mouse.x);
                    }
                }
            }

            Rectangle {
                width: volumeColumn.width
                height: 24
                radius: 5
                color: muteAllMouse.containsMouse ? bar.accent : bar.surface

                Text {
                    anchors.centerIn: parent
                    text: bar.muted ? "Unmute" : "Mute"
                    color: muteAllMouse.containsMouse ? bar.bg : bar.text
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize
                }

                MouseArea {
                    id: muteAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (bar.audio)
                            bar.audio.muted = !bar.audio.muted;
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- launcher
    // Super+A. A small app search in the same dark grey style as the bar.
    PanelWindow {
        id: launcher

        property string query: ""
        property int selected: 0
        readonly property int maxResults: 7

        // All launchable entries, alphabetically.
        readonly property var allApps: {
            const list = [];
            for (const app of DesktopEntries.applications.values) {
                if (app.noDisplay || app.name === "")
                    continue;
                list.push(app);
            }
            list.sort((a, b) => a.name.localeCompare(b.name));
            return list;
        }

        // Prefer name matches, then keywords/comment, then fuzzy subsequence.
        function matchScore(app, needle) {
            const name = app.name.toLowerCase();

            let score = 0;
            if (name === needle) {
                score = 1000;
            } else if (name.startsWith(needle)) {
                score = 900 - name.length;
            } else {
                for (const word of name.split(/[\s\-_.]+/)) {
                    if (word.startsWith(needle)) {
                        score = 850 - name.length;
                        break;
                    }
                }
                if (score === 0) {
                    const at = name.indexOf(needle);
                    if (at !== -1)
                        score = 700 - at * 2 - name.length;
                }
            }

            if (score === 0) {
                for (const kw of app.keywords) {
                    if (kw.toLowerCase().includes(needle)) {
                        score = 500;
                        break;
                    }
                }
            }

            if (score === 0 && app.comment.toLowerCase().includes(needle))
                score = 400;

            if (score === 0)
                score = subsequenceScore(name, needle);

            return score;
        }

        function subsequenceScore(haystack, needle) {
            let at = 0;
            let score = 0;
            let streak = 0;
            for (let i = 0; i < needle.length; i++) {
                const found = haystack.indexOf(needle[i], at);
                if (found === -1)
                    return 0;
                streak = found === at ? streak + 1 : 0;
                score += 10 + streak * 10 - Math.min(8, found - at);
                at = found + 1;
            }
            return Math.max(1, 200 + score - haystack.length);
        }

        readonly property var results: {
            const needle = query.trim().toLowerCase();
            if (needle === "")
                return allApps.slice(0, maxResults);

            const matches = [];
            for (const app of allApps) {
                const score = matchScore(app, needle);
                if (score > 0)
                    matches.push({ app: app, score: score });
            }
            matches.sort((a, b) => b.score - a.score
                                  || a.app.name.localeCompare(b.app.name));
            return matches.slice(0, maxResults).map(m => m.app);
        }

        onQueryChanged: selected = 0
        onResultsChanged: {
            if (selected >= results.length)
                selected = Math.max(0, results.length - 1);
        }

        function open() {
            query = "";
            selected = 0;
            searchInput.text = "";
            networkPopup.visible = false;
            volumePopup.visible = false;
            visible = true;
            Qt.callLater(() => searchInput.forceActiveFocus());
        }

        function close() {
            visible = false;
        }

        function toggle() {
            if (visible)
                close();
            else
                open();
        }

        function launch(app) {
            if (!app)
                return;
            close();
            app.execute();
        }

        function launchSelected() {
            if (results.length > 0)
                launch(results[Math.min(selected, results.length - 1)]);
        }

        anchors {
            top: true
            left: true
        }
        // Centre horizontally on the bar's screen.
        margins {
            top: 90
            left: Math.max(0, ((launcher.screen ? launcher.screen.width : 1920)
                               - implicitWidth) / 2)
        }
        implicitWidth: 340
        implicitHeight: launcherColumn.implicitHeight + 16
        color: "transparent"
        visible: false

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None

        // Close when clicking outside.
        HyprlandFocusGrab {
            active: launcher.visible
            windows: [launcher]
            onCleared: launcher.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: bar.bg
            border.width: 1
            border.color: bar.surface
        }

        Column {
            id: launcherColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 6

            // --- search field ---
            Rectangle {
                width: launcherColumn.width
                height: 30
                radius: 6
                color: bar.surface

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 9
                        verticalCenter: parent.verticalCenter
                    }
                    text: "\uF002" // magnifier
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize + 1
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 28
                        verticalCenter: parent.verticalCenter
                    }
                    visible: searchInput.text.length === 0
                    text: "Search apps..."
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize
                }

                TextInput {
                    id: searchInput

                    anchors {
                        left: parent.left
                        leftMargin: 28
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    height: 18
                    color: bar.text
                    selectionColor: bar.accent
                    selectedTextColor: bar.bg
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize
                    focus: launcher.visible
                    selectByMouse: true
                    clip: true

                    cursorDelegate: Rectangle {
                        width: 1
                        color: bar.accent
                    }

                    onTextChanged: launcher.query = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            launcher.selected = Math.min(launcher.results.length - 1,
                                                         launcher.selected + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            launcher.selected = Math.max(0, launcher.selected - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launcher.launchSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            launcher.close();
                            event.accepted = true;
                        }
                    }
                }
            }

            // --- results ---
            Column {
                id: resultsColumn

                width: launcherColumn.width
                spacing: 2

                Repeater {
                    model: launcher.results

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: resultsColumn.width
                        height: 24
                        radius: 4
                        color: launcher.selected === index ? bar.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            text: modelData.name
                            color: launcher.selected === index ? bar.accent : bar.text
                            font.family: bar.fontFamily
                            font.pixelSize: bar.fontSize
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: launcher.selected = index
                            onClicked: launcher.launch(modelData)
                        }
                    }
                }

                Text {
                    width: resultsColumn.width
                    height: visible ? 26 : 0
                    visible: launcher.results.length === 0
                    text: "No applications found"
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                }
            }

            // --- footer ---
            Item {
                width: launcherColumn.width
                height: 14

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 2
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Enter  launch"
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize - 1
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 2
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Esc  close"
                    color: bar.subtext
                    font.family: bar.fontFamily
                    font.pixelSize: bar.fontSize - 1
                }
            }
        }
    }
}
