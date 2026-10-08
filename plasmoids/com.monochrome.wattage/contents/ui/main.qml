/*
 * SPDX-FileCopyrightText: 2026 monochrome
 * SPDX-License-Identifier: MIT
 *
 * Wattage — minimal battery wattage readout for the Plasma 6 panel.
 *
 * Compact: "-7.4 W" discharging, "+42.0 W" charging, "0.0 W" otherwise.
 * Hover:   current value, 1-min / 5-min / since-login averages, 15-min min/max,
 *          battery %, time to empty/full.
 *
 * Data: /sys/class/power_supply/{BAT0,AC}/uevent, polled once a second — the raw
 * kernel value, not UPower's smoothed energy-rate (which is what the stock
 * System Monitor sensor shows, and why it looks frozen).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    // No flyout is wanted, so a click must never toggle the popup open.
    activationTogglesExpanded: false

    readonly property string batteryPath: "/sys/class/power_supply/BAT0"
    readonly property string acPath: "/sys/class/power_supply/AC"
    readonly property int pollInterval: 1000
    readonly property int historyMs: 15 * 60 * 1000
    readonly property int avgWindowShort: 60 * 1000
    readonly property int avgWindowLong: 5 * 60 * 1000

    readonly property string readCmd: "cat " + batteryPath + "/uevent " + acPath + "/uevent 2>/dev/null"
    // Panel click: a detached Konsole running btop. `setsid -f` returns at once,
    // so the data source frees up again immediately and every click works.
    readonly property string btopCmd: "setsid -f konsole --separate -e btop"
    // Middle click: Mission Center (Flatpak — no wrapper in PATH).
    readonly property string missionCmd: "setsid -f flatpak run io.missioncenter.MissionCenter"

    // ---------------------------------------------------------------- state
    property string batteryStatus: ""
    property real watts: 0
    property int capacity: -1
    property real energyNow: 0
    property real energyFull: 0
    property bool acOnline: false
    property bool batteryPresent: true

    // rolling history, oldest first
    property var histT: []
    property var histW: []
    property real sessionSum: 0
    property int sessionCount: 0

    readonly property bool charging: batteryStatus === "Charging"
    readonly property bool discharging: batteryStatus === "Discharging"

    readonly property string valueText: {
        const t = watts.toFixed(1) + " W"
        if (charging)
            return "+" + t
        if (discharging)
            return "-" + t
        return t
    }

    // --------------------------------------------------------------- sizing
    // The shell sizes a panel applet from the ROOT's Layout.* hints; the
    // compact representation is anchored inside that box. Size from constants
    // (never from the compact item or a positioner) so the applet can't
    // collapse to zero on the first layout pass.
    readonly property int fontPx: 12
    readonly property int compactHeight: Math.round(fontPx * 1.5)
    // Widest realistic reading, reserved so the panel never jiggles.
    readonly property int valueWidth: Math.max(56, Math.round(valueMetrics.advanceWidth) + Kirigami.Units.smallSpacing * 2)

    TextMetrics {
        id: valueMetrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: root.fontPx
        // widest realistic reading, reserved so the panel never jiggles
        text: "-00.0 W"
    }

    Layout.fillHeight: true
    Layout.preferredWidth: root.valueWidth
    Layout.minimumWidth: root.valueWidth
    Layout.maximumWidth: root.valueWidth
    Layout.preferredHeight: Math.round(root.fontPx * 1.5)

    // libplasma treats an applet with no full representation as "always
    // expanded" — and then draws nothing at all in the panel. A placeholder
    // full representation fixes that; since nothing ever sets `expanded`, the
    // flyout is never shown and clicking the widget does nothing.
    fullRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 12
        implicitHeight: Kirigami.Units.gridUnit * 6
    }

    // ------------------------------------------------------------ ingestion
    function appendSample(w) {
        const now = Date.now()
        const ts = histT.slice()
        const ws = histW.slice()
        ts.push(now)
        ws.push(w)
        while (ts.length > 0 && now - ts[0] > historyMs) {
            ts.shift()
            ws.shift()
        }
        histT = ts
        histW = ws
        sessionSum += w
        sessionCount += 1
    }

    function ingest(out) {
        const lines = out.split("\n")
        let st = "", cap = -1, en = 0, ef = 0, pnow = -1, ac = false, present = true
        for (let i = 0; i < lines.length; ++i) {
            const kv = lines[i].split("=")
            if (kv.length !== 2)
                continue
            const k = kv[0].trim()
            const v = kv[1].trim()
            switch (k) {
            case "POWER_SUPPLY_PRESENT":
                present = v === "1"
                break
            case "POWER_SUPPLY_STATUS":
                st = v
                break
            case "POWER_SUPPLY_CAPACITY":
                cap = parseInt(v)
                break
            case "POWER_SUPPLY_ENERGY_NOW":
                en = parseFloat(v) / 1e6
                break
            case "POWER_SUPPLY_ENERGY_FULL":
                ef = parseFloat(v) / 1e6
                break
            case "POWER_SUPPLY_POWER_NOW":
                pnow = parseFloat(v) / 1e6
                break
            case "POWER_SUPPLY_ONLINE":
                ac = v === "1"
                break
            }
        }
        acOnline = ac
        batteryPresent = present
        if (pnow < 0)
            return
        batteryStatus = st
        capacity = cap
        energyNow = en
        energyFull = ef
        watts = pnow
        appendSample(pnow)
    }

    // ------------------------------------------------------------- averaging
    function avgOver(ms) {
        const now = Date.now()
        let sum = 0, n = 0
        for (let i = histT.length - 1; i >= 0; --i) {
            if (now - histT[i] > ms)
                break
            sum += histW[i]
            ++n
        }
        return n > 0 ? sum / n : 0
    }

    function avgSession() {
        return sessionCount > 0 ? sessionSum / sessionCount : 0
    }

    function rangeOver(ms) {
        const now = Date.now()
        let lo = Infinity, hi = -Infinity
        for (let i = histT.length - 1; i >= 0; --i) {
            if (now - histT[i] > ms)
                break
            lo = Math.min(lo, histW[i])
            hi = Math.max(hi, histW[i])
        }
        return hi === -Infinity ? [0, 0] : [lo, hi]
    }

    function durationText(hours) {
        if (!isFinite(hours) || hours <= 0)
            return "--"
        let mins = Math.round(hours * 60)
        const h = Math.floor(mins / 60)
        mins = mins % 60
        if (h <= 0)
            return mins + " min"
        return h + " h " + (mins < 10 ? "0" : "") + mins + " min"
    }

    // --------------------------------------------------------------- tooltip
    toolTipMainText: valueText

    toolTipSubText: {
        // touch the history so this re-evaluates on every sample
        const haveT = histT.length
        const haveW = histW.length
        const range = rangeOver(historyMs)

        let head = ""
        if (batteryStatus.length > 0)
            head += batteryStatus
        if (acOnline)
            head += head.length > 0 ? " · AC connected" : "AC connected"
        if (capacity >= 0)
            head += (head.length > 0 ? " · " : "") + capacity + "%"
        if (charging && watts > 0.05)
            head += " · " + durationText((energyFull - energyNow) / watts) + " to full"
        else if (discharging && watts > 0.05)
            head += " · " + durationText(energyNow / watts) + " to empty"

        const rows = [
            ["avg 1 min", avgOver(avgWindowShort).toFixed(1) + " W"],
            ["avg 5 min", avgOver(avgWindowLong).toFixed(1) + " W"],
            ["since login", avgSession().toFixed(1) + " W"],
            ["min / max 15 min", range[0].toFixed(1) + " / " + range[1].toFixed(1) + " W"],
            ["left / middle click", "btop / Mission Center"]
        ]

        let body = ""
        for (let i = 0; i < rows.length; ++i)
            body += "\n" + rows[i][0] + ":  " + rows[i][1]

        return head + body
    }

    // ------------------------------------------------------------ collection
    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: sysSource.connectSource(root.readCmd)
    }

    P5Support.DataSource {
        id: sysSource
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            sysSource.disconnectSource(source)
            root.ingest(data["stdout"] || "")
        }
    }

    // Second engine for click actions, kept separate from the 1 s poll so a
    // launch can never collide with a reading in flight.
    P5Support.DataSource {
        id: cmdSource
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            cmdSource.disconnectSource(source)
        }
    }

    function launchBtop() {
        cmdSource.disconnectSource(btopCmd)
        cmdSource.connectSource(btopCmd)
    }

    function launchMissionCenter() {
        cmdSource.disconnectSource(missionCmd)
        cmdSource.connectSource(missionCmd)
    }

    // ------------------------------------------------------------- panel view
    compactRepresentation: Item {
        id: compact

        implicitWidth: root.valueWidth
        implicitHeight: root.compactHeight

        Layout.fillHeight: true
        Layout.preferredWidth: root.valueWidth
        Layout.minimumWidth: root.valueWidth
        Layout.preferredHeight: root.compactHeight

        Text {
            id: valueLabel
            anchors.centerIn: parent
            text: root.batteryPresent ? root.valueText : "--"
            color: Kirigami.Theme.textColor
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: root.fontPx
        }

        // Left click -> btop in a new Konsole window, middle click -> Mission Center.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton)
                    root.launchMissionCenter()
                else
                    root.launchBtop()
            }
        }
    }
}
