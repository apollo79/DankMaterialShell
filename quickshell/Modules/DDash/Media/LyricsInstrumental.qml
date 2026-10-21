pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../../DCommon/Widgets/MaterialShapes.js" as Shapes

// An instrumental break shows the three material shapes, like the mockup. They bob, spin and fill
// one after another while the break plays.
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

    readonly property var kinds: ["gem", "softBoom", "pixelCircle"]
    readonly property color restColor: Theme.withAlpha(Theme.tertiary, 0.35)
    readonly property color fillColor: Theme.tertiary
    readonly property real progress: root.end > root.start ? Math.max(0, Math.min(1, (root.now - root.start) / (root.end - root.start))) : 0
    // The shapes only move while the break is up and the song is playing.
    readonly property bool moving: root.active && root.playing

    // A break that scrolled up dims. A break that plays right now is also the centred one.
    opacity: root.dimmed ? DashMetrics.lyricsLineInactiveAlpha : 1

    Behavior on opacity {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: DashMetrics.lyricsLineFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: DashMetrics.lyricsTrackEaseCurve
        }
    }

    implicitHeight: row.implicitHeight + Theme.spacingS
    implicitWidth: row.implicitWidth

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingM

        Repeater {
            model: 3

            delegate: Item {
                id: shape
                required property int index

                width: root.shapeSize
                height: root.shapeSize

                readonly property string pathData: Shapes.buildPath(root.kinds[index % 3], root.shapeSize, root.shapeSize, false)
                readonly property var outline: Shapes.polarPoints(Shapes.polarProfile(root.kinds[index % 3], 64), root.shapeSize)
                // The fill follows the silhouette, not the whole orbit: the empty padding around a
                // rotated shape must not take a share of the fill time.
                readonly property var xExtent: {
                    const radians = shape.angle * Math.PI / 180;
                    const cos = Math.cos(radians);
                    const sin = Math.sin(radians);
                    let min = Infinity;
                    let max = -Infinity;
                    for (const point of shape.outline) {
                        const x = point[0] * cos - point[1] * sin;
                        min = Math.min(min, x);
                        max = Math.max(max, x);
                    }
                    return [min, max];
                }
                // The shapes fill one after another while the break plays, and empty again once it
                // has passed.
                readonly property real fillProgress: root.active ? Math.max(0, Math.min(1, root.progress * 3 - index)) : 0
                readonly property bool running: root.moving
                readonly property bool resting: !root.active

                readonly property real startAngle: Math.random() * 360
                readonly property real spinDirection: Math.random() < 0.5 ? 1 : -1
                readonly property real spinDuration: 7000 + Math.random() * 9000
                readonly property int phase: index % 2

                property real angle: startAngle
                property real bob: 0

                transform: Translate {
                    y: shape.bob
                }

                NumberAnimation on angle {
                    running: shape.running
                    loops: Animation.Infinite
                    from: shape.startAngle
                    to: shape.startAngle + 360 * shape.spinDirection
                    duration: shape.spinDuration
                }

                SequentialAnimation on bob {
                    running: shape.running
                    loops: Animation.Infinite
                    // The first swing starts where the settle left the shape; later loops pick up
                    // from the opposite extreme, so the cycle has no stop at the rest pose.
                    NumberAnimation {
                        to: shape.phase ? 13 : -13
                        duration: 1300
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: shape.phase ? 13 : -13
                        to: shape.phase ? -13 : 13
                        duration: 1300
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    id: settle

                    NumberAnimation {
                        id: settleAngle
                        target: shape
                        property: "angle"
                        duration: root.animationsEnabled ? DashMetrics.lyricsLineFadeDuration : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: DashMetrics.lyricsTrackEaseCurve
                    }
                    NumberAnimation {
                        id: settleBob
                        target: shape
                        property: "bob"
                        duration: root.animationsEnabled ? DashMetrics.lyricsLineFadeDuration : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: DashMetrics.lyricsTrackEaseCurve
                    }
                }

                function settleIfInactive() {
                    if (!shape.resting) {
                        settle.stop();
                        return;
                    }
                    // Return to the nearest equivalent of the starting angle, not the long way
                    // around the circle.
                    settleAngle.from = shape.angle;
                    settleAngle.to = shape.startAngle + 360 * Math.round((shape.angle - shape.startAngle) / 360);
                    settleBob.from = shape.bob;
                    settleBob.to = 0;
                    settle.restart();
                }

                onRestingChanged: shape.settleIfInactive()

                Shape {
                    width: root.shapeSize
                    height: root.shapeSize
                    rotation: shape.angle
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.restColor
                        strokeWidth: -1

                        PathSvg {
                            path: shape.pathData
                        }
                    }
                }

                // The sung part is the same shape, masked in the unrotated space: a clip snaps to
                // whole pixels, which makes the slowly growing fill step. The layer is only on
                // while the shape fills, so past breaks keep no texture around. It is sized to
                // the rotated bounds, or the layer would cut the corners off.
                Item {
                    id: fillSource

                    readonly property bool filling: shape.fillProgress > 0 && shape.fillProgress < 1
                    readonly property real orbit: Math.ceil(root.shapeSize * Math.SQRT2) + 2
                    readonly property real inset: (orbit - root.shapeSize) / 2

                    x: -inset
                    y: -inset
                    width: orbit
                    height: orbit
                    visible: shape.fillProgress > 0
                    layer.enabled: filling
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: false
                        maskEnabled: true
                        maskSource: fillMask
                        // The mask keeps the band between min and max; max stays at 1 or the filled
                        // white area is masked too. The spread softens the cutoff.
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 0.5
                    }

                    Shape {
                        x: fillSource.inset
                        y: fillSource.inset
                        width: root.shapeSize
                        height: root.shapeSize
                        rotation: shape.angle
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: root.fillColor
                            strokeWidth: -1

                            PathSvg {
                                path: shape.pathData
                            }
                        }
                    }

                    Item {
                        id: fillMask

                        readonly property real edge: {
                            const extent = shape.xExtent;
                            const centre = fillSource.inset + root.shapeSize / 2;
                            const left = centre + extent[0];
                            const right = centre + extent[1];
                            return (left + (right - left) * shape.fillProgress) / fillSource.orbit;
                        }
                        readonly property real softness: width > 0 ? 1 / width : 0

                        anchors.fill: parent
                        visible: false
                        layer.enabled: fillSource.filling

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal

                                GradientStop {
                                    position: 0
                                    color: "white"
                                }
                                GradientStop {
                                    position: Math.max(0, fillMask.edge - fillMask.softness)
                                    color: "white"
                                }
                                GradientStop {
                                    position: Math.min(1, fillMask.edge + fillMask.softness)
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: 1
                                    color: "transparent"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
