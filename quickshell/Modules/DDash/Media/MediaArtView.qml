pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.DDash

Item {
    id: root

    required property var player
    property bool showLyrics: true
    property bool holdArt: false
    property bool expressive: false

    readonly property real artRadius: surface.contentRadius
    readonly property real artInset: surface.contentInset
    readonly property bool lyricsVisible: root.showLyrics && root.player.lyricsOpen && root.player.live

    MediaArtSurface {
        id: surface
        anchors.fill: parent
        artStyle: root.player.options?.artStyle ?? "rounded"
        expressive: root.expressive
        player: root.player

        MediaArtwork {
            id: art
            anchors.fill: parent
            cornerRadius: 0
            placeholderIconSize: DashMetrics.mediaArtPlaceholderIcon
            artUrl: root.holdArt ? "" : root.player.presentation?.artUrl ?? ""
            // The prototype pulls the artwork back for the lyrics.
            opacity: root.lyricsVisible ? 0 : 1
            scale: root.lyricsVisible ? 0.88 : 1

            Behavior on opacity {
                enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
                }
            }

            Behavior on scale {
                enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.lyricsVisible
        onLoaded: item.forceActiveFocus(Qt.PopupFocusReason)

        // The prototype gives the lyrics the whole stage once the artwork steps aside.
        sourceComponent: LyricsOverlay {
            player: root.player
            radius: 0
            contentInset: 0
            backgroundParent: surface.contentItem
            backgroundRadius: 0
            backgroundColor: "transparent"
        }
    }
}
