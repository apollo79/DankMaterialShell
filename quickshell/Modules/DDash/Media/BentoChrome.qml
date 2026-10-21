pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.DDash
import "../../../Common/Format.js" as Format

MediaChromeBase {
    id: root

    // The artwork stage takes five parts of the card, the deck takes six.
    readonly property real columnGap: Theme.spacingXL
    readonly property bool compact: width < Theme.smallBreakpoint
    readonly property real contentWidth: Math.max(0, width - padding * 2)
    readonly property real artColumnWidth: compact ? contentWidth * 0.6 : (contentWidth - columnGap) * DashMetrics.mediaArtColumnRatio
    readonly property real deckWidth: compact ? contentWidth : (contentWidth - columnGap) * DashMetrics.mediaDeckColumnRatio
    readonly property real artworkSize: Math.round(Math.min(artColumnWidth, DashMetrics.mediaArtSizeDash))
    readonly property bool showControlsContainer: root.player.options?.controlsContainer ?? MediaOptions.defaults.controlsContainer
    readonly property real deckInset: root.showControlsContainer ? Theme.spacingXL : 0
    readonly property real deckHeight: deckArea.height
    // The transport grows into whatever the artwork column leaves over.
    readonly property real deckFixedHeight: sourceRow.height + titleBlock.implicitHeight + actionRow.implicitHeight + seekBlock.height + Theme.spacingL * 2
    readonly property real transportHeight: Math.max(Theme.buttonHeightM, Math.min(DashMetrics.mediaTransportMaxHeight, artworkSize - deckFixedHeight - Theme.spacingXL * 2))
    readonly property real columnHeight: compact ? artworkSize + columnGap + deckHeight : Math.max(artworkSize, deckHeight)

    artSize: DashMetrics.mediaArtSizeDash
    surfaceColor: Theme.foregroundColor(Theme.hostSurface)
    baseHeight: Math.max(DashMetrics.tabMinHeight, padding * 2 + columnHeight)
    focusTargets: [playerButton].concat(actionRow.focusTargets, transport.focusTargets, seekbar.canSeek && root.hasSeekbar ? [seekbar] : [])
    panelButtons: [playerButton].concat(actionRow.panelButtons)
    inlineVolume: true

    Item {
        id: artPane

        x: {
            if (root.compact)
                return (parent.width - width) / 2;
            const start = I18n.isRtl ? parent.width - root.artColumnWidth : 0;
            return start + (root.artColumnWidth - width) / 2;
        }
        y: root.compact ? 0 : (parent.height - height) / 2
        width: root.artworkSize
        // The lyrics fill the same height as the deck on the right; the square artwork stays square.
        height: !root.compact && artView.lyricsVisible ? deckArea.height : width

        MediaArtView {
            id: artView
            anchors.fill: parent
            player: root.player
            expressive: true
            showLyrics: true
            holdArt: TrackArtService.loading && TrackArtService.resolvedArtUrl === ""
        }
    }

    Item {
        id: deckArea

        x: root.compact ? 0 : (I18n.isRtl ? 0 : root.artColumnWidth + root.columnGap)
        y: root.compact ? artPane.height + root.columnGap : (parent.height - height) / 2
        width: root.deckWidth
        height: deck.height + root.deckInset * 2

        Rectangle {
            id: deckContainer

            anchors.fill: parent
            visible: root.showControlsContainer
            color: Theme.surfaceContainer
            radius: Theme.cornerRadiusXL
            border.width: Theme.layerOutlineWidth
            border.color: Theme.outlineVariant
        }

        Column {
            id: deck

            x: root.deckInset
            y: root.deckInset
            width: parent.width - root.deckInset * 2
            spacing: Theme.spacingXL

            Item {
                id: sourceRow

                width: parent.width
                height: Theme.buttonHeightXS
                implicitHeight: height

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: !!root.presentation

                    StyledText {
                        id: sourceLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Listening from", "Label before the active media player")
                        color: Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    DButton {
                        id: playerButton

                        readonly property string panelId: "players"

                        anchors.verticalCenter: parent.verticalCenter
                        buttonHeight: Theme.buttonHeightXS
                        horizontalPadding: Theme.spacingM
                        maximumWidth: Math.max(0, sourceRow.width - sourceLabel.width - Theme.spacingM)
                        text: root.presentation?.identity ?? ""
                        backgroundColor: MediaAccentService.accentContainer
                        textColor: MediaAccentService.onAccentContainer
                        tooltipText: I18n.tr("Players", "Media player selection")
                        Accessible.name: tooltipText + ": " + text
                        onClicked: root.player.togglePanel("players")
                    }
                }
            }

            Column {
                id: titleBlock

                width: parent.width
                spacing: Theme.spacingXXS

                TextMetrics {
                    id: fullSizeTitle
                    text: root.title
                    font: Qt.font({
                                      family: titleText.font.family,
                                      weight: titleText.font.weight,
                                      pixelSize: Theme.fontSizeDisplay
                                  })
                }

                FontMetrics {
                    id: fullSizeTitleFont
                    font: titleText.font
                }

                ScrollingText {
                    id: titleText

                    readonly property real fittedPixelSize: {
                        if (fullSizeTitle.advanceWidth <= width)
                            return Theme.fontSizeDisplay;
                        const fitted = Math.floor(Theme.fontSizeDisplay * width / fullSizeTitle.advanceWidth);
                        return Math.max(Theme.fontSizeXXLarge, fitted);
                    }

                    width: parent.width
                    implicitHeight: Math.ceil(fullSizeTitleFont.height)
                    height: implicitHeight
                    text: root.title
                    fontToken: root.titleFontToken
                    color: Theme.tertiary
                    // The prototype sets the title in a heavy, rounded instance of the interface font.
                    font.weight: root.titleFontToken === "ui" ? DashMetrics.mediaTitleFontWeight : Font.Normal
                    font.variableAxes: root.titleFontToken === "ui" ? DashMetrics.mediaTitleFontAxes : ({})
                    font.pixelSize: fittedPixelSize
                    horizontalAlignment: Text.AlignHCenter
                    active: root.scrolling
                    loop: true
                    fadeEdges: true
                    pxPerMs: DashMetrics.mediaTextScrollSpeed / 1000
                    stepInterval: DashMetrics.mediaTextScrollStep
                }

                ScrollingText {
                    width: parent.width
                    text: [root.artist, root.album].filter(Boolean).join(" · ") || "\u00a0"
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    active: root.scrolling
                    loop: true
                    fadeEdges: true
                    pxPerMs: DashMetrics.mediaTextScrollSpeed / 1000
                    stepInterval: DashMetrics.mediaTextScrollStep
                }
            }

            Column {
                id: controls

                width: parent.width
                spacing: Theme.spacingL

                MediaActionRow {
                    id: actionRow

                    width: parent.width
                    player: root.player
                }

                Item {
                    id: seekBlock

                    width: parent.width
                    height: seekbar.height + times.height + Theme.spacingXS
                    implicitHeight: height
                    visible: root.seekbarEnabled && !!root.presentation

                    MediaWaveSeekbar {
                        id: seekbar

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        player: root.player
                        visible: root.hasSeekbar
                    }

                    Item {
                        id: times

                        anchors.top: seekbar.bottom
                        anchors.topMargin: Theme.spacingXS
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: elapsed.implicitHeight
                        visible: root.hasSeekbar

                        TimeLabel {
                            id: elapsed

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Format.formatDuration(seekbar.value * (root.presentation?.length ?? 0))
                            reserveText: duration.text.replace(/\d/g, "8")
                        }

                        TimeLabel {
                            id: duration

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Format.formatDuration(root.presentation?.length ?? 0)
                            reserveText: text.replace(/\d/g, "8")
                        }
                    }
                }

                MediaTransport {
                    id: transport

                    width: parent.width
                    player: root.player
                    presentation: root.presentation
                    buttonSize: root.transportHeight
                    visible: hasControls
                }
            }
        }
    }

    component TimeLabel: NumericText {
        width: Math.ceil(reservedWidth)
        isMonospace: false
        color: Theme.onSurfaceVariant
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Theme.fontWeightMedium
    }
}
