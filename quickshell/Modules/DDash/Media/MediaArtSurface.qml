pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Common
import qs.Modules.DDash
import "../../../DCommon/Widgets/MaterialShapes.js" as Shapes

ClippingRectangle {
    id: root

    property var player: null
    property string artStyle: "rounded"
    // Expressive artwork: a circle that morphs into the cookie shape while the track plays.
    property bool expressive: false

    readonly property bool playing: !!root.player?.presentation?.playing
    readonly property bool shaped: root.expressive || artStyle === "slanted" || artStyle === "cookie"
    readonly property real contentRadius: root.expressive ? 0 : (artStyle === "slanted" ? width * DashMetrics.mediaArtSoftRadiusRatio * Theme.shapeScale : radius)

    readonly property real cookieMinRadius: Math.min(...Shapes.polarProfile("cookie12", 256))
    // The cookie mask rotates, so content must stay inside the largest inscribed square of the smallest cookie radius
    readonly property real contentInset: {
        if (root.expressive)
            return Math.ceil(width * (0.5 - morphMinRadius / Math.SQRT2));
        return artStyle === "cookie" ? Math.ceil(width * (0.5 - cookieMinRadius / Math.SQRT2)) : 0;
    }

    readonly property int morphSamples: 128
    readonly property var morphFrom: Shapes.polarProfile("circle", morphSamples)
    readonly property var morphTo: Shapes.polarProfile("cookie12", morphSamples)
    readonly property var morphSpring: Theme.springPreset("fast", Theme.expressiveDurations.expressiveFastSpatial)
    readonly property real morphProgress: morphMotion.value
    readonly property var morphRadii: {
        const from = morphFrom;
        const to = morphTo;
        const progress = morphProgress;
        const radii = new Array(from.length);
        for (let i = 0; i < from.length; i++)
            radii[i] = from[i] + (to[i] - from[i]) * progress;
        return radii;
    }
    readonly property real morphMinRadius: Math.min(...morphRadii)

    onPlayingChanged: updateMorph()
    onExpressiveChanged: updateMorph()

    function updateMorph() {
        morphMotion.retarget(root.expressive && root.playing ? 1 : 0);
    }

    SpringMotion {
        id: morphMotion
        enabled: !Theme.springMotionDisabled
        stiffness: root.morphSpring.stiffness
        damping: root.morphSpring.damping
        Component.onCompleted: snapTo(root.expressive && root.playing ? 1 : 0)
    }

    radius: {
        if (root.expressive)
            return 0;
        switch (artStyle) {
        case "circle":
            return width / 2;
        case "square":
            return width * DashMetrics.mediaArtSoftRadiusRatio * Theme.shapeScale;
        case "slanted":
        case "cookie":
            return 0;
        }
        return DashMetrics.mediaInnerRadius;
    }
    color: "transparent"
    antialiasing: true
    layer.enabled: root.shaped
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: {
            if (root.expressive)
                return morphShapeMask.item;
            return artStyle === "slanted" ? slantedShapeMask.item : cookieShapeMask.item;
        }
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Loader {
        id: slantedShapeMask
        anchors.fill: parent
        active: !root.expressive && root.artStyle === "slanted"
        visible: false

        sourceComponent: Item {
            layer.enabled: true

            Shape {
                id: slantedShape

                readonly property real scaleX: boundingRect.width > 0 ? root.width / boundingRect.width : 1
                readonly property real scaleY: boundingRect.height > 0 ? root.height / boundingRect.height : 1

                x: -boundingRect.x * scaleX
                y: -boundingRect.y * scaleY
                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer
                transform: Scale {
                    xScale: slantedShape.scaleX
                    yScale: slantedShape.scaleY
                }

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.withAlpha(Theme.surface, 1)

                    PathSvg {
                        path: Shapes.buildPath("slanted", root.width, root.height, Theme.shapeScale === 0)
                    }
                }
            }
        }
    }

    Loader {
        id: cookieShapeMask
        anchors.fill: parent
        active: !root.expressive && root.artStyle === "cookie"
        visible: false

        sourceComponent: Item {
            layer.enabled: true

            Shape {
                id: cookieShape

                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation {
                    origin.x: cookieShape.width / 2
                    origin.y: cookieShape.height / 2
                    NumberAnimation on angle {
                        from: 0
                        to: 360
                        paused: !root.visible || !root.player?.live || !root.playing
                        duration: 20000
                        loops: Animation.Infinite
                    }
                }

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.withAlpha(Theme.surface, 1)

                    PathSvg {
                        path: Shapes.buildPath("cookie12", root.width, root.height, Theme.shapeScale === 0)
                    }
                }
            }
        }
    }

    Loader {
        id: morphShapeMask
        anchors.fill: parent
        active: root.expressive
        visible: false

        sourceComponent: Item {
            layer.enabled: true

            Shape {
                id: morphShape

                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation {
                    origin.x: morphShape.width / 2
                    origin.y: morphShape.height / 2
                    NumberAnimation on angle {
                        from: 0
                        to: 360
                        paused: !root.visible || !root.player?.live || !root.playing
                        duration: 20000
                        loops: Animation.Infinite
                    }
                }

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.withAlpha(Theme.surface, 1)

                    PathPolyline {
                        path: {
                            const radii = root.morphRadii;
                            const size = Math.min(morphShape.width, morphShape.height);
                            const points = [];
                            for (let i = 0; i < radii.length; i++) {
                                const angle = -Math.PI + 2 * Math.PI * i / radii.length;
                                points.push(Qt.point(morphShape.width / 2 + Math.cos(angle) * radii[i] * size, morphShape.height / 2 + Math.sin(angle) * radii[i] * size));
                            }
                            return points;
                        }
                    }
                }
            }
        }
    }
}
