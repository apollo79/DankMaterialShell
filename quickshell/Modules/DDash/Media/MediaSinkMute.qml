import QtQuick
import qs.Common
import qs.Services

// The right mouse button toggles the mute of the current sink.
TapHandler {
    id: root

    acceptedButtons: Qt.RightButton
    target: null

    onTapped: {
        if (!AudioService.sink?.audio)
            return;
        SessionData.suppressOSDTemporarily();
        AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
    }
}
