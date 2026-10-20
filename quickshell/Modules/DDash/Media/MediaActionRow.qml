pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../../DCommon/Common/FocusNavigation.js" as FocusNavigation

Item {
    id: root

    required property var player

    readonly property var focusTargets: [lyricsButton, outputChip]
    readonly property var panelButtons: [outputChip]
    readonly property string devicesLabel: I18n.tr("Devices", "Media player output device picker")
    readonly property string sinkName: AudioService.displayName(AudioService.sink)
    readonly property bool showSinkName: root.player.options?.deviceName ?? MediaOptions.defaults.deviceName

    implicitHeight: Math.max(lyricsButton.implicitHeight, outputChip.implicitHeight)

    Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, focusTargets, I18n.isRtl)

    DButton {
        id: lyricsButton

        readonly property bool active: root.player.lyricsOpen

        x: I18n.isRtl ? root.width - width : 0
        y: (root.height - height) / 2
        buttonHeight: Theme.buttonHeightS
        iconName: "lyrics"
        text: I18n.tr("Lyrics", "Media player lyrics button")
        backgroundColor: active ? MediaAccentService.accentContainer : Theme.chipSurface
        textColor: active ? MediaAccentService.onAccentContainer : Theme.onSurfaceVariant
        visible: root.player.lyricsEnabled
        enabled: !!root.player.presentation
        tooltipText: text
        Accessible.name: text
        onClicked: root.player.toggleLyrics(lyricsButton)

        // The pill squashes into a squircle while the lyrics are on show.
        radius: active ? Theme.cornerRadiusM : Theme.fullRadius(width, height)

        Behavior on radius {
            enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    DButton {
        id: outputChip

        readonly property string panelId: "devices"

        x: I18n.isRtl ? 0 : root.width - width
        y: (root.height - height) / 2
        buttonHeight: Theme.buttonHeightS
        iconName: AudioService.sinkIcon(AudioService.sink)
        text: root.showSinkName ? root.sinkName : ""
        horizontalPadding: root.showSinkName ? Theme.spacingM : Theme.spacingS
        backgroundColor: MediaAccentService.accentSecondaryContainer
        textColor: MediaAccentService.onAccentSecondaryContainer
        maximumWidth: Math.round(root.width * DashMetrics.mediaDeviceNameWidthRatio)
        tooltipText: root.devicesLabel + ": " + root.sinkName
        Accessible.name: tooltipText
        onClicked: root.player.togglePanel("devices")

        MediaVolumeWheel {
            player: root.player
            button: outputChip
        }

        MediaSinkMute {}
    }
}
