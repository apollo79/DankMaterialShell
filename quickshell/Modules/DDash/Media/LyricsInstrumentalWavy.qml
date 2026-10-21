import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Modules.DDash

// Circular progress for instrumental breaks. LyricsInstrumental keeps the shape-row version.
Item {
    id: root

    property real start: 0
    property real end: 0
    property real now: 0
    property bool active: false
    property bool playing: false
    property bool dimmed: false
    property bool animationsEnabled: true
    property real shapeSize: 38

    readonly property color restColor: Theme.withAlpha(Theme.tertiary, 0.35)
    readonly property color fillColor: Theme.tertiary
    readonly property real progress: root.end > root.start ? Math.max(0, Math.min(1, (root.now - root.start) / (root.end - root.start))) : 0
    readonly property bool moving: root.active && root.playing

    opacity: root.dimmed ? DashMetrics.lyricsLineInactiveAlpha : 1

    Behavior on opacity {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: DashMetrics.lyricsLineFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: DashMetrics.lyricsTrackEaseCurve
        }
    }

    implicitHeight: root.shapeSize + Theme.spacingS
    implicitWidth: root.shapeSize

    DCircularWavyProgress {
        anchors.centerIn: parent
        width: root.shapeSize
        height: root.shapeSize
        progress: root.active ? root.progress : 0
        color: root.fillColor
        trackColor: root.restColor
        waveSpeed: root.moving && root.animationsEnabled ? Style.circularWavyProgressWavelength : 0
    }
}
