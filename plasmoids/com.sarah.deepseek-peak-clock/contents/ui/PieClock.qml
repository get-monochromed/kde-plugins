/*
 * PieClock — the 24-hour "time pie" dial.
 *
 * A ring showing all 24 hours: peak windows in one color, everything else in
 * the off-peak color (during the FLAT phase the whole ring is flat-colored).
 * Hour ticks at every hour with labels at 0/6/12/18, plus a "now" hand.
 *
 * The billing windows are fixed in UTC; on a local dial each band is shifted
 * by the zone offset (offsetMins, signed minutes to add to UTC, e.g. -300 =
 * UTC-05:00). Bands that cross local midnight are drawn as two arcs — the
 * exact math mirrored by TEST_FILES/TEST-FILE_peak_logic_test.py (band_arcs).
 *
 * Drawing: Canvas (imperative) — simple and well supported; see PLAN.md §13.
 */
import QtQuick 2.15
import org.kde.kirigami as Kirigami
import "peak.js" as Peak

Item {
    id: root

    property var windows: [[60, 240], [360, 600]]  // UTC minutes-of-day, half-open
    property int offsetMins: 0                     // SIGNED minutes to add to UTC for the zone (-300 = UTC-05:00)
    property int nowMins: 0                        // local wall-clock minutes of day
    property bool flat: false                      // FLAT phase: whole ring flat-colored
    property bool weekend: false                   // Beijing weekend: whole day off-peak
    property color peakColor: "#e53935"
    property color offPeakColor: "#43a047"
    property color flatColor: "#fb8c00"
    property color tickColor: Kirigami.Theme.textColor
    property color handColor: Kirigami.Theme.textColor

    // Redraw whenever any dial input changes.
    onWindowsChanged: canvas.requestPaint()
    onOffsetMinsChanged: canvas.requestPaint()
    onNowMinsChanged: canvas.requestPaint()
    onFlatChanged: canvas.requestPaint()
    onWeekendChanged: canvas.requestPaint()
    onPeakColorChanged: canvas.requestPaint()
    onOffPeakColorChanged: canvas.requestPaint()
    onFlatColorChanged: canvas.requestPaint()
    onTickColorChanged: canvas.requestPaint()
    onHandColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        // The popup is created hidden; make sure the dial paints once it
        // actually becomes visible (requestPaint before that is a no-op).
        onVisibleChanged: if (visible) canvas.requestPaint()

        onPaint: {
            var ctx = canvas.getContext("2d");
            var w = canvas.width;
            var h = canvas.height;
            ctx.clearRect(0, 0, w, h);
            if (w < 12 || h < 12) {
                return;
            }

            var cx = w / 2;
            var cy = h / 2;
            var twoPi = Math.PI * 2;
            var maxR = Math.min(w, h) / 2 - 2;
            // v2.3: hour labels are "00:00"…"18:00" (HH:MM), so they need more
            // room. Draw them INSIDE the ring (the ring got a touch thinner to
            // compensate) with a font sized so a 5-char label fits the dial.
            var labelFont = Math.max(8, Math.floor(maxR * 0.085));
            var ringWidth = Math.max(6, maxR * 0.17);
            var rOut = maxR - 2;
            var rMid = rOut - ringWidth / 2;
            var rIn = rOut - ringWidth;
            var labelR = rIn * 0.55;                 // hour labels sit inside the ring

            // minutes-of-day -> radians, 0h at the top, clockwise
            var angleFor = function (mins) {
                return (mins / 1440) * twoPi - Math.PI / 2;
            };

            // Draw one ring arc from minute m0 to m1 (half-open, like the windows).
            var strokeArc = function (m0, m1, color) {
                if (m1 <= m0) {
                    return;
                }
                ctx.beginPath();
                if (m1 - m0 >= 1440) {
                    ctx.arc(cx, cy, rMid, 0, twoPi);       // full circle
                } else {
                    ctx.arc(cx, cy, rMid, angleFor(m0), angleFor(m1));
                }
                ctx.strokeStyle = color;
                ctx.lineWidth = ringWidth;
                ctx.lineCap = "butt";
                ctx.stroke();
            };

            // 1. Base ring: off-peak color (flat color during the FLAT phase).
            strokeArc(0, 1440, root.flat ? root.flatColor : root.offPeakColor);

            // 2. Peak bands, shifted into local time (split at local midnight).
            // offsetMins is now SIGNED, so normalize the shifted minute into
            // [0, 1440) — JS "%" keeps the dividend's sign for negative
            // dividends, which would otherwise produce negative angles.
            function localMin(utcMin) {
                return ((utcMin + root.offsetMins) % 1440 + 1440) % 1440;
            }
            // 2026-08-23 weekend rule: Beijing Saturdays/Sundays are off-peak
            // all day, so no peak bands are drawn (the whole ring stays the
            // off-peak color).
            if (!root.flat && !root.weekend) {
                for (var i = 0; i < root.windows.length; i++) {
                    var win = root.windows[i];
                    var ls = localMin(win[0]);
                    var le = localMin(win[1]);
                    if (le <= ls) {
                        strokeArc(ls, 1440, root.peakColor);
                        strokeArc(0, le, root.peakColor);
                    } else {
                        strokeArc(ls, le, root.peakColor);
                    }
                }
            }

            // 3. Hour ticks (major at 0/6/12/18) + labels.
            ctx.lineCap = "butt";
            for (var t = 0; t < 24; t++) {
                var major = (t % 6 === 0);
                var ang = angleFor(t * 60);
                var inner = major ? rIn - 3 : rIn + ringWidth * 0.25;
                var outer = rOut + (major ? 3 : 1);
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(ang) * inner, cy + Math.sin(ang) * inner);
                ctx.lineTo(cx + Math.cos(ang) * outer, cy + Math.sin(ang) * outer);
                ctx.strokeStyle = root.tickColor;
                ctx.lineWidth = major ? Math.max(2, ringWidth * 0.10) : Math.max(1, ringWidth * 0.06);
                ctx.stroke();
            }
            ctx.font = labelFont + "px sans-serif";
            ctx.fillStyle = root.tickColor;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            for (var l = 0; l < 24; l += 6) {
                var lang = angleFor(l * 60);
                // "00:00" / "06:00" / "12:00" / "18:00"
                ctx.fillText(Peak.pad2(l) + ":00",
                    cx + Math.cos(lang) * labelR, cy + Math.sin(lang) * labelR);
            }

            // 4. "Now" hand + center dot (points at the local hour of day).
            var handAng = angleFor(root.nowMins);
            var handLen = rIn - ringWidth * 0.25;
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + Math.cos(handAng) * handLen, cy + Math.sin(handAng) * handLen);
            ctx.strokeStyle = root.handColor;
            ctx.lineWidth = Math.max(2, ringWidth * 0.12);
            ctx.lineCap = "round";
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, Math.max(3, ringWidth * 0.15), 0, twoPi);
            ctx.fillStyle = root.handColor;
            ctx.fill();
        }

        Component.onCompleted: canvas.requestPaint()
    }
}
