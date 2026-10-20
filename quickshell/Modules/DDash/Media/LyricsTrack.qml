pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../../DCommon/Common/WheelInput.js" as WheelInput
import "../../../DCommon/Widgets/ScrollConstants.js" as Scroll

// The lyrics track follows the mockup: every line sits in one column and the column is moved so
// the line that is up next rests in the vertical centre. Moving the column instead of scrolling a
// list keeps the centring exact, also for the first and the last line, and the line heights stay
// the same while the scale animates.
Item {
    id: root

    objectName: "lyricsTrack"

    required property var controller
    property bool following: true
    property bool ready: false

    // A line was clicked, the panel follows the playback again.
    signal activated()

    property bool animationsEnabled: true
    property bool sweep: true
    property real leadFontSize: Theme.fontSizeXLarge
    // The extra offset the user scrolls the track with. It sits on the same translate as the push.
    property real userOffset: 0
    property bool userScrolling: false

    readonly property bool synced: controller.synced
    readonly property int activeIndex: controller.activeIndex
    readonly property real sampleTime: controller.sampleTime
    // The clock the word fill runs on. It follows the frames while the track is on screen.
    property real now: 0

    // Lines and instrumental breaks share one list, so a break can be centred on its own.
    readonly property var items: {
        const out = [];
        if (!root.synced) {
            const plain = controller.plainLines ?? [];
            for (let i = 0; i < plain.length; i++)
                out.push({
                    "kind": "plain",
                    "index": i,
                    "text": plain[i]
                });
            return out;
        }
        const lines = controller.lines ?? [];
        let previousEnd = 0;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            // A gap before a line, also at the start of the song, is an instrumental break.
            if (line.t - previousEnd > DashMetrics.lyricsBreakGap)
                out.push({
                    "kind": "break",
                    "index": i - 1,
                    "start": previousEnd,
                    "end": line.t
                });
            out.push({
                "kind": "line",
                "index": i,
                "group": line,
                "start": line.t,
                "end": line.e
            });
            previousEnd = line.e;
        }
        return out;
    }

    // The item that is on: the last one that has started, like the mockup.
    readonly property int activeItemIndex: {
        let found = -1;
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].start <= root.sampleTime)
                found = i;
            else
                break;
        }
        return found;
    }

    // The item the column is moved to. It runs ahead of the sung line, so the line is already in
    // the centre when it is sung. A break that plays right now is centred on its own.
    readonly property int centredItemIndex: {
        for (let i = 0; i < root.items.length; i++) {
            const item = root.items[i];
            if (item.kind === "break" && root.sampleTime >= item.start && root.sampleTime < item.end)
                return i;
        }
        const wanted = Math.max(0, root.activeIndex);
        for (let i = 0; i < root.items.length; i++) {
            const item = root.items[i];
            if (item.kind === "line" && item.index === wanted)
                return i;
        }
        return root.activeItemIndex;
    }

    // Where every line has to move to, so the centred line rests in the vertical centre.
    readonly property real target: {
        repeater.count;
        const item = repeater.itemAt(root.centredItemIndex);
        if (!item)
            return 0;
        return root.height / 2 - (item.y + item.height / 2);
    }

    // The push is driven from here, so every line knows its delay before the move starts.
    function pushItems(value, animate) {
        const centre = root.centredItemIndex;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (!item)
                continue;
            // The line that is up next moves first, the lines around it follow one after another.
            // The lines above it get closer to it, the ones below it fall a little behind.
            const delay = Math.min(Math.abs(item.itemIndex - centre), DashMetrics.lyricsTrackMaxPush) * DashMetrics.lyricsTrackPushStep;
            item.push(value, delay, animate);
        }
    }

    onTargetChanged: root.pushItems(root.target, root.ready && root.animationsEnabled)
    onReadyChanged: {
        if (root.ready)
            root.pushItems(root.target, false);
    }

    function resume() {
        userOffset = 0;
    }

    function scrollBy(amount) {
        userScrolling = true;
        wheelRelease.restart();
        userOffset -= amount;
    }

    function scrollToStart() {
        const item = repeater.itemAt(0);
        userOffset = item ? root.height / 2 - (item.y + item.height / 2) - root.target : 0;
    }

    function scrollToEnd() {
        const item = repeater.itemAt(repeater.count - 1);
        userOffset = item ? root.height / 2 - (item.y + item.height / 2) - root.target : 0;
    }

    function snap() {
        ready = false;
        snapTimer.restart();
    }

    function reset() {
        userOffset = 0;
        snap();
    }

    Component.onCompleted: snapTimer.restart()

    Timer {
        id: snapTimer
        interval: 60
        onTriggered: root.ready = true
    }

    onWidthChanged: root.snap()
    onHeightChanged: root.snap()
    onVisibleChanged: {
        if (root.visible && root.synced)
            root.now = root.controller.currentTime();
    }

    FrameAnimation {
        running: root.visible && root.synced && root.controller.enabled && root.controller.playing
        onTriggered: root.now = root.controller.currentTime()
    }

    Item {
        id: viewport
        objectName: "lyricsViewport"
        anchors.fill: parent
        clip: true

        Column {
            id: column
            objectName: "lyricsColumn"
            y: root.userOffset
            width: root.width
            spacing: Theme.spacingS

            Repeater {
                id: repeater
                model: root.items

                delegate: LyricsLine {
                    required property var modelData
                    required property int index

                    width: column.width
                    controller: root.controller
                    item: modelData
                    itemIndex: index
                    activeItemIndex: root.activeItemIndex
                    centredItemIndex: root.centredItemIndex
                    now: root.now
                    ready: root.ready
                    animationsEnabled: root.animationsEnabled
                    synced: root.synced
                    sweep: root.sweep
                    following: root.following
                    leadFontSize: root.leadFontSize
                    onActivated: root.activated()
                }
            }
        }
    }

    // The user scrolls the track by dragging the space around the lines.
    MouseArea {
        id: dragArea
        z: -1
        anchors.fill: parent
        property real pressY: 0

        onPressed: mouse => {
            pressY = mouse.y;
            root.userScrolling = true;
        }
        onReleased: root.userScrolling = false
        onCanceled: root.userScrolling = false
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root.userOffset += mouse.y - pressY;
            pressY = mouse.y;
        }
    }

    // The wheel scrolls the same way it scrolls everywhere else in the shell. A positive delta
    // scrolls towards the beginning, which moves the column down.
    WheelHandler {
        id: wheelHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const kind = WheelInput.verticalKind(event);
            const deltaY = event.angleDelta.y;
            if (kind === WheelInput.Kind.wheel) {
                const lines = Math.round(Math.abs(deltaY) / 120);
                root.scrollBy((deltaY > 0 ? -lines : lines) * Scroll.mouseWheelSpeed);
            } else if (kind === WheelInput.Kind.highResWheel) {
                root.scrollBy(-deltaY / 8 * Scroll.touchpadSpeed);
            } else if (kind === WheelInput.Kind.touchpad) {
                root.scrollBy(-event.pixelDelta.y * Scroll.touchpadSpeed);
            } else {
                return;
            }
            root.userScrolling = true;
            wheelRelease.restart();
            event.accepted = true;
        }
    }

    Timer {
        id: wheelRelease
        interval: 250
        onTriggered: root.userScrolling = false
    }
}
