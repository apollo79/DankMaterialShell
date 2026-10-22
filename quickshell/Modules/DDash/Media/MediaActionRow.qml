pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../../DCommon/Common/FocusNavigation.js" as FocusNavigation

RowLayout {
    id: root

    required property var player

    readonly property var focusTargets: [lyricsButton, volumeSlider, outputChip]
    readonly property var panelButtons: [outputChip]
    readonly property string devicesLabel: I18n.tr("Devices", "Media player output device picker")
    readonly property string sinkName: AudioService.displayName(AudioService.sink)
    readonly property bool showSinkName: root.player.options?.deviceName ?? MediaOptions.defaults.deviceName

    implicitHeight: Math.max(lyricsButton.implicitHeight, outputChip.implicitHeight)
    layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight
    spacing: Theme.spacingL

    Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, focusTargets, I18n.isRtl)

    DIconButton {
        id: lyricsButton

        readonly property bool active: root.player.lyricsOpen

        iconName: "lyrics"
        size: "s"
        visible: root.player.lyricsEnabled
        enabled: !!root.player.presentation
        tooltipText: I18n.tr("Lyrics", "Media player lyrics button")
        Accessible.name: tooltipText
        onClicked: root.player.toggleLyrics(lyricsButton)
        backgroundColor: MediaAccentService.accentContainer
        iconColor: MediaAccentService.onAccentContainer

        checkable: true
        checked: active

        Behavior on radius {
            enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    MediaVolumeSlider {
        id: volumeSlider
        Layout.fillWidth: true
        size: "s"

        volume: root.player.currentVolume
        muted: root.player.usePlayerVolume ? volume === 0 : AudioService.sinkSilent
        maximumVolume: root.player.maxVolumePercent
        enabled: root.player.volumeAvailable
        onVolumeChangedByUser: volume => root.player.setVolume(volume)
        onMuteRequested: root.player.toggleMute()
    }

    DIconButton {
        id: outputChip

        readonly property string panelId: "devices"

        iconName: AudioService.sinkIcon(AudioService.sink)
        size: "s"

        tooltipText: root.devicesLabel + ": " + root.sinkName
        Accessible.name: tooltipText
        onClicked: root.player.togglePanel("devices")
        backgroundColor: MediaAccentService.accentSecondaryContainer
        iconColor: MediaAccentService.onAccentSecondaryContainer
    }
}
