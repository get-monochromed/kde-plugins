/*
 * Settings form (contents/ui/configGeneral.qml).
 *
 * Loaded by the shell's "Configure…" dialog via config.qml's ConfigModel.
 * All controls read/write plasmoid.configuration.<key> directly: KConfig
 * persists every write and emits valueChanged, which main.qml listens to —
 * so settings are live.
 *
 * Text fields commit on editingFinished (not on every keystroke) and are
 * re-bound to the config whenever the value changes externally, so the form
 * never drifts from the stored configuration.
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "peak.js" as Peak

Item {
    id: form

    // The config-page host sizes the page from the root item's size. A plain
    // Item that only fills from an anchored ScrollView collapses to 0×0 (the
    // ScrollView's anchors.fill depends on the parent, so nothing gives the
    // parent a size) → the tab renders empty ("no options"). Match the
    // reference config pages (e.g. systemtray ConfigGeneral.qml): size the
    // root from childrenRect and carry an explicit implicit size.
    width: childrenRect.width
    height: childrenRect.height
    implicitWidth: Kirigami.Units.gridUnit * 30
    implicitHeight: Kirigami.Units.gridUnit * 36

    property var cfg: plasmoid.configuration

    // ------------------------------------------------------- color picker
    component ColorSetting: RowLayout {
        id: cs
        property string labelText: ""
        property color colorValue: "#000000"
        signal applyColor(color value)

        PlasmaComponents3.Label {
            text: cs.labelText
            Layout.preferredWidth: Kirigami.Units.gridUnit * 7
        }
        Rectangle {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
            radius: Kirigami.Units.smallSpacing
            color: cs.colorValue
            border.width: 1
            border.color: Kirigami.Theme.textColor
        }
        PlasmaComponents3.TextField {
            id: hexField
            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            text: cs.colorValue.toString()
            onEditingFinished: {
                if (/^#[0-9a-fA-F]{6}$/.test(hexField.text)) {
                    cs.applyColor(hexField.text);
                } else {
                    // invalid input: snap back to the stored color
                    hexField.text = Qt.binding(function () { return cs.colorValue.toString(); });
                }
            }
        }
        Row {
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: ["#e53935", "#43a047", "#fb8c00", "#1e88e5", "#8e24aa", "#fdd835"]
                Rectangle {
                    width: Kirigami.Units.gridUnit
                    height: Kirigami.Units.gridUnit
                    radius: width / 2
                    color: modelData
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cs.applyColor(modelData);
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- model
    ListModel {
        id: zoneModel
        ListElement { label: "System (follow computer)"; zone: "System" }
        ListElement { label: "UTC"; zone: "UTC" }
        ListElement { label: "America/New_York"; zone: "America/New_York" }
        ListElement { label: "America/Chicago"; zone: "America/Chicago" }
        ListElement { label: "America/Denver"; zone: "America/Denver" }
        ListElement { label: "America/Los_Angeles"; zone: "America/Los_Angeles" }
        ListElement { label: "America/Sao_Paulo"; zone: "America/Sao_Paulo" }
        ListElement { label: "Europe/London"; zone: "Europe/London" }
        ListElement { label: "Europe/Paris"; zone: "Europe/Paris" }
        ListElement { label: "Europe/Berlin"; zone: "Europe/Berlin" }
        ListElement { label: "Europe/Moscow"; zone: "Europe/Moscow" }
        ListElement { label: "Africa/Cairo"; zone: "Africa/Cairo" }
        ListElement { label: "Asia/Dubai"; zone: "Asia/Dubai" }
        ListElement { label: "Asia/Kolkata"; zone: "Asia/Kolkata" }
        ListElement { label: "Asia/Shanghai"; zone: "Asia/Shanghai" }
        ListElement { label: "Asia/Tokyo"; zone: "Asia/Tokyo" }
        ListElement { label: "Australia/Sydney"; zone: "Australia/Sydney" }
        ListElement { label: "Pacific/Auckland"; zone: "Pacific/Auckland" }
        ListElement { label: "Custom IANA zone…"; zone: "__custom__" }
    }

    property int customZoneIndex: zoneModel.count - 1

    // ---------------------------------------------------------------- sync
    function zoneIndexOf(zone) {
        for (var i = 0; i < form.customZoneIndex; i++) {
            if (zoneModel.get(i).zone === zone) {
                return i;
            }
        }
        return form.customZoneIndex;
    }
    function customZoneText() {
        var z = form.cfg.timeZone;
        return (z === "System" || z === "") ? "" : z;
    }
    function syncZone() {
        var idx = zoneIndexOf(form.cfg.timeZone);
        zoneBox.currentIndex = idx;
        zoneField.visible = idx === form.customZoneIndex;
        zoneField.text = idx === form.customZoneIndex ? customZoneText() : "";
        zoneError.visible = false;
    }
    function syncTextField(field, valueFn) {
        field.text = Qt.binding(valueFn);
    }

    Connections {
        target: form.cfg
        function onValueChanged(key) {
            if (key === "timeZone") {
                form.syncZone();
            } else if (key === "peakLabel") {
                form.syncTextField(peakLabelField, function () { return form.cfg.peakLabel; });
            } else if (key === "offPeakLabel") {
                form.syncTextField(offPeakLabelField, function () { return form.cfg.offPeakLabel; });
            } else if (key === "flatLabel") {
                form.syncTextField(flatLabelField, function () { return form.cfg.flatLabel; });
            } else if (key === "peakWindows") {
                form.syncTextField(windowsField, function () { return form.cfg.peakWindows; });
            } else if (key === "showCountdown") {
                countdownBox.checked = Qt.binding(function () { return form.cfg.showCountdown; });
            }
        }
    }

    Component.onCompleted: {
        form.syncZone();
        form.syncTextField(peakLabelField, function () { return form.cfg.peakLabel; });
        form.syncTextField(offPeakLabelField, function () { return form.cfg.offPeakLabel; });
        form.syncTextField(flatLabelField, function () { return form.cfg.flatLabel; });
        form.syncTextField(windowsField, function () { return form.cfg.peakWindows; });
        countdownBox.checked = Qt.binding(function () { return form.cfg.showCountdown; });
    }

    // ---------------------------------------------------------------- ui
    PlasmaComponents3.ScrollView {
        id: scroll
        // Explicit size (not anchors.fill) so the root Item's childrenRect can
        // resolve — an anchored ScrollView leaves the root at 0×0 and the page
        // renders empty.
        width: form.implicitWidth
        height: form.implicitHeight
        implicitWidth: form.implicitWidth
        implicitHeight: form.implicitHeight

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            // ---- Appearance
            PlasmaComponents3.Label {
                text: i18n("Appearance")
                // Qt 6 forbids a whole `font:` assignment together with
                // sub-property assignments in one literal; PC3 Label already
                // uses the system font, so assign only what we change.
                font.bold: true
            }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                columnSpacing: Kirigami.Units.gridUnit
                rowSpacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Peak label")
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents3.TextField {
                    id: peakLabelField
                    Layout.fillWidth: true
                    onEditingFinished: form.cfg.peakLabel = peakLabelField.text;
                }

                PlasmaComponents3.Label {
                    text: i18n("Off-peak label")
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents3.TextField {
                    id: offPeakLabelField
                    Layout.fillWidth: true
                    onEditingFinished: form.cfg.offPeakLabel = offPeakLabelField.text;
                }

                PlasmaComponents3.Label {
                    text: i18n("Flat label")
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents3.TextField {
                    id: flatLabelField
                    Layout.fillWidth: true
                    onEditingFinished: form.cfg.flatLabel = flatLabelField.text;
                }
            }

            ColorSetting {
                labelText: i18n("Peak color")
                colorValue: form.cfg.peakColor
                onApplyColor: form.cfg.peakColor = value;
            }
            ColorSetting {
                labelText: i18n("Off-peak color")
                colorValue: form.cfg.offPeakColor
                onApplyColor: form.cfg.offPeakColor = value;
            }
            ColorSetting {
                labelText: i18n("Flat color")
                colorValue: form.cfg.flatColor
                onApplyColor: form.cfg.flatColor = value;
            }

            // ---- Time zone
            PlasmaComponents3.Label {
                text: i18n("Time zone (display only — billing is always UTC)")
                font.bold: true
            }

            PlasmaComponents3.ComboBox {
                id: zoneBox
                Layout.fillWidth: true
                textRole: "label"
                model: zoneModel
                onActivated: {
                    var z = zoneModel.get(zoneBox.currentIndex).zone;
                    if (z !== "__custom__") {
                        form.cfg.timeZone = z;
                        zoneField.visible = false;
                    } else {
                        zoneField.visible = true;
                        zoneField.text = customZoneText();
                        zoneField.forceActiveFocus();
                    }
                }
            }
            PlasmaComponents3.TextField {
                id: zoneField
                visible: false
                Layout.fillWidth: true
                placeholderText: i18n("IANA zone, e.g. Europe/Berlin")
                onEditingFinished: {
                    var z = zoneField.text.trim();
                    if (z === "") {
                        zoneError.visible = false;
                        zoneField.text = customZoneText();
                        return;
                    }
                    if (Peak.isValidZone(z)) {
                        form.cfg.timeZone = z;
                        zoneError.visible = false;
                    } else {
                        zoneError.visible = true;
                        zoneField.text = customZoneText();
                    }
                }
            }
            PlasmaComponents3.Label {
                id: zoneError
                visible: false
                text: i18n("Not a valid IANA timezone (e.g. Europe/Berlin)")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.negativeTextColor
            }

            // ---- Billing windows
            PlasmaComponents3.Label {
                text: i18n("Peak windows (override)")
                font.bold: true
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                // NB: args go to i18n() itself — .arg() chaining on the result
                // triggers ki18n's "I18N argument missing" error.
                text: i18n("Active: %1 (UTC) — %2",
                    Peak.formatWindows(Peak.applyOverride(form.cfg.peakWindows)),
                    form.cfg.peakWindows !== "" ? i18n("override") : i18n("built-in"));
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.TextField {
                    id: windowsField
                    Layout.fillWidth: true
                    placeholderText: i18n("60-240,360-600 (UTC minutes, half-open; empty = built-in)")
                    onEditingFinished: {
                        var raw = windowsField.text.trim();
                        if (raw === "") {
                            form.cfg.peakWindows = "";
                            windowsError.visible = false;
                            return;
                        }
                        if (Peak.isValidOverride(raw)) {
                            form.cfg.peakWindows = raw;
                            windowsError.visible = false;
                        } else {
                            windowsError.visible = true;
                            form.syncTextField(windowsField, function () { return form.cfg.peakWindows; });
                        }
                    }
                }
                PlasmaComponents3.ToolButton {
                    text: i18n("Reset")
                    onClicked: {
                        form.cfg.peakWindows = "";
                        windowsError.visible = false;
                    }
                }
            }
            PlasmaComponents3.Label {
                id: windowsError
                visible: false
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: i18n("Invalid windows — expected start-end pairs of UTC minutes (half-open), e.g. 60-240,360-600")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.negativeTextColor
            }

            // ---- Behavior
            PlasmaComponents3.CheckBox {
                id: countdownBox
                text: i18n("Show countdown in tooltip and popup")
                onToggled: form.cfg.showCountdown = countdownBox.checked;
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Refresh interval (minutes)")
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents3.SpinBox {
                    id: refreshBox
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    from: 1
                    to: 1440
                    stepSize: 1
                    value: form.cfg.refreshInterval
                    editable: true
                    onValueModified: form.cfg.refreshInterval = refreshBox.value;
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Weekends (Saturdays and Sundays, Beijing Time) are off-peak all day from %1. This override sets the weekday peak windows (UTC, half-open); empty uses the built-in windows.",
                           Peak.WEEKEND_RULE_TEXT)
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Peak/off-peak hours per the official DeepSeek pricing page. All settings are saved automatically.")
            }
        }
    }
}
