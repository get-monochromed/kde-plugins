#!/usr/bin/env bash
# install.sh — install/uninstall the "Send via Packet / LocalSend" Dolphin
# service menus and the systemd user unit that keeps both apps running.
#
#   ./install.sh              install or upgrade (idempotent)
#   ./install.sh --uninstall  remove everything it installed
#
# Both source apps are Flatpak (io.github.nozwock.Packet,
# org.localsend.localsend_app), so flatpak must be present.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
bin_dir="$HOME/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

menu_dir="$data_home/kio/servicemenus"

PACKET_APP=io.github.nozwock.Packet
LOCALSEND_APP=org.localsend.localsend_app

say() { printf '%s\n' "$*"; }

uninstall() {
    say "== removing service menu entries"
    rm -f "$menu_dir/send-via-packet.desktop" "$menu_dir/send-via-localsend.desktop"

    say "== stopping and removing the systemd user unit"
    systemctl --user disable --now send-apps.service 2>/dev/null || true
    rm -f "$unit_dir/send-apps.service"
    systemctl --user daemon-reload 2>/dev/null || true

    say "== removing helper scripts"
    rm -f "$bin_dir/send-via" "$bin_dir/send-ensure"

    say "== dropping the Packet read-only filesystem override"
    flatpak override --user --reset "$PACKET_APP" 2>/dev/null || true

    command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

    say
    say "Done. Packet and LocalSend themselves are untouched and may still be"
    say "running — they are Flatpak apps in their own scopes; kill them by pid:"
    say "  pkill -x packet ; pkill -x localsend"
}

install_all() {
    command -v flatpak >/dev/null || { say "flatpak is required but not installed." >&2; exit 1; }
    command -v gdbus >/dev/null || { say "gdbus (glib2) is required but not installed." >&2; exit 1; }

    # --- helper scripts -------------------------------------------------
    say "== installing helper scripts to $bin_dir"
    install -d "$bin_dir"
    install -m 755 "$here/bin/send-via" "$bin_dir/send-via"
    install -m 755 "$here/bin/send-ensure" "$bin_dir/send-ensure"

    # --- Dolphin service menus -----------------------------------------
    say "== installing service menus to $menu_dir"
    install -d "$menu_dir"
    for f in send-via-packet.desktop send-via-localsend.desktop; do
        sed "s|__HOME__|$HOME|g" "$here/servicemenus/$f" > "$menu_dir/$f"
        # KIO only authorises a user-local service menu whose desktop file is executable
        chmod 755 "$menu_dir/$f"
    done

    # --- systemd user unit ----------------------------------------------
    say "== installing systemd user unit to $unit_dir"
    install -d "$unit_dir"
    sed "s|__HOME__|$HOME|g" "$here/systemd/send-apps.service" > "$unit_dir/send-apps.service"

    systemctl --user daemon-reload
    systemctl --user enable send-apps.service
    systemctl --user restart send-apps.service

    # --- app permissions -------------------------------------------------
    # Packet has no CLI for files; the menu feeds paths to its GAction, which
    # resolves them inside the sandbox. Its stock permissions only expose
    # ~/Downloads, so anything else fails to open. Read-only is enough to send.
    say "== granting $PACKET_APP read-only access to the host filesystem"
    flatpak override --user --filesystem=host:ro "$PACKET_APP" || true
    # LocalSend needs no override: its menu entry exports files through the
    # document portal with --file-forwarding.

    # --- refresh KIO's view ----------------------------------------------
    if command -v kbuildsycoca6 >/dev/null; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi

    say
    say "Installed. Right-click a file in Dolphin for 'Send via Packet' /"
    say "'Send via LocalSend'. Check the background service with:"
    say "  systemctl --user status send-apps.service"

    for app in "$PACKET_APP" "$LOCALSEND_APP"; do
        if ! flatpak info "$app" >/dev/null 2>&1; then
            say
            say "note: $app is not installed — that menu entry will do nothing until it is:"
            say "  flatpak install flathub $app"
        fi
    done
}

case "${1:-}" in
    --uninstall | -u) uninstall ;;
    --help | -h)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    "") install_all ;;
    *)
        say "unknown argument: $1 (try --help)" >&2
        exit 2
        ;;
esac
