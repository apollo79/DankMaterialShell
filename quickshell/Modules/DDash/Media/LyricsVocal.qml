pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash

// A lyric line is drawn word by word, like the mockup: every word sits on a dim base text with a
// bright copy on top, clipped to the part of the word that has been sung already. A word that is
// synced below the word level keeps its parts together, and the parts fill in turn.
Item {
    id: root

    required property var controller
    required property var part
    required property real now

    property bool synced: true
    property bool animationsEnabled: true
    property bool sweep: true
    property bool dimmed: false
    property real leadFontSize: Theme.fontSizeXLarge
    // The clock of the sung line. It only runs while this line is the one being sung.
    property real clock: 0

    readonly property bool timedWords: synced && !!part.w && part.w.length > 0
    readonly property real sampleTime: controller.sampleTime
    readonly property var words: root.timedWords ? root.buildWords() : []
    readonly property var rows: {
        // advanceWidth reads the font in C++, so QML cannot see the dependency. Read the font
        // properties here or the rows keep the old wrapping when the lead size changes.
        root.fontSize;
        root.fontWeight;
        metrics.font;
        return root.layoutRows(root.words, Math.max(0, root.width - Theme.spacingM * 2));
    }
    readonly property real lastEnd: {
        let end = 0;
        for (const word of root.words)
            end = Math.max(end, word.e);
        return end;
    }
    readonly property real partEnd: root.timedWords ? root.lastEnd : (part.e ?? 0)
    // The line keeps its accent for a moment after its last word, then it dims into the colour of a
    // line that was never sung.
    readonly property real sinceEnd: root.sampleTime - root.partEnd
    readonly property bool started: root.synced && root.sampleTime >= part.t
    readonly property bool holding: root.started && root.sinceEnd >= 0 && root.sinceEnd < DashMetrics.lyricsLineFillHold / 1000
    readonly property bool singing: root.started && (root.sinceEnd < 0 || root.holding)
    // The highlight of the line: it comes up as fast as it can when the line starts, it holds the
    // accent for a moment after the last word and then it fades into the colour of a line that was
    // never sung. It follows the clock, like the fill of the instrumental break does.
    readonly property real highlight: {
        const at = root.now;
        const start = part.t;
        const end = root.partEnd;
        if (at <= start)
            return 0;
        if (at < end) {
            // The rise never reaches past the end of the line, so the curve stays continuous where
            // the line hands over to the fade out.
            const rise = Math.max(0.001, Math.min(DashMetrics.lyricsLineFadeInDuration / 1000, end - start));
            return Math.max(0, Math.min(1, (at - start) / rise));
        }
        const hold = DashMetrics.lyricsLineFillHold / 1000;
        const fade = DashMetrics.lyricsLineFadeDuration / 1000;
        if (at < end + hold + fade)
            return Math.max(0, Math.min(1, 1 - (at - end - hold) / fade));
        return 0;
    }
    // The sung words take the tertiary, the words that are still to come a hint of it. The mockup
    // mixes the accent with transparency, so the two are told apart by the strength, and a line
    // that is done fades into the same rest the lines that were never sung have.
    readonly property color accentRest: Theme.withAlpha(Theme.tertiary, 0.35)
    readonly property color restColor: root.accentRest
    readonly property color fillColor: Theme.withAlpha(Theme.tertiary, root.highlight)
    readonly property int alignment: part.side === 0 ? Text.AlignHCenter : (part.side < 0) !== I18n.isRtl ? Text.AlignLeft : Text.AlignRight
    readonly property real fontSize: part.background ? Math.round(root.leadFontSize * Theme.fontSizeLarge / Theme.fontSizeXLarge) : root.leadFontSize
    readonly property int fontWeight: root.synced && !part.background ? Theme.fontWeightBold : Theme.fontWeightMedium
    // A line without spaces holds one cue per word, so nothing is added between them.
    readonly property bool spaced: root.timedWords && (part.w ?? []).some(cue => /\s/.test(cue.x))

    // A line that scrolled up dims once its last word is done, unless this part is still sung.
    // `singing` includes the fill hold, so the opacity follows the same hold and fade as the
    // highlight instead of starting a second dim when the part end arrives.
    opacity: root.dimmed && !root.singing ? DashMetrics.lyricsLineInactiveAlpha : 1

    Behavior on opacity {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: DashMetrics.lyricsLineFadeDuration
            easing.type: Easing.Linear
        }
    }

    implicitHeight: rowsContainer.height + Theme.spacingS

    // The clock only runs while the line is sung, so the other lines do not follow the frames.
    Binding {
        target: root
        property: "clock"
        value: root.now
        when: root.singing
        // Keep the last position when the line stops being sung. The default restore mode would
        // reset the clock to zero, which snaps the word fill away before the colour can fade.
        restoreMode: Binding.RestoreNone
    }

    // The words of a line in the order they are written. A cue that carries on where the last one
    // stopped belongs to the same word, so a word that is synced below the word level stays whole.
    // A word without its own end runs until the next cue starts.
    function buildWords() {
        const source = part.w ?? [];
        const spaced = source.some(cue => /\s/.test(cue.x));
        const order = source.map((word, index) => index).sort((a, b) => source[a].t - source[b].t);
        const limit = Number.isFinite(part.e) ? part.e : Infinity;
        const ends = new Map();
        for (let i = 0; i < source.length; i++) {
            const cue = source[i];
            const place = order.indexOf(i);
            const next = place >= 0 && place + 1 < order.length ? source[order[place + 1]] : null;
            const end = cue.e > cue.t ? cue.e : (next ? next.t : limit);
            ends.set(i, Math.min(limit, end) > cue.t ? Math.min(limit, end) : cue.t);
        }
        const words = [];
        let current = null;
        for (let i = 0; i < source.length; i++) {
            const cue = source[i];
            if (!cue.x.length)
                continue;
            const text = cue.x;
            const startsWord = !current || !spaced || /^\s/.test(text) || /\s$/.test(current.text);
            if (startsWord) {
                current = {
                    "text": "",
                    "parts": [],
                    "t": cue.t,
                    "e": ends.get(i)
                };
                words.push(current);
            }
            const part = {
                "text": text,
                "t": cue.t,
                "e": ends.get(i)
            };
            current.parts.push(part);
            current.text += text;
            current.e = Math.max(current.e, part.e);
        }
        for (const word of words) {
            word.text = word.text.trim();
            for (const part of word.parts)
                part.text = part.text.trim();
        }
        return words;
    }

    // A word that is wider than the track cannot be wrapped between words. Split it into chunks
    // and give each chunk its slice of the word's time, so the chunks fill in order.
    function splitWord(word, maxWidth) {
        const letters = Array.from(word.text);
        if (letters.length < 2 || maxWidth <= 0)
            return [word];
        const chunks = [];
        let chunk = "";
        let start = 0;
        for (let i = 0; i < letters.length; i++) {
            const next = chunk + letters[i];
            if (chunk && metrics.advanceWidth(next) > maxWidth) {
                chunks.push({
                    "text": chunk,
                    "start": start,
                    "end": i
                });
                chunk = letters[i];
                start = i;
            } else {
                chunk = next;
            }
        }
        if (chunk)
            chunks.push({
                "text": chunk,
                "start": start,
                "end": letters.length
            });
        const span = Number.isFinite(word.e) ? Math.max(0, word.e - word.t) : 0;
        return chunks.map(chunk => {
            const part = {
                "text": chunk.text,
                "t": span > 0 ? word.t + span * chunk.start / letters.length : word.t,
                "e": span > 0 ? word.t + span * chunk.end / letters.length : word.e
            };
            return {
                "text": chunk.text,
                "parts": [part],
                "t": word.t,
                "e": word.e
            };
        });
    }

    // The words are packed into rows that fit the width of the track.
    function layoutRows(words, maxWidth) {
        const rows = [];
        let row = [];
        let width = 0;
        for (const word of words) {
            const wordWidth = metrics.advanceWidth(word.text);
            if (maxWidth > 0 && wordWidth > maxWidth) {
                if (row.length) {
                    rows.push(row);
                    row = [];
                    width = 0;
                }
                for (const chunk of root.splitWord(word, maxWidth))
                    rows.push([chunk]);
                continue;
            }
            if (row.length && width + root.spaceWidth + wordWidth > maxWidth) {
                rows.push(row);
                row = [];
                width = 0;
            }
            width += (row.length ? root.spaceWidth : 0) + wordWidth;
            row.push(word);
        }
        if (row.length)
            rows.push(row);
        return rows;
    }

    StyledText {
        id: fontSource
        visible: false
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        text: " "
    }

    FontMetrics {
        id: metrics
        font: fontSource.font
    }

    readonly property real spaceWidth: {
        root.fontSize;
        root.fontWeight;
        metrics.font;
        return root.spaced ? metrics.advanceWidth(" ") : 0;
    }

    // One word: its parts sit next to each other, and every part fills on its own.
    component LyricWord: Item {
        id: word

        required property var parts
        required property color rest
        required property color fill
        required property real pixelSize
        required property int weight
        required property bool singing
        required property bool started
        required property bool sweep
        required property real clock

        implicitWidth: partsRow.implicitWidth
        implicitHeight: partsRow.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Row {
            id: partsRow
            spacing: 0

            Repeater {
                model: word.parts

                delegate: Item {
                    id: part
                    required property var modelData

                    width: base.implicitWidth
                    height: base.implicitHeight

                    readonly property real progress: {
                        if (!word.started)
                            return 0;
                        const span = Math.max(0.001, part.modelData.e - part.modelData.t);
                        const done = word.sweep ? (word.clock - part.modelData.t) / span : (word.clock >= part.modelData.t ? 1 : 0);
                        return Math.max(0, Math.min(1, done));
                    }

                    StyledText {
                        id: base
                        text: part.modelData.text
                        color: word.rest
                        font.pixelSize: word.pixelSize
                        font.weight: word.weight
                        wrapMode: Text.NoWrap
                        elide: Text.ElideNone
                    }

                    // The bright copy is clipped to the sung part of the word.
                    Item {
                        width: part.width * part.progress
                        height: part.height
                        clip: true

                        StyledText {
                            text: part.modelData.text
                            color: word.fill
                            font: base.font
                            wrapMode: Text.NoWrap
                            elide: Text.ElideNone
                        }
                    }
                }
            }
        }
    }

    Item {
        id: rowsContainer
        width: parent.width
        height: rowsColumn.implicitHeight
        // The line keeps half the spacing above and below, so its state layer has even padding.
        y: Theme.spacingS / 2

        Column {
            id: rowsColumn
            width: parent.width
            spacing: Theme.spacingXXS

            Repeater {
                model: root.rows

                delegate: Item {
                    id: rowItem
                    required property var modelData

                    width: rowsColumn.width
                    height: wordRow.implicitHeight

                    Row {
                        id: wordRow
                        height: rowItem.height
                        spacing: root.spaceWidth
                        x: {
                            const rowWidth = wordRow.implicitWidth;
                            if (root.alignment === Text.AlignLeft)
                                return 0;
                            if (root.alignment === Text.AlignRight)
                                return rowItem.width - rowWidth;
                            return (rowItem.width - rowWidth) / 2;
                        }

                        Repeater {
                            model: rowItem.modelData

                            delegate: LyricWord {
                                required property var modelData

                                parts: modelData.parts
                                rest: root.restColor
                                fill: root.fillColor
                                pixelSize: root.fontSize
                                weight: root.fontWeight
                                singing: root.singing
                                started: root.started
                                sweep: root.sweep
                                clock: root.clock
                            }
                        }
                    }
                }
            }
        }
    }
}
