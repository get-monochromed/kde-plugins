/*
 * About settings page (contents/ui/configAbout.qml).
 *
 * Loaded by the shell's "Configure…" dialog via config.qml's ConfigModel as a
 * second category ("About"). Shows the current version and an issue/report
 * link (GitHub URL to be filled in later).
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: about

    width: childrenRect.width
    height: childrenRect.height
    implicitWidth: Kirigami.Units.gridUnit * 30
    implicitHeight: Kirigami.Units.gridUnit * 18

    // GitHub repository (to be filled in later — placeholder for now).
    readonly property string issuesUrl: "https://github.com/your-org/your-repo/issues"

    // Version: prefer the package metadata; fall back to a literal so the
    // page is never blank on engines where metaData.version is unavailable.
    readonly property string versionText: {
        try {
            var v = plasmoid.metaData.version;
            return v ? v : "2.3";
        } catch (e) {
            return "2.3";
        }
    }

    ColumnLayout {
        width: about.implicitWidth
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: i18n("DeepSeek Peak-Time Clock")
            font.bold: true
        }

        PlasmaComponents3.Label {
            text: i18n("Version %1", about.versionText)
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Shows whether DeepSeek API billing is currently peak or off-peak, with a 24-hour dial of the official UTC windows.")
            color: Kirigami.Theme.disabledTextColor
        }

        PlasmaComponents3.Label {
            text: i18n("Found an issue or want a change?")
            font.bold: true
        }

        // The URL is set by `about.issuesUrl` — a plain read-only label until
        // the real repository address is filled in.
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: about.issuesUrl
            color: Kirigami.Theme.linkColor
        }
    }
}
