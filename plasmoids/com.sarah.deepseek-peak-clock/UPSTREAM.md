# Fork notice — DeepSeek Peak-Time Clock

This directory is a **modified copy of someone else's plasmoid**, not original work of mine.

- **Original project:** DeepSeek Peak-Time Clock by **Sarah Schmidt** (GitHub: `SAI-DAEMON`)
- **Upstream repository:** https://github.com/Sai-daemon/KDE-Deepseek-Peaktime-clock
- **Marketplace page:** https://www.opendesktop.org/p/2368817
- **License:** MIT © 2026 Sarah Schmidt (see [`LICENSE`](LICENSE) in this directory)
- **Base revision:** tag `v2.7.0` — commit `931e41721ec0955f1b390a9477e7fceb76dd606c`
- **Not affiliated with or endorsed by the upstream author.** All credit for the widget itself goes upstream; bug reports about the underlying behaviour belong in the upstream issue tracker (still referenced from `metadata.json`).

## What I changed

Panel appearance and one settings option only. Everything else — the billing logic, the flyout, the settings form — is upstream's, byte for byte.

| File | Change |
|---|---|
| `contents/ui/DeepSeekIcon.qml` | **Added.** The DeepSeek whale mark, drawn as a `Shape` so it can be tinted with the panel's text colour (an `Image`/`IconItem` can't be tinted). Path data is the official DeepSeek mark from simple-icons (24×24 viewBox, MIT). |
| `contents/ui/StatusIndicator.qml` | **Rewritten.** Upstream was a phase-coloured dot with a pulsing glow plus a bold coloured `PEAK` / `OFF-PEAK` label, sized via `TextMetrics`. Now it is just the whale: full brightness during peak hours, dimmed off-peak, with fixed content-derived sizing. |
| `contents/ui/main.qml` | Panel representation hands `peak: root.phaseName === "peak"` to the indicator instead of colour + label text; comments updated. The flyout is untouched — colour and text status still live there and in the hover tooltip. |
| `contents/config/main.xml` | Dropped the `mode` entry (panel `regular` dot+text vs `compact` dot). With the panel showing only the whale there is no panel text left to toggle; the label/colour entries now affect the flyout, the dial and the tooltip only. |
| `contents/ui/configGeneral.qml` | Dropped the matching "Display mode" combo box and its sync logic. |

**Not touched:** `contents/ui/peak.js` (billing rules), `contents/ui/PopupView.qml`, `contents/ui/PieClock.qml`, `contents/config/config.qml`, `metadata.json`. The plugin id stays `com.sarah.deepseek-peak-clock`, so installing this **replaces an existing upstream install in place** rather than sitting beside it.

One oddity: `contents/ui/configAbout.qml` exists in the copy I run but **not** in upstream v2.7.0, and nothing loads it — `contents/config/config.qml` deliberately declares no "About" category (its own comment explains why: the shell appends one). It looks like an unused leftover and still carries an upstream placeholder URL (`https://github.com/your-org/your-repo/issues`). Kept here for fidelity with what's installed; delete it if you want a clean tree.

## Diff it against upstream yourself

```bash
git clone --branch v2.7.0 --depth 1 https://github.com/Sai-daemon/KDE-Deepseek-Peaktime-clock /tmp/ds-upstream
diff -ru /tmp/ds-upstream plasmoids/com.sarah.deepseek-peak-clock \
  --exclude='.git' --exclude='.github' --exclude='.gitattributes' --exclude='.gitignore' \
  --exclude='README.md' --exclude='install.sh' --exclude='LICENSE'
```

Expected: 5 files (1 added, 4 modified) plus `configAbout.qml` on this side only.

## Install

```bash
kpackagetool6 -t Plasma/Applet -i plasmoids/com.sarah.deepseek-peak-clock   # fresh
kpackagetool6 -t Plasma/Applet -u plasmoids/com.sarah.deepseek-peak-clock   # upgrade existing
```
