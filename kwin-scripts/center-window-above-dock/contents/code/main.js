/*
 * center-window-above-dock — KWin 6 script
 *
 * Centers the active window in the usable area of its screen and raises it above a
 * bottom dock, so Meta+C never drops a window on top of the dock.
 *
 * Placement region: horizontally the KWin work area (panel struts excluded); vertically
 * from the work-area top down to the dock. A Plasma dock that reserves no strut space
 * ("windows can cover" / auto-hide docks) is invisible to KWin.clientArea(), so those are
 * found as dock windows on this screen and used as the lower bound instead.
 *
 * Config lives in kwinrc, group [Script-center-window-above-dock]:
 *   offset      — extra pixels to raise the window above the region center (default 0)
 *   applyOnLoad — center the active window once when the script loads (test path used by
 *                 `center-window apply`; leave false/absent for normal use)
 *
 * Every move is logged as "[center-window] ..." to the journal for verification.
 * Use console.info: in this engine console.log/print go to a filtered debug channel.
 */

function configInt(key, fallback) {
    var value = readConfig(key, fallback);
    if (typeof value === "string") {
        value = parseInt(value, 10);
    }
    return (typeof value === "number" && !isNaN(value)) ? value : fallback;
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(value, high));
}

// A bottom dock/panel on this screen: inside the screen, top edge in the lower half.
function isBottomDock(w, screen) {
    if (!w || w.deleted || !w.dock) {
        return false;
    }
    var g = w.frameGeometry;
    if (g.width <= 0 || g.height <= 0) {
        return false;
    }
    return g.y >= screen.y + screen.height / 2
        && g.y + g.height <= screen.y + screen.height + 1
        && g.x + g.width > screen.x && g.x < screen.x + screen.width;
}

function regionBottom(screen, area, left, width) {
    var bottom = area.y + area.height;
    var windows = workspace.windowList();
    for (var i = 0; i < windows.length; i++) {
        var dock = windows[i];
        if (!isBottomDock(dock, screen)) {
            continue;
        }
        var g = dock.frameGeometry;
        if (g.x + g.width <= left || g.x >= left + width) {
            continue; // the dock is not under this window anyway
        }
        bottom = Math.min(bottom, g.y);
    }
    return (bottom > area.y) ? bottom : area.y + area.height;
}

function centerActiveWindow() {
    var win = workspace.activeWindow;
    if (!win || win.deleted || win.specialWindow) {
        console.info("[center-window] no usable active window");
        return;
    }
    // Maximized/fullscreen windows are not ours to move: KWin keeps them maximized, so
    // assigning a "centered" frame just shoves them off the top edge (measured: a
    // maximizeMode=3 window got y=-11, hiding the titlebar and leaving a gap at the dock).
    // KWin's own "Move Window to the Center" is a no-op there too.
    if (win.maximizeMode !== 0 || win.fullScreen === true) {
        console.info("[center-window] window is maximized/fullscreen, leaving it alone");
        return;
    }

    var offset = configInt("offset", 0);
    var screen = workspace.clientArea(KWin.ScreenArea, win);
    var area = workspace.clientArea(KWin.PlacementArea, win);
    var frame = win.frameGeometry;

    var x = area.x + Math.round((area.width - frame.width) / 2);
    if (frame.width <= area.width) {
        x = clamp(x, area.x, area.x + area.width - frame.width);
    }

    var top = area.y;
    var bottom = regionBottom(screen, area, x, frame.width);
    var y = Math.round(top + (bottom - top - frame.height) / 2) - offset;
    if (frame.height <= bottom - top) {
        // Never let the nudge push the titlebar under the top panel or the frame over the dock.
        y = clamp(y, top, bottom - frame.height);
    }

    console.info("[center-window] offset=" + offset +
          " screen=" + screen.x + "," + screen.y + " " + screen.width + "x" + screen.height +
          " area=" + area.x + "," + area.y + " " + area.width + "x" + area.height +
          " region=" + top + ".." + bottom +
          " frame=" + frame.x + "," + frame.y + " " + frame.width + "x" + frame.height +
          " -> " + x + "," + y);

    // KWin 6's script engine has no Qt global; QRect is built from a plain object
    // (the engine converts {x, y, width, height} to QRect).
    win.frameGeometry = {x: x, y: y, width: frame.width, height: frame.height};
}

registerShortcut("CenterWindowAboveDock", "Center Window (above panels)", "Meta+C", centerActiveWindow);

if (readConfig("applyOnLoad", false)) {
    centerActiveWindow();
}
