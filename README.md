# kde-plugins

My personal KDE Plasma 6 add-ons — two panel applets, one KWin script, a pair of Dolphin service menus, and a locally modified fork of a third-party applet.

| Plugin | Type | Id | What it does |
|---|---|---|---|
| **Todos** | Plasma applet | `com.monochrome.todos` | Daily to-do list with per-task check-in reminders (low every 10 min, medium every 30 min, high every 2 h). |
| **Wattage** | Plasma applet | `com.monochrome.wattage` | Minimal battery wattage readout — `-x W` draining / `+x W` charging, with averages on hover. |
| **Center Window (above panels)** | KWin script | `center-window-above-dock` | Centers the active window in the screen's usable area (panels excluded) and nudges it up by a configurable offset so it clears a bottom dock. |
| **Send via Packet / LocalSend** | Dolphin service menus + systemd user unit | `dolphin-send-via/` | Right-click any file in Dolphin and hand it to Packet (Quick Share) or LocalSend with the file already attached. Ships a watchdog unit that keeps both apps running from login, since their own "start on login" toggles are unreliable. |
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

## Install — Dolphin service menus

Separate from the applets: the two context-menu entries plus the background unit.
Both apps must be installed as Flatpak first:

```bash
flatpak install flathub io.github.nozwock.Packet org.localsend.localsend_app
```

Then, from the repo root:

```bash
./dolphin-send-via/install.sh
```

The script writes the helper scripts, the two `.desktop` service menus and the systemd
user unit, chmods the menu files (KIO refuses a user-local service menu that is not
executable), refreshes KIO's cache, enables `send-apps.service`, and grants Packet
read-only access to the host filesystem — Packet's stock sandbox only exposes
`~/Downloads`, so files anywhere else would fail to open.

What each entry does:

- **Send via Packet** — there is no Packet CLI for files, so this calls the GAction Packet
  exports for its own Nautilus plugin (`org.gtk.Actions.Activate` → `send-files`) on
  `/io/github/nozwock/Packet/Share`.
- **Send via LocalSend** — `flatpak run --file-forwarding … @@ <paths> @@`, which exports
  the selection through the document portal so the sandbox needs no extra permission.

Requires `gdbus` (glib2) and Plasma 6's `kbuildsycoca6`.

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

The Dolphin service menus are plain file installs, so re-running the installer is the
update path — it overwrites the scripts, menus and unit in place and restarts the unit:

```bash
./dolphin-send-via/install.sh
```

## Uninstall

```bash
kpackagetool6 -t Plasma/Applet --remove com.monochrome.todos
kpackagetool6 -t Plasma/Applet --remove com.monochrome.wattage
kpackagetool6 -t Plasma/Applet --remove com.sarah.deepseek-peak-clock
kpackagetool6 -t KWin/Script   --remove center-window-above-dock

./dolphin-send-via/install.sh --uninstall
```

`--uninstall` also drops the Packet filesystem override. Packet and LocalSend keep running
until you close them (they are Flatpak apps in their own scopes): `pkill -x packet;
pkill -x localsend`.

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
| Dolphin service menu | `~/.local/share/kio/servicemenus/<name>.desktop` |
| Helper scripts | `~/.local/bin/send-via`, `~/.local/bin/send-ensure` |
| systemd user unit | `~/.config/systemd/user/send-apps.service` |

So a bare-metal way to install without `kpackagetool6` is just copying the directories to those paths — but `kpackagetool6` is the supported route.

## License

My own plugins (Todos, Wattage, Center Window, Dolphin send-via) are MIT — see [LICENSE](LICENSE).

The forked DeepSeek Peak-Time Clock keeps its upstream license: MIT © 2026 Sarah Schmidt — see its own [LICENSE](plasmoids/com.sarah.deepseek-peak-clock/LICENSE). My modifications to it are released under the same terms.
