# kde-plugins

My personal KDE Plasma 6 plugins — two panel applets, one KWin script, and a locally modified fork of a third-party applet.

| Plugin | Type | Id | What it does |
|---|---|---|---|
| **Todos** | Plasma applet | `com.monochrome.todos` | Daily to-do list with per-task check-in reminders (low every 10 min, medium every 30 min, high every 2 h). |
| **Wattage** | Plasma applet | `com.monochrome.wattage` | Minimal battery wattage readout — `-x W` draining / `+x W` charging, with averages on hover. |
| **Center Window (above panels)** | KWin script | `center-window-above-dock` | Centers the active window in the screen's usable area (panels excluded) and nudges it up by a configurable offset so it clears a bottom dock. |
| **DeepSeek Peak-Time Clock** *(fork, see below)* | Plasma applet | `com.sarah.deepseek-peak-clock` | Shows whether DeepSeek API billing is peak or off-peak, with a 24-hour dial of the official UTC windows. **Not my work** — a modified copy of Sarah Schmidt's plasmoid. |

Requires Plasma 6 (`kpackagetool6`, shipped with Plasma 6).

## Install

Copy-paste the whole block into a terminal on a Plasma 6 machine:

```bash
git clone https://github.com/get-monochromed/kde-plugins.git && cd kde-plugins

# Plasma applets
kpackagetool6 -t Plasma/Applet -i plasmoids/com.monochrome.todos
kpackagetool6 -t Plasma/Applet -i plasmoids/com.monochrome.wattage

# KWin script
kpackagetool6 -t KWin/Script -i kwin-scripts/center-window-above-dock

# Forked applet (optional — replaces the upstream applet with the same id)
kpackagetool6 -t Plasma/Applet -i plasmoids/com.sarah.deepseek-peak-clock
```

Then add the applets to a panel: right-click the panel → **Add Widgets…** → search "Todos" / "Wattage" / "DeepSeek".
Enable the KWin script: **System Settings → Window Management → KWin Scripts** → tick *Center Window (above panels)*.

If the applets don't show up, restart plasmashell:

```bash
kquitapp6 plasmashell; plasmashell & disown
```

## Reinstall / update

`kpackagetool6 -i` fails when the plugin is already installed. Use `-u` to overwrite an existing install:

```bash
cd kde-plugins && git pull

kpackagetool6 -t Plasma/Applet -u plasmoids/com.monochrome.todos
kpackagetool6 -t Plasma/Applet -u plasmoids/com.monochrome.wattage
kpackagetool6 -t Plasma/Applet -u plasmoids/com.sarah.deepseek-peak-clock
kpackagetool6 -t KWin/Script   -u kwin-scripts/center-window-above-dock

qdbus-qt6 org.kde.KWin /KWin reconfigure   # reload the KWin script
```

## Uninstall

```bash
kpackagetool6 -t Plasma/Applet --remove com.monochrome.todos
kpackagetool6 -t Plasma/Applet --remove com.monochrome.wattage
kpackagetool6 -t Plasma/Applet --remove com.sarah.deepseek-peak-clock
kpackagetool6 -t KWin/Script   --remove center-window-above-dock
```

## Forked plugin — attribution

`plasmoids/com.sarah.deepseek-peak-clock/` is **not my original work**. It is Sarah Schmidt's *DeepSeek Peak-Time Clock*, MIT licensed, with a few local changes of mine (panel shows the DeepSeek whale instead of a status dot + text label; the regular/compact display-mode option is gone).

- **Original source:** https://github.com/Sai-daemon/KDE-Deepseek-Peaktime-clock
- **Marketplace page:** https://www.opendesktop.org/p/2368817
- **Base version:** upstream tag `v2.7.0` (commit `931e41721ec0955f1b390a9477e7fceb76dd606c`)
- **Upstream author's metadata is untouched** — the plugin id, `Website` and `BugReportUrl` in `metadata.json` still point at the original repo, so bugs in the underlying widget belong upstream.

Exactly what I changed, and how to diff against upstream yourself: see [`plasmoids/com.sarah.deepseek-peak-clock/UPSTREAM.md`](plasmoids/com.sarah.deepseek-peak-clock/UPSTREAM.md).

## Where things get installed

| Type | Destination |
|---|---|
| Plasma applet | `~/.local/share/plasma/plasmoids/<id>/` |
| KWin script | `~/.local/share/kwin/scripts/<id>/` |

So a bare-metal way to install without `kpackagetool6` is just copying the directories to those paths — but `kpackagetool6` is the supported route.

## License

My own plugins (Todos, Wattage, Center Window) are MIT — see [LICENSE](LICENSE).

The forked DeepSeek Peak-Time Clock keeps its upstream license: MIT © 2026 Sarah Schmidt — see its own [LICENSE](plasmoids/com.sarah.deepseek-peak-clock/LICENSE). My modifications to it are released under the same terms.
