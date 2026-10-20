pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.DCommon.Widgets
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
    property bool past: false
    property real shapeSize: 38

    readonly property var kinds: ["gem", "softBoom", "pixelCircle"]
    readonly property color restColor: Theme.withAlpha(Theme.tertiary, 0.35)
    readonly property color fillColor: Theme.tertiary
    readonly property real progress: root.end > root.start ? Math.max(0, Math.min(1, (root.now - root.start) / (root.end - root.start))) : 0
    // The shapes only move while the break is up and the song is playing.
    readonly property bool moving: root.active && root.playing

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
                // The shapes fill one after another while the break plays.
                readonly property real fillProgress: root.past ? 1 : root.active ? Math.max(0, Math.min(1, root.progress * 3 - index)) : 0
                readonly property bool running: root.moving

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
                    NumberAnimation {
                        from: shape.phase ? 13 : -13
                        to: shape.phase ? -13 : 13
                        duration: 1300
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: shape.phase ? -13 : 13
                        to: shape.phase ? 13 : -13
                        duration: 1300
                        easing.type: Easing.InOutSine
                    }
                }

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

                // The fill draws the whole shape, clipped to the sung part of it.
                Item {
                    width: root.shapeSize * shape.fillProgress
                    height: root.shapeSize
                    clip: true

                    Shape {
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
                }
            }
        }
    }
}
