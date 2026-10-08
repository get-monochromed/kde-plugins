/*
 * DeepSeekIcon — the DeepSeek whale, tinted with the panel's text colour.
 *
 * Local modification (2026-09): replaces the upstream panel representation's
 * phase-coloured dot + bold coloured "PEAK"/"OFF-PEAK" label with the actual
 * DeepSeek mark, bright while peak and dimmed while off-peak. The upstream
 * flyout (PopupView/PieClock) still carries the colour + text status.
 *
 * Drawn as a Shape so it can be tinted (an Image/IconItem cannot) and stays
 * crisp at panel sizes. Path data is the official DeepSeek mark from
 * simple-icons (24x24 viewBox, MIT); the path fills correctly with the
 * default non-zero rule, which is what PathSvg uses.
 */
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Peak: full brightness. Off-peak (and the pre-rule "flat" phase): dimmed.
    property bool peak: false

    property color color: Kirigami.Theme.textColor

    // Kirigami's panel icon size; override to resize.
    property real iconSize: Kirigami.Units.iconSizes.smallMedium

    // Dim factor while off-peak — deliberately the same feel as the old
    // Quickshell widget (dim, not invisible).
    property real dimOpacity: 0.45

    implicitWidth: iconSize
    implicitHeight: iconSize
    // The panel container does not stretch the compact representation, so the
    // item keeps its implicit size unless a parent explicitly overrides it.
    width: implicitWidth
    height: implicitHeight

    opacity: peak ? 1.0 : dimOpacity
    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    readonly property string whalePath: "M23.748 4.651c-.254-.124-.364.113-.512.233-.051.04-.094.09-.137.137-.372.397-.806.657-1.373.626-.829-.046-1.537.214-2.163.848-.133-.782-.575-1.248-1.247-1.548-.352-.155-.708-.311-.955-.65-.172-.24-.219-.509-.305-.774-.055-.16-.11-.323-.293-.35-.2-.031-.278.136-.356.276-.313.572-.434 1.202-.422 1.84.027 1.436.633 2.58 1.838 3.393.137.094.172.187.129.323-.082.28-.18.553-.266.833-.055.179-.137.218-.328.14a5.5 5.5 0 0 1-1.737-1.179c-.857-.828-1.631-1.743-2.597-2.46a12 12 0 0 0-.689-.47c-.985-.957.13-1.743.387-1.836.27-.098.094-.433-.778-.428-.872.003-1.67.295-2.687.685a3 3 0 0 1-.465.136 9.6 9.6 0 0 0-2.883-.101c-1.885.21-3.39 1.1-4.497 2.622C.082 8.776-.231 10.854.152 13.02c.403 2.284 1.568 4.175 3.36 5.653 1.857 1.533 3.997 2.284 6.438 2.14 1.482-.085 3.132-.284 4.994-1.86.47.234.962.328 1.78.398.629.058 1.235-.031 1.705-.129.735-.155.684-.836.418-.961-2.155-1.004-1.682-.595-2.112-.926 1.095-1.295 2.768-3.598 3.284-6.733.05-.346.115-.834.108-1.114-.004-.171.035-.238.23-.257a4.2 4.2 0 0 0 1.545-.475c1.397-.763 1.96-2.016 2.093-3.517.02-.23-.004-.467-.247-.588M11.58 18.168c-2.088-1.642-3.101-2.183-3.52-2.16-.39.024-.32.472-.234.763.09.288.207.487.371.74.114.167.192.416-.113.603-.673.416-1.842-.14-1.897-.168-1.361-.801-2.5-1.86-3.301-3.306-.775-1.393-1.225-2.888-1.299-4.482-.02-.385.094-.522.477-.592a4.7 4.7 0 0 1 1.53-.038c2.131.311 3.946 1.264 5.467 2.774.868.86 1.525 1.887 2.202 2.89.72 1.066 1.494 2.082 2.48 2.915.348.291.626.513.892.677-.802.09-2.14.109-3.055-.615zm1.001-6.44a.306.306 0 0 1 .415-.287.3.3 0 0 1 .113.074.3.3 0 0 1 .086.214c0 .17-.136.307-.308.307a.303.303 0 0 1-.306-.307m3.11 1.596c-.2.081-.4.151-.591.16a1.25 1.25 0 0 1-.798-.254c-.274-.23-.47-.358-.551-.758a1.7 1.7 0 0 1 .015-.588c.07-.327-.007-.537-.238-.727-.188-.156-.426-.199-.689-.199a.6.6 0 0 1-.254-.078.253.253 0 0 1-.114-.358 1 1 0 0 1 .192-.21c.356-.202.767-.136 1.146.016.352.144.618.408 1.001.782.392.451.462.576.685.915.176.264.336.536.446.848.066.194-.02.353-.25.45"

    Shape {
        anchors.centerIn: parent
        // Source coordinates are a 24x24 viewBox; scale the whole shape to the
        // requested icon size about its own centre.
        width: 24
        height: 24
        scale: root.iconSize / 24
        transformOrigin: Item.Center
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: root.color
            strokeWidth: 0
            PathSvg { path: root.whalePath }
        }
    }
}
