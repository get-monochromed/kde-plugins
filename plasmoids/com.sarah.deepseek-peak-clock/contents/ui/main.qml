/*
 * DeepSeek Peak-Time Clock — Plasma 6 applet root.
 *
 * Popup applet: the compact representation (StatusIndicator) sits in the
 * panel; clicking it toggles the popup (full representation) anchored above
 * the widget by the shell. All billing state is recomputed here by
 * refresh() and passed down to the representations as plain properties.
 *
 * The peak/off-peak decision itself lives in peak.js (pure, unit-tested).
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "peak.js" as Peak

PlasmoidItem {
    id: root

    // Popup applet: compact in the panel, full representation in a popup on
    // click. MUST prefer the COMPACT representation — with the full one
    // preferred, libplasma's appletShouldBeExpanded() returns true and the
    // full representation is parented inline into the panel (no popup).
    preferredRepresentation: compactRepresentation

    // Fixed panel size hints on the root as well: the panel reads
    // applet.Layout.* (BasicAppletContainer), and if the compact's hints are
    // not picked up these constants keep the applet visible. Sizes are the
    // content-derived widths of the compact StatusIndicator (never 0).
    Layout.fillHeight: true
    Layout.preferredWidth: compactRepresentation.implicitWidth
    Layout.preferredHeight: compactRepresentation.implicitHeight
    Layout.minimumWidth: compactRepresentation.implicitWidth
    Layout.maximumWidth: 32767

    // ---- Derived state (recomputed by refresh() and consumed by both
    // representations).
    property string phaseName: "flat"          // "flat" | "peak" | "off"
    property int minutesToNext: 0
    property bool nextStart: false
    property var windows: Peak.PEAK_WINDOWS_UTC
    property int offsetMins: 0                 // signed minutes to add to UTC for the chosen zone
    property int localNowMins: 0               // local wall-clock minutes of day
    property int utcNowMins: 0                 // UTC minutes of day
    property bool weekendOffPeak: false        // true: Beijing weekend after the weekend-rule epoch
    property color phaseColor: "#fb8c00"
    property string statusText: ""
    property string countdownText: ""
    property string zoneLabel: ""              // "Europe/Berlin", "UTC+02:00"…

    function refresh() {
        try {
            refreshImpl();
        } catch (e) {
            // Never let one bad helper (e.g. a zone lookup) blank the whole
            // widget — log and keep the last known state.
            console.warn("deepseek-peak-clock refresh failed: " + e);
        }
    }

    function refreshImpl() {
        var nowMs = Date.now();
        var cfg = plasmoid.configuration;

        // NB: every cfg read has a fallback — stored config values can be
        // empty/invalid (an empty color renders TRANSPARENT: invisible dot
        // and pie, empty label: no text). The `||` keeps sane defaults.
        var peakColor = cfg.peakColor || "#e53935";
        var offPeakColor = cfg.offPeakColor || "#43a047";
        var flatColor = cfg.flatColor || "#fb8c00";

        root.windows = Peak.applyOverride(cfg.peakWindows);
        var p = Peak.phaseAt(nowMs, root.windows, Peak.EFFECTIVE_EPOCH, Peak.WEEKEND_RULE_EPOCH);
        root.phaseName = p.phase;
        root.minutesToNext = p.minutesToNext;
        root.nextStart = p.nextStart;
        root.weekendOffPeak = nowMs >= Peak.WEEKEND_RULE_EPOCH * 1000
                           && Peak.isWeekendBeijing(nowMs);

        var local = Peak.localHourMin(nowMs, cfg.timeZone || "System");
        root.localNowMins = local.h * 60 + local.m;
        var localOff = Peak.localOffsetMins(nowMs, cfg.timeZone || "System");
        root.offsetMins = Peak.signedOffsetMins(localOff);
        var utc = Peak.localHourMin(nowMs, "UTC");
        root.utcNowMins = utc.h * 60 + utc.m;

        // Human-readable label for the timezone the system-time display uses:
        // "Eastern Standard Time (UTC-05:00)". The name comes from the display
        // table (peak.js ZONE_DISPLAY_NAMES) and the offset is the CURRENT
        // (DST-aware) signed UTC offset. The billing decision is unaffected.
        var zone = cfg.timeZone || "System";
        var offText = Peak.offsetText(root.offsetMins);
        if (zone !== "System") {
            root.zoneLabel = Peak.zoneDisplayName(zone) + " (UTC" + offText + ")";
        } else {
            var sysName = Peak.zoneDisplayName(Peak.systemZoneName(nowMs));
            if (!sysName) {
                // No resolved system zone name (no-Intl engine): fall back to
                // a name derived from the current signed offset.
                sysName = Peak.zoneNameFromOffset(root.offsetMins, nowMs);
            }
            root.zoneLabel = sysName ? sysName + " (UTC" + offText + ")" : "UTC" + offText;
        }

        var label = p.phase === "flat" ? (cfg.flatLabel || "FLAT")
                  : p.phase === "peak" ? (cfg.peakLabel || "PEAK")
                  : (cfg.offPeakLabel || "OFF-PEAK");
        // v2.0: no separate unicode symbol — the colored dot is the status
        // icon, and the text label itself is colored by phase.
        root.statusText = label;
        root.phaseColor = p.phase === "flat" ? flatColor
                        : p.phase === "peak" ? peakColor
                        : offPeakColor;

        if (p.phase === "flat") {
            root.countdownText = i18n("Peak/off-peak billing starts in %1",
                Peak.formatDuration(p.minutesToNext));
        } else if (p.phase === "peak") {
            root.countdownText = i18n("Peak ends in %1",
                Peak.formatDuration(p.minutesToNext));
        } else if (root.weekendOffPeak) {
            root.countdownText = i18n("Weekend off-peak ends in %1",
                Peak.formatDuration(p.minutesToNext));
        } else {
            root.countdownText = i18n("Next peak starts in %1",
                Peak.formatDuration(p.minutesToNext));
        }
    }

    // Hover tooltip (countdown line only when enabled in settings).
    // Plasma 6: toolTip* are properties of the PlasmoidItem root, not of the
    // Plasmoid attached object (KF6 Applet dropped them — porting_kf6 guide).
    toolTipMainText: root.statusText
    toolTipSubText: plasmoid.configuration.showCountdown
        ? root.countdownText : ""
    // A custom toolTipItem REPLACES toolTipMainText/SubText, so it must carry
    // both the status and the countdown — otherwise the countdown vanishes
    // from the hover tooltip (the v2.0 regression).
    toolTipItem: Column {
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents3.Label {
            text: root.statusText
            font.bold: true
            color: root.phaseColor
        }
        PlasmaComponents3.Label {
            text: root.countdownText
            visible: plasmoid.configuration.showCountdown
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }

    // ---- Panel representation: the DeepSeek whale (bright during peak
    // hours, dimmed off-peak). The colour + text status lives in the flyout
    // and the tooltip. Digital Clock pattern: the compact representation must
    // export Layout.* hints — the shell only reads those (not implicit sizes)
    // to size the applet in the panel — and toggle `expanded` on click; the
    // shell then shows the full representation in a popup anchored above the
    // widget.
    compactRepresentation: MouseArea {
        id: compactArea
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property bool wasExpanded

        // FIXED size hints — content-derived from the StatusIndicator, whose
        // size is a constant (icon size × fixed height), so these are never 0.
        // The shell reads these (not implicit sizes) to size the applet in
        // the panel.
        Layout.fillWidth: false
        Layout.fillHeight: true
        Layout.preferredWidth: indicator.implicitWidth
        Layout.preferredHeight: indicator.implicitHeight
        Layout.minimumWidth: indicator.implicitWidth
        Layout.maximumWidth: 32767

        implicitWidth: indicator.implicitWidth
        implicitHeight: indicator.implicitHeight

        Accessible.role: Accessible.Button
        Accessible.onPressAction: compactArea.toggleExpanded()

        function toggleExpanded() {
            root.expanded = !root.expanded;
        }

        // `expanded` lives on the PlasmoidItem root (KF6 Applet dropped it).
        // Read it on press: if the popup is open, the shell closes it before
        // the click arrives, and toggling from the post-close state would
        // reopen instead of close.
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        StatusIndicator {
            id: indicator
            anchors.fill: parent
            peak: root.phaseName === "peak"
        }
    }

    // ---- Popup: 24 h dial + live settings.
    fullRepresentation: PopupView {
        phaseName: root.phaseName
        phaseColor: root.phaseColor
        statusText: root.statusText
        countdownText: root.countdownText
        minutesToNext: root.minutesToNext
        windows: root.windows
        offsetMins: root.offsetMins
        localNowMins: root.localNowMins
        utcNowMins: root.utcNowMins
        zoneName: plasmoid.configuration.timeZone
        zoneLabel: root.zoneLabel
        weekendOffPeak: root.weekendOffPeak
    }

    // ---- Refresh: the peak state obviously doesn't change second-to-second,
    // so update on a configurable interval (default 15 min) instead of every
    // minute. The first tick lands at the next minute boundary so the very
    // first update is prompt; each later tick is a full interval apart. Also
    // refresh right when the popup opens so a popup shown after hours of
    // idling is never stale.
    property int refreshIntervalMinutes: {
        var v = plasmoid.configuration.refreshInterval;
        return (typeof v === "number" && v >= 1) ? v : 15;
    }

    Timer {
        id: refreshTimer
        repeat: false
        running: true
        interval: 60000 - (Date.now() % 60000)
        onTriggered: {
            root.refresh();
            interval = root.refreshIntervalMinutes * 60000;
            restart();
        }
    }

    // Recompute immediately when any setting changes (KConfig persists it).
    Connections {
        target: plasmoid.configuration
        function onValueChanged(key) {
            if (key === "refreshInterval") {
                refreshTimer.interval = root.refreshIntervalMinutes * 60000;
                refreshTimer.restart();
            } else {
                root.refresh();
            }
        }
    }

    // A refresh() on every expand isn't strictly necessary (the interval
    // timer covers it), but guarantees a just-opened popup is never stale by
    // more than the (up to 15-min) interval. Cheap enough to do unconditionally.
    onExpandedChanged: if (expanded) root.refresh()

    Component.onCompleted: root.refresh()
}
