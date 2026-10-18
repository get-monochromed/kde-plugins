# AGENTS.md — kde-plugins

Personal KDE Plasma 6 add-ons: two QML panel applets, a KWin 6 script, two Dolphin
service menus, and one modified third-party applet fork. Plasma 6 / Qt6 only.

## Layout

| Plugin | Type | Id | What it does | Path |
|---|---|---|---|---|
| Todos | Plasma applet | `com.monochrome.todos` | Daily to-do list in a popup flyout; per-task check-in reminders (low 10 min / medium 30 min / high 2 h), bundled into one notification per minute | `plasmoids/com.monochrome.todos/` |
| Wattage | Plasma applet | `com.monochrome.wattage` | Panel-only battery wattage (`-7.4 W` / `+42.0 W` / `0.0 W`); hover shows 1-min, 5-min and since-login averages plus 15-min min/max, %, time to empty/full. No flyout | `plasmoids/com.monochrome.wattage/` |
| Center Window | KWin 6 script | `center-window-above-dock` | Centers the active window in the work area (panel struts excluded) and raises it by a configurable offset so a bottom dock doesn't cover it; bound to Meta+C | `kwin-scripts/center-window-above-dock/` |
| Send via Packet / LocalSend | Dolphin service menus + systemd user unit | `dolphin-send-via/` | Right-click a file → hand it to Packet (Quick Share) or LocalSend with it attached; a watchdog keeps both running from login | `dolphin-send-via/` |
| DeepSeek Peak-Time Clock | Plasma applet (**fork**) | `com.sarah.deepseek-peak-clock` | Peak/off-peak DeepSeek API billing state with a 24-hour UTC dial. **Sarah Schmidt's work, not ours** | `plasmoids/com.sarah.deepseek-peak-clock/` |

Applet internals: `main.qml` is the root `PlasmoidItem`; Todos keeps its flyout in
`PopupView.qml` (view only — emits intent signals, holds no state). Wattage reads
`/sys/class/power_supply/{BAT0,AC}/uevent` every second — the raw kernel value,
deliberately *not* UPower's smoothed `energy-rate` (what the stock System Monitor
sensor shows, and why it looks frozen).

### Todos state is a plain JSON file — this is the AI-drivable path

`~/.local/state/todos-plasmoid/state.json` (override via the `stateFile` config key):

```json
{ "version": 1, "remindersEnabled": true, "day": "YYYY-MM-DD", "nextId": 54,
  "tasks": [ { "text": "…", "priority": "low|medium|high", "done": false,
               "lastRemindAt": 1792348205379 } ] }
```

The applet re-reads it every few seconds, so external edits take effect live with no
plasmashell restart. `lastRemindAt` is epoch milliseconds; `nextId` must exceed every
task id; don't add fields without bumping `version` and tolerating their absence.

## Install / update / verify

```bash
# fresh install (fails if already installed)
kpackagetool6 -t Plasma/Applet -i plasmoids/com.monochrome.todos
kpackagetool6 -t Plasma/Applet -i plasmoids/com.monochrome.wattage
kpackagetool6 -t Plasma/Applet -i plasmoids/com.sarah.deepseek-peak-clock
kpackagetool6 -t KWin/Script  -i kwin-scripts/center-window-above-dock
# update an existing install — this is the normal iteration loop
kpackagetool6 -t Plasma/Applet -u plasmoids/com.monochrome.todos
kpackagetool6 -t Plasma/Applet -u plasmoids/com.monochrome.wattage
kpackagetool6 -t KWin/Script  -u kwin-scripts/center-window-above-dock
qdbus-qt6 org.kde.KWin /KWin reconfigure     # reload the KWin script

# applet changes need a shell restart to be visible
kquitapp6 plasmashell; plasmashell & disown
journalctl -f -o cat /usr/bin/plasmashell   # watch QML errors while it loads

# Dolphin menus: installing is the update path (idempotent)
./dolphin-send-via/install.sh
./dolphin-send-via/install.sh --uninstall
```

Destinations: `~/.local/share/plasma/plasmoids/<id>/`, `~/.local/share/kwin/scripts/<id>/`,
`~/.local/share/kio/servicemenus/*.desktop`, `~/.local/bin/send-{via,ensure}`,
`~/.config/systemd/user/send-apps.service`.

KWin test driver: `center-window status|offset <px>|reload|apply` in `~/.local/bin`
(greps the journal for `[center-window]`). **Untracked — exists only on this machine**;
don't cite it from committed docs as if it shipped.

## Hard rules / invariants

- **Attribution is not negotiable.** `com.sarah.deepseek-peak-clock` forks Sarah
  Schmidt's MIT plasmoid (base tag `v2.7.0`, commit
  `931e41721ec0955f1b390a9477e7fceb76dd606c`). Keep `metadata.json`'s id, `Website`
  and `BugReportUrl` pointing upstream, keep the upstream `LICENSE`, and never present
  it as original work.
- **Never "clean up" upstream files in the fork.** `peak.js`, `PopupView.qml`,
  `PieClock.qml` and `config/config.qml` are upstream's byte for byte. Local changes
  are exactly: added `DeepSeekIcon.qml`, rewrote `StatusIndicator.qml`, edited
  `main.qml`, dropped the `mode` entry and its combo box. Any further divergence gets
  documented in `UPSTREAM.md` first.
- **Plugin ids are the install identity.** The fork keeps the upstream id, so it
  *replaces* an upstream install in place; renaming an id orphans panel config.
- **`-i` fails when the plugin exists; use `-u`.** Installers must not assume a clean machine.
- **QML panel sizing comes from the root's `Layout.*` hints** computed from constants
  and `TextMetrics` — never from the compact item or a positioner.
- **No new runtime dependencies** beyond Plasma 6, `gdbus` (glib2), `flatpak`, the two apps.
- Own plugins are MIT © monochrome (`LICENSE`); the fork keeps Sarah's MIT and our
  modifications are released under the same terms.

## Pitfalls (each already cost a misdiagnosis)

- A popup applet **must** set `preferredRepresentation: compactRepresentation`, else
  libplasma parents the full representation inline into the panel and there is no popup.
- An applet with **no** full representation counts as "always expanded" and then draws
  nothing. Fix: a dummy placeholder `fullRepresentation` (Wattage does this) plus
  `activationTogglesExpanded: false` so a click never opens a flyout.
- Sizing from the compact item logs `undefined to double` and can collapse the applet
  to zero on the first layout pass; compute `Layout.*` from `Kirigami.Units`/`TextMetrics`.
- KWin: use `console.info` — `console.log`/`print` go to a filtered debug channel and
  vanish. Log every move as `[center-window] …` so the journal is verifiable.
- Reloading a plain-JS KWin script: `loadScript(filePath, pluginName)` wants the `.js`
  **file path** (a package name is treated as a path and fails silently), and
  `unloadScript` deletes via `deleteLater()` — poll `isScriptLoaded` until it's gone,
  or `loadScript` returns -1.
- A dock reserving no strut space ("windows can cover" / auto-hide) is invisible to
  `KWin.clientArea()`; find it as a dock window and use its top edge as the lower bound.
- Dolphin menus must be **executable** (KIO silently refuses otherwise) and need
  `kbuildsycoca6 --noincremental` afterwards.
- Packet has no file CLI: the menu calls its GAction (`org.gtk.Actions.Activate` →
  `send-files` on `/io/github/nozwock/Packet/Share`). Its sandbox only exposes
  `~/Downloads` (hence the read-only override) and it **cannot send folders**.
- LocalSend: `flatpak run --file-forwarding @@ <paths> @@` with **plain** paths — its
  GUI parses argv paths and does not understand `file://` URIs.
- Both apps move into their own `app-flatpak-*.scope`, so a unit wrapping `flatpak run`
  does not own them; `send-ensure` is a 30 s poll (`gdbus NameHasOwner` / `pgrep`).

## Conventions

- Commit subjects in the imperative, scoped where useful:
  `todos applet: keep the chrome fixed when the flyout is resized`,
  `Add Dolphin "Send via Packet / LocalSend" service menus`.
- Comment **why**, not what. Several comments record a real misdiagnosis — keep them
  when refactoring, and add one when you fix something non-obvious.
- Keep the README user-facing and this file agent-facing; update both when install
  commands, paths or ids change. Verify with real tool output (`command -v`,
  `journalctl`, `kpackagetool6 -l`) instead of assuming a tool or path exists.
