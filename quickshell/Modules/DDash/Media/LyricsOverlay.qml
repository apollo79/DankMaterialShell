pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets
import qs.Services
import qs.Modules.DDash

FocusScope {
    id: root

    property var player: null
    property var lyrics: null
    property bool smoothHighlight: root.player?.smoothLyrics ?? MediaOptions.defaults.smoothLyrics
    property real radius: DashMetrics.mediaInnerRadius
    property real contentInset: 0
    property Item blurSource: null
    property Item backgroundParent: null
    property real backgroundRadius: radius
    property color backgroundColor: blurSource ? MediaAccentService.lyricsTint : DashMetrics.cardColor
    property bool following: true

    readonly property var controller: root.lyrics ?? LyricsService.controller
    readonly property bool ready: controller.state === "ready"
    readonly property bool unsynced: ready && !controller.synced
    readonly property bool showFollow: ready && controller.synced && !following
    readonly property bool animationsEnabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property string trackKey: controller.trackKey
    readonly property string shownResult: controller.shownResult
    readonly property bool userScrolling: transcript.userScrolling
    readonly property real shapeInset: Math.ceil(Math.min(radius, width / 2, height / 2) * (1 - Math.SQRT1_2))
    readonly property bool compact: content.height < Theme.listItemTwoLineHeight * 2
    readonly property real leadFontSize: Math.round(Math.max(Theme.fontSizeXLarge, Math.min(Theme.fontSizeDisplay, transcript.height / DashMetrics.lyricsLeadHeightDivisor, transcript.width / DashMetrics.lyricsLeadWidthDivisor)))
    readonly property string message: {
        switch (controller.state) {
        case "instrumental":
            return I18n.tr("Instrumental", "Track has no lyrics because it is instrumental");
        case "error":
            return I18n.tr("Unavailable");
        case "none":
            return I18n.tr("No results");
        }
        return "";
    }

    activeFocusOnTab: true
    Accessible.role: Accessible.Pane
    Accessible.name: I18n.tr("Lyrics", "Media player lyrics button")
    onReadyChanged: transcript.snap()
    onShownResultChanged: transcript.snap()
    onTrackKeyChanged: {
        if (controller.holdsSong())
            return;
        following = true;
        transcript.reset();
    }
    onUserScrollingChanged: {
        if (userScrolling)
            browse();
    }

    LyricsSubscription {
        active: root.visible && !root.lyrics
    }

    Binding {
        target: root.player
        when: root.player !== null
        property: "lyricsFocusTarget"
        value: root
        restoreMode: Binding.RestoreBindingOrValue
    }

    function browse() {
        following = false;
    }

    function followCurrent() {
        following = true;
        transcript.resume();
    }

    function scrollBy(amount) {
        browse();
        transcript.scrollBy(amount);
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:
            scrollBy(-Theme.listItemHeight);
            break;
        case Qt.Key_Down:
            scrollBy(Theme.listItemHeight);
            break;
        case Qt.Key_PageUp:
            scrollBy(-transcript.height);
            break;
        case Qt.Key_PageDown:
            scrollBy(transcript.height);
            break;
        case Qt.Key_Home:
            browse();
            transcript.scrollToStart();
            break;
        case Qt.Key_End:
            browse();
            transcript.scrollToEnd();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    NumberAnimation on opacity {
        running: root.animationsEnabled
        from: 0
        to: 1
        duration: DashMetrics.lyricsRevealDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    }

    Item {
        parent: root.backgroundParent ?? root
        anchors.fill: parent
        opacity: root.backgroundParent ? root.opacity : 1

        BackdropBlur {
            anchors.fill: parent
            radius: root.backgroundRadius
            sourceItem: root.blurSource
            active: root.blurSource !== null && MediaAccentService.lyricsTint.a < 1
        }

        Rectangle {
            anchors.fill: parent
            radius: root.backgroundRadius
            color: root.backgroundColor
            antialiasing: true
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: Math.max(0, Math.max(root.shapeInset, root.contentInset) - Theme.spacingM)

        StyledText {
            id: heading
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.spacingM * 2
            text: I18n.tr("Unsynced", "Lyrics have no timestamps")
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            visible: root.unsynced && !root.compact
        }

        LyricsTrack {
            id: transcript
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.visible ? heading.bottom : parent.top
            anchors.bottom: attribution.top
            anchors.margins: Theme.spacingM
            clip: true
            visible: root.ready
            opacity: root.ready ? 1 : 0
            controller: root.controller
            following: root.following
            animationsEnabled: root.animationsEnabled
            sweep: root.smoothHighlight
            leadFontSize: root.leadFontSize
            onActivated: {
                root.following = true;
                transcript.resume();
                root.forceActiveFocus(Qt.MouseFocusReason);
            }

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
        }

        Item {
            id: attribution
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.spacingM * 2
            height: credit.implicitHeight

            StyledText {
                id: credit
                anchors.fill: parent
                text: root.controller.attributionName
                color: Theme.outline
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            StateLayer {
                anchors.fill: credit
                anchors.margins: -Theme.spacingXS
                cornerRadius: Theme.cornerRadius
                stateColor: Theme.outline
                visible: root.controller.attributionUrl !== ""
                tooltipText: root.controller.attributionText || root.controller.attributionUrl
                onClicked: Qt.openUrlExternally(root.controller.attributionUrl)
            }
        }

        DButton {
            id: followButton
            objectName: "followPlayback"
            anchors.horizontalCenter: parent.horizontalCenter
            // Floats over the bottom of the lyrics, above the attribution line.
            anchors.bottom: attribution.top
            anchors.bottomMargin: Theme.spacingL
            buttonHeight: Theme.buttonHeightXS
            maximumWidth: Math.max(0, parent.width - Theme.spacingM * 2)
            wrapText: true
            visible: root.showFollow
            text: root.compact ? "" : I18n.tr("Follow playback", "Resume automatic scrolling of lyrics")
            Accessible.name: I18n.tr("Follow playback", "Resume automatic scrolling of lyrics")
            tooltipText: root.compact ? Accessible.name : ""
            iconName: "my_location"
            backgroundColor: MediaAccentService.accentSecondaryContainer
            textColor: MediaAccentService.onAccentSecondaryContainer
            onClicked: {
                root.forceActiveFocus(Qt.OtherFocusReason);
                root.followCurrent();
            }
        }

        Loader {
            anchors.centerIn: transcript
            active: opacity > 0
            opacity: root.controller.pending ? 1 : 0

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }

            sourceComponent: DLoadingIndicator {
                contained: true
                containerColor: MediaAccentService.accentContainer
                color: MediaAccentService.onAccentContainer
                Accessible.role: Accessible.ProgressBar
                Accessible.name: I18n.tr("Loading...")
            }
        }

        Column {
            readonly property bool shown: !root.ready && root.message !== ""

            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM
            visible: shown
            opacity: shown ? 1 : 0

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }

            StyledText {
                width: parent.width
                text: root.message
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            DButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Retry")
                visible: root.controller.state === "error"
                onClicked: root.controller.request()
            }
        }
    }
}
