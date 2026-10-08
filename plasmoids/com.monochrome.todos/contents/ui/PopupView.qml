/*
 * PopupView — the flyout (full representation), anchored by the shell.
 *
 * Pure view: it holds no state. The applet root owns the model and the
 * mutations; this file emits intent signals and renders what it is given.
 *
 * The add field and the task rows both wrap and auto-grow up to 3 lines; the
 * add field hard-rejects input beyond 3 lines so todos stay short.
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: popup

    property var taskModel: null
    property bool remindersOn: true
    property int pendingCount: 0
    property int doneCount: 0

    signal addRequested(string text)
    signal setDoneRequested(int taskId, bool done)
    signal setPriorityRequested(int taskId, string priority)
    signal clearDoneRequested()
    signal remindersToggled(bool on)

    readonly property int lineCap: 3
    readonly property real threeLineHeight: Kirigami.Units.gridUnit * 3.6
    readonly property var priorities: ["low", "medium", "high"]

    // Reference line for row alignment: the effort pill is a fixed-height box,
    // so its text centre (height/2) is what the checkbox and the task's first
    // line are aligned to.
    readonly property real pillHeight: Kirigami.Units.gridUnit * 1.6
    readonly property font rowFont: Kirigami.Theme.defaultFont
    FontMetrics { id: fm; font: popup.rowFont }

    implicitWidth: Kirigami.Units.gridUnit * 26
    implicitHeight: column.implicitHeight + Kirigami.Units.gridUnit * 2
    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 8

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.smallSpacing

        // ---- header: name left, reminders master switch right ----
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("Todos")
                font.bold: true
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                text: popup.remindersOn ? i18n("Reminders on") : i18n("Reminders off")
                opacity: 0.7
            }
            PlasmaComponents3.Switch {
                checked: popup.remindersOn
                onToggled: popup.remindersToggled(checked)
            }
        }

        // ---- add row: multiline, grows to 3 lines, hard-capped ----
        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.TextArea {
                id: addArea
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight + topPadding + bottomPadding, popup.threeLineHeight)
                Layout.maximumHeight: popup.threeLineHeight
                placeholderText: i18n("Add a task for today…")
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                // Reject input past 3 lines so todos stay short and meaningful.
                onTextChanged: if (lineCount > popup.lineCap) undo()
                // Take Enter before the TextArea turns it into a newline.
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && !(event.modifiers & Qt.ShiftModifier)) {
                        popup.addRequested(addArea.text)
                        addArea.text = ""
                        event.accepted = true
                    }
                }
            }

            PlasmaComponents3.Button {
                text: i18n("Add")
                enabled: addArea.text.trim().length > 0
                Layout.alignment: Qt.AlignTop
                onClicked: {
                    popup.addRequested(addArea.text)
                    addArea.text = ""
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents3.Label {
            visible: popup.taskModel && popup.taskModel.count === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            text: i18n("Nothing planned for today.\nAdd a task above.")
        }

        // ---- task list ----
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 16)
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: popup.taskModel
            interactive: contentHeight > height

            delegate: RowLayout {
                id: rowItem
                width: listView.width
                spacing: Kirigami.Units.smallSpacing
                required property int taskId
                required property string text
                required property string priority
                required property bool done

                // The pill's real height is the alignment reference; fall back
                // to the constant before the first layout pass.
                readonly property real refHeight: pillRow.height > 0 ? pillRow.height : popup.pillHeight

                // checkbox, centred on the reference line (band = one pill tall
                // at the top, so multi-line rows keep it on the first line)
                Item {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: cb.implicitWidth
                    Layout.preferredHeight: rowItem.refHeight
                    PlasmaComponents3.CheckBox {
                        id: cb
                        anchors.verticalCenter: parent.verticalCenter
                        checked: rowItem.done
                        onToggled: popup.setDoneRequested(rowItem.taskId, checked)
                    }
                }

                // Wraps and grows to 3 lines; the FIRST line is centred on the
                // reference line via a top margin, later lines flow below.
                Text {
                    id: taskText
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.max(0, (rowItem.refHeight - fm.height) / 2)
                    text: rowItem.text
                    color: Kirigami.Theme.textColor
                    font.family: popup.rowFont.family
                    font.pixelSize: popup.rowFont.pixelSize
                    font.strikeout: rowItem.done
                    wrapMode: Text.Wrap
                    maximumLineCount: popup.lineCap
                    elide: Text.ElideRight
                    opacity: rowItem.done ? 0.6 : 1.0
                }

                // effort pill: low | medium | high — the alignment reference
                RowLayout {
                    id: pillRow
                    Layout.alignment: Qt.AlignTop
                    spacing: 0
                    Repeater {
                        model: popup.priorities
                        PlasmaComponents3.Button {
                            required property string modelData
                            text: modelData
                            checkable: true
                            checked: rowItem.priority === modelData
                            font: Kirigami.Theme.smallFont
                            Layout.preferredHeight: popup.pillHeight
                            onClicked: popup.setPriorityRequested(rowItem.taskId, modelData)
                        }
                    }
                }
            }
        }

        // ---- footer: cadence legend + clear done ----
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("low 10m · med 30m · high 2h")
                opacity: 0.6
                font: Kirigami.Theme.smallFont
            }
            PlasmaComponents3.Button {
                visible: popup.doneCount > 0
                text: i18np("Clear %1 done", "Clear %1 done", popup.doneCount)
                font: Kirigami.Theme.smallFont
                onClicked: popup.clearDoneRequested()
            }
        }
    }
}
