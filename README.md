# kde-plugins

My personal KDE Plasma 6 plugins — two panel applets and one KWin script.

| Plugin | Type | Id | What it does |
|---|---|---|---|
| **Todos** | Plasma applet | `com.monochrome.todos` | Daily to-do list with per-task check-in reminders (low every 10 min, medium every 30 min, high every 2 h). |
| **Wattage** | Plasma applet | `com.monochrome.wattage` | Minimal battery wattage readout — `-x W` draining / `+x W` charging, with averages on hover. |
| **Center Window (above panels)** | KWin script | `center-window-above-dock` | Centers the active window in the screen's usable area (panels excluded) and nudges it up by a configurable offset so it clears a bottom dock. |

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
```

Then add the applets to a panel: right-click the panel → **Add Widgets…** → search "Todos" / "Wattage".
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
kpackagetool6 -t KWin/Script   -u kwin-scripts/center-window-above-dock

qdbus-qt6 org.kde.KWin /KWin reconfigure   # reload the KWin script
```

## Uninstall

```bash
kpackagetool6 -t Plasma/Applet --remove com.monochrome.todos
kpackagetool6 -t Plasma/Applet --remove com.monochrome.wattage
kpackagetool6 -t KWin/Script   --remove center-window-above-dock
```

## Where things get installed

| Type | Destination |
|---|---|
| Plasma applet | `~/.local/share/plasma/plasmoids/<id>/` |
| KWin script | `~/.local/share/kwin/scripts/<id>/` |

So a bare-metal way to install without `kpackagetool6` is just copying the directories to those paths — but `kpackagetool6` is the supported route.

## License

MIT — see [LICENSE](LICENSE).
