/*
 * PopupView — the click-popup (full representation), anchored above the
 * widget by the shell. Shows the 24 h pie, the current status, the system
 * time + timezone, the UTC time, the peak/off-peak countdown, and the
 * effective peak windows.
 *
 * Settings are NOT here: they live in the shell's "Configure…" dialog
 * (contents/config/config.qml), reachable via the widget's right-click menu.
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "peak.js" as Peak

Item {
    id: popup

    property string phaseName: "flat"   // "flat" | "peak" | "off"
    property color phaseColor: "#fb8c00"
    property string statusText: ""
    property string countdownText: ""
    property int minutesToNext: 0
    property var windows: []
    property int offsetMins: 0          // signed UTC offset of the chosen zone
    property int localNowMins: 0
    property int utcNowMins: 0
    property string zoneName: "System"
    property string zoneLabel: ""       // resolved display name/offset of the zone
    property bool weekendOffPeak: false // Beijing weekend after the 2026-08-23 rule

    // Layout minimum size: the shell honours Layout.minimumWidth/Height and
    // will not let the popup shrink below this floor. (v2.4: raised ~20% on
    // request; content still elides/clips when shrunk below its natural size.)
    // v2.5: minimum height raised ~10% (17 → 19 gridUnit); minimum width
    // untouched. v2.6: minimum height raised another ~10% (19 → 21 gridUnit)
    // so the pie + labels never clip at the bottom; width still untouched.
    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 28
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 21

    // Lock the popup WIDTH to the fixed 22 gridUnit so a long timezone / status
    // line can never widen the popup (which used to push the centred pie clock
    // right and add whitespace to its left). Long text just overflows/clips at
    // the right edge instead — see the `clip` on the layout below. (v2.5)
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.maximumWidth: Kirigami.Units.gridUnit * 22

    function clockText(mins) {
        return Peak.pad2(Math.floor(mins / 60)) + ":" + Peak.pad2(mins % 60);
    }
    function windowsText() {
        return Peak.formatWindows(popup.windows);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.smallSpacing
        // v2.5: clip children so an over-long timezone/status line is cut off
        // at the right edge instead of widening the popup (see the width lock
        // above) — it no longer pushes the centred pie clock sideways.
        clip: true

        PieClock {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
            windows: popup.windows
            offsetMins: popup.offsetMins
            nowMins: popup.localNowMins
            flat: popup.phaseName === "flat"
            weekend: popup.weekendOffPeak
            peakColor: plasmoid.configuration.peakColor || "#e53935"
            offPeakColor: plasmoid.configuration.offPeakColor || "#43a047"
            flatColor: plasmoid.configuration.flatColor || "#fb8c00"
        }

        // ---- Current phase label, BELOW the pie clock (v2.3). Centered with
        // no leading circle — the text itself is the status, colored by phase.
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: popup.statusText
            // Qt 6 forbids a whole `font:` assignment together with
            // sub-property assignments (e.g. font.bold) in one literal;
            // PlasmaComponents3.Label already uses the system font.
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
            color: popup.phaseColor
            elide: Text.ElideRight
        }

        // ---- Countdown, directly BELOW the Peak/Off-Peak status text (v2.5:
        // moved up from under the system-time row so "time until next window"
        // reads against the phase it belongs to).
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: popup.countdownText
            visible: plasmoid.configuration.showCountdown
            horizontalAlignment: Text.AlignHCenter
            font: Kirigami.Theme.smallFont
            elide: Text.ElideRight
        }

        // ---- System time, its timezone, and the UTC time (UTC shown once).
        // The zone label is the flexible middle element: it fills the leftover
        // width and elides when a long timezone name would otherwise grow the
        // row (and with it the whole popup) past the fixed 22 gridUnit width —
        // which used to push the UTC readout off the right edge. The local
        // time stays left and UTC stays pinned right; the zone text just
        // truncates in between instead. (v2.6)
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignVCenter
                text: popup.clockText(popup.localNowMins)
                font.bold: true
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: popup.zoneLabel
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignVCenter
                text: popup.clockText(popup.utcNowMins) + " UTC"
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }

        // Effective windows + effective date.
        // NB: pass the arguments to i18n() itself — chaining .arg() on the
        // result triggers ki18n's "I18N argument missing" error.
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: popup.phaseName === "flat"
                ? i18n("Peak hours (UTC): %1\nPeak/off-peak billing starts %2",
                       popup.windowsText(), Peak.EFFECTIVE_TEXT)
                : popup.weekendOffPeak
                    ? i18n("Weekend (Beijing): off-peak all day\nWeekday peak hours (UTC): %1",
                           popup.windowsText())
                    : i18n("Peak hours (UTC): %1\nWeekends (Beijing) off-peak from %2",
                           popup.windowsText(), Peak.WEEKEND_RULE_TEXT)
        }
    }
}
