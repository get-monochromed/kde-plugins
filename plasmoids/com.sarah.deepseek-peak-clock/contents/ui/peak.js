/*
 * peak.js — pure time/billing logic for the DeepSeek Peak-Time Clock.
 *
 * No Qt imports: everything here operates on plain epoch-milliseconds,
 * numbers and strings, so the exact same math is unit-tested outside QML
 * (Python mirror in TEST_FILES/TEST-FILE_peak_logic_test.py).
 *
 * Authoritative data source:
 *   https://api-docs.deepseek.com/quick_start/pricing/
 *   Retrieved: 2026-08-16 (~03:45 UTC)
 *
 * Verbatim from the official page:
 *   "Peak hours are 01:00 - 04:00 and 06:00 - 10:00 UTC (all other hours are
 *    off-peak). The new prices take effect at 16:00 UTC on August 16, 2026."
 *   "Effective 00:00 (Beijing Time) on Sunday, August 23, 2026, we will
 *    adjust our peak/off-peak billing rules, with off-peak rates applying
 *    throughout the day on weekends (Saturdays and Sundays, Beijing Time)."
 *
 * Windows are HALF-OPEN [start, end): 04:00 and 10:00 UTC are already
 * off-peak. Until the weekend rule starts, the decision is pure UTC.
 * From the weekend-rule epoch onward, Beijing weekends (Saturday/Sunday in
 * Asia/Shanghai, UTC+8 with no DST) are off-peak all day; Beijing weekdays
 * keep the UTC peak windows. Timezones still only affect how the dial is
 * drawn (see localOffsetMins / the pie band math in PieClock.qml).
 *
 * To update the windows when DeepSeek changes them, see tools/check-pricing.sh
 * and the runbook in PLAN.md §13.
 */

var PEAK_WINDOWS_UTC = [[60, 240], [360, 600]];  // minutes-of-day in UTC, half-open
var EFFECTIVE_EPOCH = 1786896000;                 // 2026-08-16 16:00:00 UTC
var EFFECTIVE_TEXT = "2026-08-16 16:00 UTC";
var WEEKEND_RULE_EPOCH = 1787414400;              // 2026-08-23 00:00 Beijing = 2026-08-22 16:00 UTC
var WEEKEND_RULE_TEXT = "2026-08-23 00:00 Beijing (2026-08-22 16:00 UTC)";
var BEIJING_OFFSET_MINS = 480;                    // China Standard Time is UTC+8 year-round (no DST)
var MINUTES_PER_DAY = 1440;

/* "7" -> "07" (avoids String.padStart, which is not guaranteed in QJSEngine) */
function pad2(n) {
    return ("0" + n).slice(-2);
}

/* Minutes since 00:00 UTC of the day containing the given epoch-ms. */
function utcMins(ms) {
    var d = new Date(ms);
    return d.getUTCHours() * 60 + d.getUTCMinutes();
}

/* True iff the instant falls inside any half-open [start, end) window. */
function isPeakAt(ms, windows) {
    if (!windows) {
        windows = PEAK_WINDOWS_UTC;
    }
    var m = utcMins(ms);
    for (var i = 0; i < windows.length; i++) {
        if (m >= windows[i][0] && m < windows[i][1]) {
            return true;
        }
    }
    return false;
}

/* Beijing weekday of an instant: 0 = Sunday … 6 = Saturday (Date.getUTCDay
 * on UTC+8-shifted time; China has no DST, so this is exact). */
function beijingWeekday(ms) {
    return new Date(ms + BEIJING_OFFSET_MINS * 60000).getUTCDay();
}

/* True when the instant is a Saturday or Sunday in Beijing time. */
function isWeekendBeijing(ms) {
    var d = beijingWeekday(ms);
    return d === 0 || d === 6;
}

/*
 * True when the instant is peak under the 2026-08-23 weekend rule:
 * Beijing weekends are off-peak all day; Beijing weekdays use the UTC windows.
 */
function isPeakAfterWeekendRule(ms, windows) {
    if (!windows) {
        windows = PEAK_WINDOWS_UTC;
    }
    return !isWeekendBeijing(ms) && isPeakAt(ms, windows);
}

/* UTC start-of-day for the day containing ms (epoch ms). */
function utcDayStart(ms) {
    var d = new Date(ms);
    return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

/*
 * Phase at an instant under the full two-epoch rule set:
 *   - "flat" before the first effective epoch,
 *   - old pure-UTC windows from then until the weekend-rule epoch,
 *   - the Beijing-weekend rule from the weekend-rule epoch onward.
 */
function phaseFor(ms, windows, effective, weekendEffective) {
    if (!windows) {
        windows = PEAK_WINDOWS_UTC;
    }
    if (typeof effective !== "number") {
        effective = EFFECTIVE_EPOCH;
    }
    if (typeof weekendEffective !== "number") {
        weekendEffective = WEEKEND_RULE_EPOCH;
    }
    if (ms < effective * 1000) {
        return "flat";
    }
    if (ms < weekendEffective * 1000) {
        return isPeakAt(ms, windows) ? "peak" : "off";
    }
    return isPeakAfterWeekendRule(ms, windows) ? "peak" : "off";
}

/*
 * Next phase transition strictly after ms.
 *
 * Candidate transitions are all UTC window boundaries and the Beijing-midnight
 * boundary (16:00 UTC, where the Beijing weekend flag flips) over the next
 * 8 days, plus the two rule-change epochs. Each candidate is checked by
 * comparing the phase just before and just after it, so suppressed weekend
 * windows and overrides that cross Beijing midnight need no special cases.
 * 8 days is longer than the longest possible off-peak gap (Friday 10:00 UTC
 * to Monday 01:00 UTC under the weekend rule).
 */
function nextTransitionAfter(ms, windows, effective, weekendEffective) {
    if (!windows) {
        windows = PEAK_WINDOWS_UTC;
    }
    if (typeof effective !== "number") {
        effective = EFFECTIVE_EPOCH;
    }
    if (typeof weekendEffective !== "number") {
        weekendEffective = WEEKEND_RULE_EPOCH;
    }

    var dayStart = utcDayStart(ms);
    var DAY_MS = 86400000;
    var best = null;

    function consider(at) {
        if (at <= ms) {
            return;
        }
        var before = at - 1000;     // one second before the boundary
        if (before < ms) {
            before = ms;
        }
        var beforePhase = phaseFor(before, windows, effective, weekendEffective);
        var afterPhase = phaseFor(at, windows, effective, weekendEffective);
        if (beforePhase === afterPhase) {
            return;
        }
        var mins = Math.ceil((at - ms) / 60000);
        if (mins < 1) {
            mins = 1;
        }
        if (best === null || at < best.at) {
            best = { at: at, minutes: mins, opens: afterPhase === "peak" };
        }
    }

    // Rule-change epochs (flat is handled by the caller, but comparing the
    // phases before/after also catches a rule change that itself flips).
    consider(effective * 1000);
    consider(weekendEffective * 1000);

    for (var day = 0; day < 8; day++) {
        var dayBase = dayStart + day * DAY_MS;
        // 16:00 UTC = 00:00 Beijing, where the Beijing weekend flag flips.
        consider(dayBase + 960 * 60000);
        for (var w = 0; w < windows.length; w++) {
            consider(dayBase + windows[w][0] * 60000);
            consider(dayBase + windows[w][1] * 60000);
        }
    }

    if (best === null) {
        // Should never happen (peak windows repeat at least weekly), but keep
        // the same safe fallback shape as the old code.
        return { minutes: MINUTES_PER_DAY, opens: true };
    }
    return { minutes: best.minutes, opens: best.opens };
}

/*
 * Full status at an instant.
 *
 * Returns { phase, minutesToNext, nextStart }:
 *   - before the first effective epoch: phase "flat", minutesToNext = ceil of
 *     the minutes remaining until the cutover, nextStart true.
 *   - after:  phase "peak" | "off"; minutesToNext = minutes until the next
 *     actual phase transition (strictly after now, taking the weekend rule
 *     into account); nextStart = whether that transition OPENS a peak window
 *     (true) or CLOSES one (false).
 */
function phaseAt(ms, windows, effective, weekendEffective) {
    if (!windows) {
        windows = PEAK_WINDOWS_UTC;
    }
    if (typeof effective !== "number") {
        effective = EFFECTIVE_EPOCH;
    }
    if (typeof weekendEffective !== "number") {
        weekendEffective = WEEKEND_RULE_EPOCH;
    }
    /* effective is epoch SECONDS (PLAN.md §2); ms is epoch milliseconds. */
    if (ms < effective * 1000) {
        return {
            phase: "flat",
            minutesToNext: Math.ceil((effective * 1000 - ms) / 60000),
            nextStart: true
        };
    }
    var next = nextTransitionAfter(ms, windows, effective, weekendEffective);
    return {
        phase: phaseFor(ms, windows, effective, weekendEffective),
        minutesToNext: next.minutes,
        nextStart: next.opens
    };
}

/*
 * Parse an override string like "60-240,360-600" (UTC minutes, half-open)
 * into [[60, 240], [360, 600]], or return null when invalid.
 * Empty string is not parseable here — callers decide what empty means.
 */
function parseWindows(str) {
    if (typeof str !== "string") {
        return null;
    }
    var trimmed = str.trim();
    if (trimmed === "") {
        return null;
    }
    var parts = trimmed.split(",");
    var parsed = [];
    for (var i = 0; i < parts.length; i++) {
        var m = /^\s*(\d{1,4})\s*-\s*(\d{1,4})\s*$/.exec(parts[i]);
        if (!m) {
            return null;
        }
        var start = parseInt(m[1], 10);
        var end = parseInt(m[2], 10);
        if (isNaN(start) || isNaN(end) || start < 0 || end > MINUTES_PER_DAY || start >= end) {
            return null;
        }
        parsed.push([start, end]);
    }
    return parsed.length > 0 ? parsed : null;
}

/* Override parser used by the applet: invalid/empty falls back to built-in. */
function applyOverride(str) {
    if (typeof str !== "string" || str.trim() === "") {
        return PEAK_WINDOWS_UTC;
    }
    var parsed = parseWindows(str);
    return parsed ? parsed : PEAK_WINDOWS_UTC;
}

/* True when the override string is either empty (built-in) or parseable. */
function isValidOverride(str) {
    if (typeof str !== "string" || str.trim() === "") {
        return true;
    }
    return parseWindows(str) !== null;
}

/* ------------------------------------------------------------------ zones
 * Zone handling must work even where the QML engine was built WITHOUT the
 * Intl object (some distro Qt builds throw "ReferenceError: Intl is not
 * defined" — seen on the target machine). Strategy: use Intl when present
 * (full DST support); otherwise fall back to a static table of standard
 * offsets plus Date's own local getters. Offsets are display-only — the
 * peak/off-peak decision is always computed in UTC (§2).
 */
var ZONE_STANDARD_OFFSETS = {
    "UTC": 0, "Etc/UTC": 0, "Etc/GMT": 0, "GMT": 0,
    "America/New_York": -300, "America/Chicago": -360,
    "America/Denver": -420, "America/Los_Angeles": -480,
    "America/Sao_Paulo": -180,
    "Europe/London": 0, "Europe/Paris": 60, "Europe/Berlin": 60,
    "Europe/Moscow": 180,
    "Africa/Cairo": 120, "Asia/Dubai": 240, "Asia/Kolkata": 330,
    "Asia/Shanghai": 480, "Asia/Tokyo": 540,
    "Australia/Sydney": 600, "Pacific/Auckland": 720
};

/*
 * Human-readable English names for the zones the applet lists, used to build
 * the popup's "Eastern Standard Time (UTC-05:00)"-style label. Display only —
 * never used for the billing decision. For anything not in the table, callers
 * fall back to the IANA name itself.
 */
var ZONE_DISPLAY_NAMES = {
    "UTC": "Coordinated Universal Time", "Etc/UTC": "Coordinated Universal Time",
    "Etc/GMT": "Greenwich Mean Time", "GMT": "Greenwich Mean Time",
    // US zones use the generic "…Time" name (correct year-round) rather than
    // "…Standard Time", which is wrong for half the year during DST.
    "America/New_York": "Eastern Time",
    "America/Chicago": "Central Time",
    "America/Denver": "Mountain Time",
    "America/Los_Angeles": "Pacific Time",
    "America/Sao_Paulo": "Brasília Time",
    "Europe/London": "Greenwich Mean Time",
    "Europe/Paris": "Central European Time",
    "Europe/Berlin": "Central European Time",
    "Europe/Moscow": "Moscow Standard Time",
    "Africa/Cairo": "Eastern European Time",
    "Asia/Dubai": "Gulf Standard Time",
    "Asia/Kolkata": "India Standard Time",
    "Asia/Shanghai": "China Standard Time",
    "Asia/Tokyo": "Japan Standard Time",
    "Australia/Sydney": "Australian Eastern Time",
    "Pacific/Auckland": "New Zealand Time"
};

function hasIntl() {
    return typeof Intl !== "undefined" && typeof Intl.DateTimeFormat === "function";
}

/* Standard-time offset in minutes for a named zone; null = unknown/system. */
function zoneStandardOffset(zone) {
    if (zone === "UTC" || zone === "GMT") {
        return 0;
    }
    return Object.prototype.hasOwnProperty.call(ZONE_STANDARD_OFFSETS, zone)
        ? ZONE_STANDARD_OFFSETS[zone] : null;
}

/* True when the string is "System", "UTC" or a valid IANA zone name. */
function isValidZone(zone) {
    if (!zone || zone === "System" || zone === "Local" || zone === "UTC") {
        return true;
    }
    if (hasIntl()) {
        try {
            new Intl.DateTimeFormat(undefined, { timeZone: zone });
            return true;
        } catch (e) {
            return false;
        }
    }
    /* No Intl: accept the standard table plus Continent/City-shaped names. */
    if (zoneStandardOffset(zone) !== null) {
        return true;
    }
    return /^[A-Za-z_+-]+(?:\/[A-Za-z_+-]+)+$/.test(zone);
}

/*
 * Wall-clock {h, m} of the instant in the given zone ("System" or an IANA
 * name). Intl path handles DST and minute offsets; the fallback uses Date
 * local getters (system zone) or the static standard-offset table (named
 * zones, DST-naive). Display only — never used for the billing decision.
 */
function hourMin(ms, zone) {
    if (hasIntl()) {
        var options = { hour: "2-digit", minute: "2-digit", hour12: false };
        if (zone && zone !== "System") {
            options.timeZone = zone;
        }
        var fmt = new Intl.DateTimeFormat(undefined, options);
        var dt = new Date(ms);
        if (typeof fmt.formatToParts === "function") {
            var h = 0;
            var m = 0;
            var parts = fmt.formatToParts(dt);
            for (var i = 0; i < parts.length; i++) {
                if (parts[i].type === "hour") {
                    h = parseInt(parts[i].value, 10);
                } else if (parts[i].type === "minute") {
                    m = parseInt(parts[i].value, 10);
                }
            }
            return { h: h, m: m };
        }
        /* Fallback (formatToParts missing): numeric hour/minute in "HH…MM". */
        var text = fmt.format(dt);
        var mm = /(\d{1,2})\D+(\d{1,2})/.exec(text);
        if (mm) {
            return { h: parseInt(mm[1], 10), m: parseInt(mm[2], 10) };
        }
        return { h: 0, m: 0 };
    }

    /* No Intl: engine-local getters for the system zone, table otherwise. */
    var d = new Date(ms);
    if (!zone || zone === "System" || zone === "Local") {
        return { h: d.getHours(), m: d.getMinutes() };
    }
    var off = zoneStandardOffset(zone);
    if (off === null) {
        off = 0;   // unknown custom zone without Intl: shown as UTC
    }
    var shifted = new Date(ms + off * 60000);
    return { h: shifted.getUTCHours(), m: shifted.getUTCMinutes() };
}

function localHourMin(ms, zone) {
    return hourMin(ms, zone);
}

/*
 * Minutes to ADD to a UTC minute-of-day to obtain the same wall-clock
 * minute-of-day in the chosen zone, normalized into [0, 1440).
 * (e.g. UTC-5 yields 1140, and adding 1140 ≡ subtracting 300 mod 1440 —
 * exactly what the pie band math needs.)
 */
function localOffsetMins(ms, zone) {
    var local = hourMin(ms, zone);
    var utc = hourMin(ms, "UTC");
    var diff = (local.h * 60 + local.m) - (utc.h * 60 + utc.m);
    return ((diff % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
}

/* "01:00–04:00, 06:00–10:00" (UTC), for display only. */
function formatWindows(windows) {
    if (!windows) {
        windows = PEAK_WINDOWS_UTC;
    }
    var parts = [];
    for (var i = 0; i < windows.length; i++) {
        var s = windows[i][0];
        var e = windows[i][1];
        parts.push(
            pad2(Math.floor(s / 60)) + ":" + pad2(s % 60) +
            "–" +
            pad2(Math.floor(e / 60)) + ":" + pad2(e % 60)
        );
    }
    return parts.join(", ");
}

/* ------------------------------------------------------------------ zone labels
 * Display helpers for "which timezone is the system-time display actually
 * using" — the popup shows the real zone name/offset next to the local
 * clock. Display only; the billing decision is always computed in UTC.
 */

/*
 * OS/system timezone name for an instant.
 *
 * With Intl: the IANA name (Intl.DateTimeFormat().resolvedOptions().timeZone,
 * e.g. "Europe/Berlin"). Without Intl (the target machine's engine): the
 * parenthesized zone name at the end of Date.toString(), e.g.
 * "Central European Summer Time". "" when the engine provides no name at
 * all — the caller then shows the offset only.
 */
function systemZoneName(ms) {
    if (hasIntl()) {
        try {
            var tz = new Intl.DateTimeFormat().resolvedOptions().timeZone;
            if (tz) {
                return tz;
            }
        } catch (e) {
            /* fall through to the Date.toString() parse */
        }
    }
    var s = new Date(ms).toString();
    var m = /\(([^()]+)\)$/.exec(s);
    return (m && m[1]) ? m[1] : "";
}

/*
 * Human-readable English name for a zone ("America/New_York" → "Eastern
 * Standard Time"). Unknown zones return the input unchanged (the IANA name),
 * so the display never loses information.
 */
function zoneDisplayName(zone) {
    if (!zone) {
        return "";
    }
    return Object.prototype.hasOwnProperty.call(ZONE_DISPLAY_NAMES, zone)
        ? ZONE_DISPLAY_NAMES[zone] : zone;
}

/*
 * Best-effort friendly zone name from a SIGNED UTC offset. Used only when the
 * engine cannot otherwise resolve the system zone name (no Intl object and no
 * parenthesized name in Date.toString() — the target machine's QJSEngine
 * emits neither). Purely cosmetic; never used for the billing decision.
 *
 * The offset alone is ambiguous where one zone's DST offset equals the next
 * zone's standard offset (e.g. -07:00 is Pacific DAYLIGHT time in summer but
 * Mountain STANDARD time in winter), so we disambiguate with a
 * northern-hemisphere DST heuristic on `ms` (roughly mid-March through early
 * November). Focused on the four mainland US/Canada zones; returns "" for
 * offsets outside the table (the caller then shows the offset alone).
 */
function zoneNameFromOffset(signedMins, ms) {
    // Approximate northern-hemisphere DST: the span from the second Sunday of
    // March to the first Sunday of November. Only a heuristic — good enough
    // for a display label, and the billing decision never depends on it.
    function summerDST(ms) {
        var d = new Date(ms);
        var m = d.getMonth();           // 0 = January
        if (m < 2 || m > 10) {
            return false;               // Dec-Feb: standard time
        }
        if (m > 2 && m < 10) {
            return true;                // Apr-Oct: DST
        }
        var day = d.getDate();
        if (m === 2) {
            return day >= 8;            // March: after ~2nd Sunday
        }
        return day < 8;                 // November: before ~1st Sunday
    }
    var dst = summerDST(ms);
    switch (signedMins) {
        case -480: return "Pacific Time";                 // PST (standard)
        case -420: return dst ? "Pacific Time" : "Mountain Time";  // PDT vs MST
        case -360: return dst ? "Mountain Time" : "Central Time";  // MDT vs CST
        case -300: return dst ? "Central Time" : "Eastern Time";   // CDT vs EST
        case -240: return "Eastern Time";                 // EDT
        default:   return "";
    }
}

/*
 * The "add to UTC" offset value in [0, 1440) as a signed UTC offset in
 * minutes: 330 -> 330 (UTC+05:30), 1140 (-300 mod 1440) -> -300 (UTC-05:00).
 */
function signedOffsetMins(localOffsetMins) {
    return localOffsetMins <= 720 ? localOffsetMins : localOffsetMins - 1440;
}

/* "+02:00" / "-05:30" for a signed minute offset. */
function offsetText(signedMins) {
    var sign = signedMins < 0 ? "-" : "+";
    var a = Math.abs(signedMins);
    return sign + pad2(Math.floor(a / 60)) + ":" + pad2(a % 60);
}

/* Minutes -> "1h 23m", "3m", "12d 4h" … */
function formatDuration(mins) {
    if (mins < 0) {
        mins = 0;
    }
    mins = Math.floor(mins);
    var d = Math.floor(mins / 1440);
    var h = Math.floor((mins % 1440) / 60);
    var m = mins % 60;
    var parts = [];
    if (d > 0) {
        parts.push(d + "d");
    }
    if (h > 0) {
        parts.push(h + "h");
    }
    if (m > 0 || parts.length === 0) {
        parts.push(m + "m");
    }
    return parts.join(" ");
}
