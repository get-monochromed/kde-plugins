/*
 * StatusIndicator — the panel widget.
 *
 * LOCAL MODIFICATION (2026-09): upstream this was a phase-coloured dot with a
 * pulsing glow plus a bold phase-coloured "PEAK" / "OFF-PEAK" label. The panel
 * now shows ONLY the DeepSeek whale: full brightness during peak hours, dimmed
 * off-peak. The colour + text status still lives in the flyout (PopupView) and
 * the hover tooltip, which are untouched.
 *
 * Sizing: content-derived constants only (never a positioner's implicit size —
 * positioner implicit widths can be 0 on a first layout pass, which collapsed
 * the applet to nothing on the real panel). The height stays a fixed
 * gridUnit multiple so the icon is never clipped.
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Panel state: peak hours = bright, everything else = dimmed.
    property bool peak: false

    property real iconSize: Kirigami.Units.iconSizes.smallMedium

    implicitWidth: iconSize
    implicitHeight: Kirigami.Units.gridUnit * 1.5

    DeepSeekIcon {
        anchors.centerIn: parent
        iconSize: root.iconSize
        peak: root.peak
    }
}
