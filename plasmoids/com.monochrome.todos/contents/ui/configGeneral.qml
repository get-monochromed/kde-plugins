/*
 * Settings form. All Todos data lives in a plain JSON file (see main.qml);
 * this page only exposes its path so it can be relocated, plus documents the
 * headless debugging path.
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: form

    // Size the root from childrenRect: a bare Item that only anchors a
    // ScrollView collapses to 0x0 and the tab renders empty.
    width: childrenRect.width
    height: childrenRect.height
    implicitWidth: Kirigami.Units.gridUnit * 32
    implicitHeight: Kirigami.Units.gridUnit * 12

    ColumnLayout {
        id: col
        width: form.width
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: i18n("State file")
            font.bold: true
        }

        PlasmaComponents3.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 30
            wrapMode: Text.Wrap
            opacity: 0.75
            font: Kirigami.Theme.smallFont
            text: i18n("Tasks are stored as plain JSON so they can be read or edited without the UI. Leave empty for the default. The widget re-reads this file every few seconds, so external edits appear live.")
        }

        PlasmaComponents3.TextField {
            id: pathField
            Layout.preferredWidth: Kirigami.Units.gridUnit * 30
            placeholderText: "~/.local/state/todos-plasmoid/state.json"
            text: plasmoid.configuration.stateFile
            onEditingFinished: plasmoid.configuration.stateFile = text
        }
    }
}
