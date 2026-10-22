pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import qs.Services

// One item of the lyrics track: a line with its voices, an instrumental break or a plain line.
Item {
    id: root

    // The line was clicked, the panel takes the focus and follows the playback again.
    signal activated
    required property var controller
    required property var item
    required property int itemIndex
    required property int activeItemIndex
    required property int centredItemIndex
    required property real now
    property bool following: true
    property bool ready: false
    property bool animationsEnabled: true
    property bool synced: true
    property bool sweep: true
    property real leadFontSize: Theme.fontSizeXLarge

    readonly property bool isBreak: item.kind === "break"
    readonly property bool isPlain: item.kind === "plain"
    readonly property var parts: root.isPlain ? [] : (item.group?.parts ?? [])
    // The line that is centred is the one that grows and brightens, so the move and the change in
    // size happen together.
    readonly property bool promoted: root.synced ? itemIndex === centredItemIndex : true
    readonly property bool active: root.synced ? itemIndex === activeItemIndex : true
    // While the user scrolls the lines all look the same, only the line that is sung keeps its
    // highlight.
    readonly property bool browsing: !root.following
    readonly property real targetScale: root.browsing ? 1 : root.promoted ? 1 : DashMetrics.lyricsLineInactiveScale

    // The push: the line that is up next leads, the lines above it follow one after another.
    property real shift: 0
    property int pushDelay: 0
    // The scale is driven from the same push, so a line above the new centre does not shrink
    // before the push has moved it.
    property real lineScale: 1
    property int scaleDelay: 0

    function push(value, delay, animate, scale) {
        pushMotion.stop();
        root.scaleTo(scale, delay, animate);
        if (!animate) {
            shift = value;
            return;
        }
        pushDelay = delay;
        pushMove.from = shift;
        pushMove.to = value;
        pushMotion.start();
    }

    function scaleTo(value, delay, animate) {
        scaleMotion.stop();
        if (!animate || value === root.lineScale) {
            root.lineScale = value;
            return;
        }
        scaleDelay = delay;
        scaleMove.from = root.lineScale;
        scaleMove.to = value;
        scaleMotion.start();
    }

    function stopPush() {
        pushMotion.stop();
    }

    onBrowsingChanged: {
        if (root.browsing)
            root.scaleTo(1, 0, root.ready && root.animationsEnabled);
    }

    Component.onCompleted: root.lineScale = root.targetScale

    // A line without a height would drop out of the column, so the height never goes below one.
    implicitHeight: Math.max(1, root.isBreak ? breakItem.implicitHeight : root.isPlain ? plainText.implicitHeight : content.implicitHeight)
    height: implicitHeight

    // The push waits for the lines above, so they follow one after another.
    SequentialAnimation {
        id: pushMotion

        PauseAnimation {
            duration: root.pushDelay
        }

        NumberAnimation {
            id: pushMove
            target: root
            property: "shift"
            duration: DashMetrics.lyricsTrackMoveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: DashMetrics.lyricsTrackCurve
        }
    }

    SequentialAnimation {
        id: scaleMotion

        PauseAnimation {
            duration: root.scaleDelay
        }

        NumberAnimation {
            id: scaleMove
            target: root
            property: "lineScale"
            duration: DashMetrics.lyricsLineScaleDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: DashMetrics.lyricsTrackCurve
        }
    }

    Item {
        id: mover
        width: root.width
        height: root.height
        transform: Translate {
            y: root.shift
        }

        Item {
            id: face
            anchors.fill: parent
            scale: root.lineScale
            transformOrigin: Item.Center
            Column {
                id: content
                width: parent.width
                spacing: Theme.spacingS
                visible: !root.isBreak && !root.isPlain

                Repeater {
                    model: root.parts
                    delegate: LyricsVocal {
                        required property var modelData

                        width: content.width
                        height: implicitHeight
                        controller: root.controller
                        part: modelData
                        synced: root.synced
                        now: root.now
                        leadFontSize: root.leadFontSize
                        animationsEnabled: root.animationsEnabled
                        sweep: root.sweep
                        dimmed: !root.browsing && !root.promoted
                    }
                }
            }

            LyricsInstrumental {
                id: breakItem
                visible: root.isBreak
                width: parent.width
                height: implicitHeight
                start: root.item.start ?? 0
                end: root.item.end ?? 0
                now: root.now
                active: root.active
                playing: root.controller.playing ?? false
                dimmed: !root.browsing && !root.promoted
                animationsEnabled: root.animationsEnabled
                shapeSize: Math.round(root.leadFontSize * 1.2)
            }

            StyledText {
                id: plainText
                visible: root.isPlain
                width: parent.width
                height: implicitHeight
                text: root.item.text ?? ""
                color: Theme.onSurfaceVariant
                font.pixelSize: root.leadFontSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        // Clicking an item seeks to it. The layer sits in the moving item, so it follows the item
        // while the track moves.
        StateLayer {
            anchors.fill: parent
            visible: !root.isPlain
            enabled: root.controller.canSeekLines
            stateColor: Theme.onSurfaceVariant
            cornerRadius: Theme.cornerRadius
            onClicked: {
                if (root.isBreak)
                    root.controller.seekToTime(root.item.start ?? 0);
                else
                    root.controller.seekToLine(root.item.index ?? -1);
                root.activated();
            }
        }
    }
}
