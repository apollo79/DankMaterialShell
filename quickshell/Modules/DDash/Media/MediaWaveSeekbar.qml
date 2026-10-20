pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DDash

// The prototype's seek bar: a sine wave over the played part, a rounded line over the rest,
// and a round handle that stretches into a pill while the bar is being dragged.
Item {
    id: root

    required property var player

    property MprisPlayer activePlayer: root.player.activePlayer
    property real stableLength: root.player.presentation?.length ?? 0
    property bool isSeeking: false
    property real seekPreviewRatio: -1
    property real displayRatio: 0
    property real handleWidth: 16
    property real handleHeight: 16

    readonly property bool canSeek: enabled && (activePlayer?.canSeek ?? false) && stableLength > 0
    readonly property real playerRatio: canSeek ? Math.max(0, Math.min(1, (activePlayer?.position ?? 0) / stableLength)) : 0
    readonly property real ratio: root.isSeeking ? root.displayRatio : root.playerRatio
    // The position the panel shows the elapsed time from.
    readonly property real value: root.ratio
    readonly property bool wantsPosition: visible && (Window.window?.visible ?? false)
    readonly property color accentColor: root.player.accent
    readonly property color accentTrackColor: MediaAccentService.accentTrack

    readonly property real waveStroke: 4
    readonly property real waveAmplitude: 1.8
    readonly property real waveLength: 22
    readonly property real handleSize: 16
    readonly property real handleDragWidth: 5
    readonly property real handleDragHeight: 28
    readonly property real handleGap: 7
    // The handle keeps a fixed inset from the ends of the bar, so the wave always ends at
    // its centre and the bar never starts under the handle.
    readonly property real handleInset: root.handleSize * 0.5
    readonly property real handleCenter: root.ratio * (width - root.handleInset * 2) + root.handleInset
    readonly property real waveValue: width > 0 ? root.handleCenter / width : 0

    property bool _positionHeld: false
    onWantsPositionChanged: _syncPositionRef(wantsPosition)
    onIsSeekingChanged: {
        root.player.isSeeking = isSeeking;
        root.updateHandleSize();
    }
    Component.onCompleted: {
        _syncPositionRef(wantsPosition);
        root.updateHandleSize();
    }
    Component.onDestruction: _syncPositionRef(false)

    function updateHandleSize() {
        handleWidth = isSeeking ? handleDragWidth : handleSize;
        handleHeight = isSeeking ? handleDragHeight : handleSize;
    }

    Behavior on handleWidth {
        enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    Behavior on handleHeight {
        enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    function _syncPositionRef(wanted) {
        if (wanted === _positionHeld)
            return;
        _positionHeld = wanted;
        if (wanted) {
            MprisController.addPositionRef();
            return;
        }
        MprisController.removePositionRef();
    }

    function ratioForPosition(x) {
        const travel = width - root.handleInset * 2;
        if (travel <= 0)
            return 0;
        return Math.max(0, Math.min(1, (x - root.handleInset) / travel));
    }

    function seekTo(ratio) {
        if (!canSeek)
            return;
        activePlayer.position = Math.max(0.1, Math.min(ratio * stableLength, stableLength * 0.99));
    }

    function seekBy(seconds) {
        if (!canSeek)
            return;
        seekTo((activePlayer.position + seconds) / stableLength);
    }

    implicitHeight: DashMetrics.mediaWaveSeekbarHeight
    height: implicitHeight
    activeFocusOnTab: canSeek
    Accessible.role: Accessible.Slider
    Accessible.name: I18n.tr("Playback position", "media seekbar accessible name")
    Accessible.focusable: canSeek
    Accessible.onIncreaseAction: seekBy(5)
    Accessible.onDecreaseAction: seekBy(-5)

    Keys.onPressed: event => {
        if (!canSeek)
            return;
        switch (event.key) {
        case Qt.Key_Left:
            seekBy(-5);
            break;
        case Qt.Key_Right:
            seekBy(5);
            break;
        case Qt.Key_PageUp:
            seekBy(stableLength / 10);
            break;
        case Qt.Key_PageDown:
            seekBy(-stableLength / 10);
            break;
        case Qt.Key_Home:
            seekTo(0);
            break;
        case Qt.Key_End:
            seekTo(1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    FocusRing {
        radius: Theme.cornerRadiusXS + Theme.focusRingOffset
        visible: root.activeFocus
    }

    M3WaveProgress {
        id: wave

        anchors.fill: parent
        value: root.waveValue
        actualValue: root.playerRatio
        showActualPlaybackState: false
        isPlaying: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        lineWidth: root.waveStroke
        amp: root.waveAmplitude
        wavelength: root.waveLength
        fillColor: root.accentColor
        trackColor: root.accentTrackColor
        playheadColor: "transparent"
        showHandle: true
        handleWidth: root.handleWidth
        handleHeight: root.handleHeight
        handleColor: root.accentColor
        handleGap: root.handleGap
    }

    // The pointer only reports whole pixels, so the handle glides onto the position instead of
    // stepping along with it. While the track plays the position is asked for every frame,
    // because the controller only polls it once a second.
    FrameAnimation {
        running: root.visible && (root.isSeeking || (root.canSeek && root.activePlayer?.playbackState === MprisPlaybackState.Playing))
        onTriggered: {
            if (!root.isSeeking) {
                root.activePlayer.positionChanged();
                return;
            }
            const delta = root.seekPreviewRatio - root.displayRatio;
            if (Math.abs(delta) < 0.0002) {
                root.displayRatio = root.seekPreviewRatio;
                return;
            }
            root.displayRatio += delta * 0.7;
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.canSeek

        onPressed: event => {
            root.isSeeking = true;
            root.seekPreviewRatio = root.ratioForPosition(event.x);
            root.displayRatio = root.seekPreviewRatio;
        }
        onPositionChanged: event => {
            if (!root.isSeeking)
                return;
            root.seekPreviewRatio = root.ratioForPosition(event.x);
        }
        onReleased: {
            if (!root.isSeeking)
                return;
            root.seekTo(root.seekPreviewRatio);
            root.isSeeking = false;
            root.seekPreviewRatio = -1;
        }
        onCanceled: {
            root.isSeeking = false;
            root.seekPreviewRatio = -1;
        }
    }
}
