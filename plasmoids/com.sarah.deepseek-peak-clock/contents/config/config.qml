/*
 * Settings form (contents/config/config.qml).
 *
 * This file is the ConfigModel: it declares the configuration categories
 * (tabs) shown in the shell's "Configure…" dialog (right-click the widget →
 * Configure…). The actual controls live in configGeneral.qml (in
 * contents/ui/, where ConfigCategory.source resolves — NOT contents/config/),
 * which the shell loads (with `plasmoid.configuration` in scope) as the form.
 *
 * All controls in configGeneral.qml read/write plasmoid.configuration.<key>
 * directly: KConfig persists every write and emits valueChanged, which
 * main.qml listens to — so settings are live.
 */
import QtQuick 2.0
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    // No explicit "About" category: the shell's AppletConfiguration appends
    // its own About tab (loading AboutPlugin.qml from the plasma-desktop
    // package) that renders only `Plasmoid.metaData` fields from
    // metadata.json — name, version (glued to name in the heading),
    // description, Website, BugReportUrl, copyrightText, license, authors,
    // otherContributors, translators. Defining a custom "About" ConfigCategory
    // here would only add a second, duplicate About tab.
}
