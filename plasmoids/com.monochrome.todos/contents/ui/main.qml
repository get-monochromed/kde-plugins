/*
 * Todos — Plasma 6 applet root.
 *
 * Popup applet: the compact representation (panel icon + pending badge) sits
 * in the panel; clicking toggles the flyout (full representation).
 *
 * All state lives in a PLAIN JSON FILE so it can be read/edited without the
 * GUI (headless debugging):  ~/.local/state/todos-plasmoid/state.json
 * Schema:
 *   { "version":1, "remindersEnabled":true, "day":"YYYY-MM-DD", "nextId":N,
 *     "tasks":[ {"text":"…","priority":"low|medium|high","done":false,
 *                "lastRemindAt":<epoch_ms>} ] }
 * The file is re-read every few seconds, so external edits are picked up live.
 *
 * Reminders are PER-TASK, driven by the effort pill:
 *   low -> every 10 min, medium -> every 30 min, high -> every 2 h.
 * A 1-minute tick reminds every pending task whose cadence has elapsed and
 * bundles everything due that minute into a single notification.
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasma5support 2.0 as P5Support

PlasmoidItem {
    id: root

    // Popup applet: MUST prefer the compact representation, otherwise libplasma
    // parents the full representation inline into the panel (no popup).
    preferredRepresentation: compactRepresentation

    // Constant panel size hints (the shell reads Layout.*, and sizing these
    // from the compact item at load time logs "undefined to double").
    readonly property int compactIconSize: Kirigami.Units.iconSizes.smallMedium
    readonly property int compactWidth: compactIconSize + Kirigami.Units.smallSpacing * 2

    Layout.fillHeight: true
    Layout.preferredWidth: compactWidth
    Layout.preferredHeight: compactIconSize
    Layout.minimumWidth: compactWidth
    Layout.maximumWidth: 32767

    // ---------------------------------------------------------------- state
    ListModel { id: tasksModel }

    property bool remindersOn: true
    property string day: ""
    property int _nextId: 1
    property bool loaded: false
    property string lastSerialized: ""   // content we last wrote/read
    property int pending: 0
    property int doneCount: 0

    readonly property string defaultStatePath: "${HOME}/.local/state/todos-plasmoid/state.json"
    readonly property string statePath: {
        var p = plasmoid.configuration.stateFile
        return (typeof p === "string" && p.length > 0) ? p : defaultStatePath
    }
    readonly property string qPath: "\"" + statePath + "\""
    readonly property string qDir: "\"" + statePath.replace(/\/[^\/]*$/, "") + "\""

    // Also creates the directory on first run.
    readonly property string readCmd: "mkdir -p " + qDir + " && cat " + qPath + " 2>/dev/null"

    function intervalMs(priority) {
        if (priority === "low") return 10 * 60000
        if (priority === "high") return 120 * 60000
        return 30 * 60000 // medium
    }

    function dayKey(d) {
        var m = String(d.getMonth() + 1)
        var dd = String(d.getDate())
        if (m.length < 2) m = "0" + m
        if (dd.length < 2) dd = "0" + dd
        return d.getFullYear() + "-" + m + "-" + dd
    }
    function today() { return dayKey(new Date()) }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function refreshCounts() {
        var p = 0, d = 0
        for (var i = 0; i < tasksModel.count; i++) {
            if (tasksModel.get(i).done) d++
            else p++
        }
        root.pending = p
        root.doneCount = d
    }

    // ------------------------------------------------- executable data engine
    P5Support.DataSource {
        id: engine
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            engine.disconnectSource(sourceName)
            if (sourceName === root.readCmd) root.adopt(String(data["stdout"] || ""))
        }
    }
    function exec(cmd) {
        engine.disconnectSource(cmd)
        engine.connectSource(cmd)
    }

    // ------------------------------------------------------------ state IO
    function serialize() {
        var out = []
        for (var i = 0; i < tasksModel.count; i++) {
            var r = tasksModel.get(i)
            out.push({ text: r.text, priority: r.priority, done: r.done, lastRemindAt: Number(r.lastRemindAt) || 0 })
        }
        return JSON.stringify({
            version: 1,
            remindersEnabled: root.remindersOn,
            day: root.day,
            nextId: root._nextId,
            tasks: out
        }, null, 2)
    }

    function adopt(raw) {
        var txt = String(raw || "").trim()
        if (txt === "") {
            if (!root.loaded) {           // first run, no file yet
                root.day = root.today()
                root._nextId = 1
                tasksModel.clear()
                root.refreshCounts()
                root.loaded = true
            }
            return
        }
        if (txt === root.lastSerialized) return   // our own write, ignore
        var d = null
        try { d = JSON.parse(txt) } catch (e) { console.warn("todos: bad state json: " + e); return }
        if (!d || d.version !== 1) return

        root.lastSerialized = txt
        tasksModel.clear()
        root.remindersOn = d.remindersEnabled !== false
        root.day = String(d.day || root.today())
        root._nextId = Math.max(1, Math.round(Number(d.nextId) || 1))
        var arr = Array.isArray(d.tasks) ? d.tasks : []
        for (var i = 0; i < arr.length; i++) {
            var e = arr[i]
            tasksModel.append({
                taskId: root._nextId++,
                text: String(e.text || ""),
                priority: (e.priority === "low" || e.priority === "high") ? e.priority : "medium",
                done: !!e.done,
                lastRemindAt: Number(e.lastRemindAt) > 0 ? Number(e.lastRemindAt) : Date.now()
            })
        }
        root.refreshCounts()
        root.loaded = true
        root.rollover()
    }

    function writeState() {
        var json = root.serialize()
        root.lastSerialized = json
        root.exec("printf %s " + root.shellQuote(json) + " > " + root.qPath)
    }
    function save() { saveTimer.restart() }

    Timer { id: saveTimer; interval: 500; repeat: false; onTriggered: root.writeState() }

    // ------------------------------------------------------------ mutations
    function addTask(text) {
        var t = String(text || "").replace(/\s*\n\s*/g, " ").trim()
        if (t === "") return
        tasksModel.append({ taskId: _nextId++, text: t, priority: "medium", done: false, lastRemindAt: Date.now() })
        refreshCounts(); save()
    }
    function setDone(taskId, done) {
        for (var i = 0; i < tasksModel.count; i++) {
            if (tasksModel.get(i).taskId === taskId) {
                tasksModel.setProperty(i, "done", !!done)
                break
            }
        }
        refreshCounts(); save()
    }
    function setPriority(taskId, priority) {
        var p = (priority === "low" || priority === "medium" || priority === "high") ? priority : "medium"
        for (var i = 0; i < tasksModel.count; i++) {
            if (tasksModel.get(i).taskId === taskId) {
                tasksModel.setProperty(i, "priority", p)
                tasksModel.setProperty(i, "lastRemindAt", Date.now())  // restart its clock
                break
            }
        }
        save()
    }
    function clearDone() {
        for (var i = tasksModel.count - 1; i >= 0; i--)
            if (tasksModel.get(i).done) tasksModel.remove(i)
        refreshCounts(); save()
    }
    function setRemindersOn(on) { root.remindersOn = !!on; save() }

    // ------------------------------------------------ rollover + reminders
    function rollover() {
        if (!root.loaded) return
        var t = root.today()
        if (root.day === t) return
        var keep = []
        for (var i = 0; i < tasksModel.count; i++) {
            var r = tasksModel.get(i)
            if (!r.done) keep.push({ text: r.text, priority: r.priority })
        }
        tasksModel.clear()
        for (var j = 0; j < keep.length; j++)
            tasksModel.append({ taskId: _nextId++, text: keep[j].text, priority: keep[j].priority, done: false, lastRemindAt: Date.now() })
        root.day = t
        refreshCounts(); save()
    }

    function schedulerTick() {
        if (!root.remindersOn || root.pending <= 0) return
        var now = Date.now()
        var due = []
        for (var i = 0; i < tasksModel.count; i++) {
            var r = tasksModel.get(i)
            if (r.done) continue
            if (now - (Number(r.lastRemindAt) || 0) >= intervalMs(r.priority)) due.push(i)
        }
        if (due.length === 0) return
        var lines = []
        for (var j = 0; j < due.length; j++) {
            lines.push("  •  " + tasksModel.get(due[j]).text)
            tasksModel.setProperty(due[j], "lastRemindAt", now)
        }
        refreshCounts(); save()
        var headline = due.length === 1 ? "1 to-do needs your attention"
                                       : due.length + " to-dos need your attention"
        root.exec("notify-send -a " + shellQuote("Todos") + " " + shellQuote(headline) + " " + shellQuote(lines.join("\n")))
    }

    Timer {
        id: tickTimer
        interval: 60000
        repeat: true
        running: root.loaded
        onTriggered: { root.schedulerTick(); root.rollover() }
    }

    // Live external edits: re-read the JSON file periodically.
    Timer {
        id: pollTimer
        interval: 4000
        repeat: true
        running: root.loaded
        onTriggered: root.exec(root.readCmd)
    }

    Component.onCompleted: root.exec(root.readCmd)

    // ------------------------------------------------------------- tooltip
    toolTipMainText: i18n("Todos")
    toolTipSubText: root.pending === 0 ? i18n("No tasks pending")
                                       : i18np("%1 task pending", "%1 tasks pending", root.pending)

    // ------------------------------------------------------ panel (compact)
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property bool wasExpanded

        // Constant, content-derived size hints. The shell reads Layout.*, not
        // implicit sizes — and sizing from a positioner can be 0 on the first
        // pass, collapsing the applet in the panel.
        readonly property int s: Kirigami.Units.iconSizes.smallMedium
        Layout.fillHeight: true
        Layout.preferredWidth: s + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: s
        Layout.minimumWidth: s + Kirigami.Units.smallSpacing * 2
        implicitWidth: s + Kirigami.Units.smallSpacing * 2
        implicitHeight: s

        Accessible.role: Accessible.Button
        Accessible.onPressAction: root.expanded = !root.expanded

        // Read `expanded` on press: when the popup is open the shell closes it
        // before the click arrives, so toggling from the post-close state would
        // reopen instead of close.
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Kirigami.Icon {
            anchors.centerIn: parent
            width: compact.s
            height: compact.s
            source: "view-task"
            color: root.pending > 0 ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

        Rectangle {
            visible: root.pending > 0
            anchors.right: parent.right
            anchors.top: parent.top
            width: badgeLabel.implicitWidth + Kirigami.Units.smallSpacing
            height: badgeLabel.implicitHeight
            radius: height / 2
            color: Kirigami.Theme.highlightColor
            PlasmaComponents3.Label {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.pending
                color: Kirigami.Theme.highlightedTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }

    // ------------------------------------------------------- flyout (full)
    fullRepresentation: PopupView {
        taskModel: tasksModel
        remindersOn: root.remindersOn
        pendingCount: root.pending
        doneCount: root.doneCount
        onAddRequested: function(text) { root.addTask(text) }
        onSetDoneRequested: function(taskId, done) { root.setDone(taskId, done) }
        onSetPriorityRequested: function(taskId, priority) { root.setPriority(taskId, priority) }
        onClearDoneRequested: root.clearDone()
        onRemindersToggled: function(on) { root.setRemindersOn(on) }
    }
}
