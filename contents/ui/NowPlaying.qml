/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// Panel representation: [cover] [text + progress bar]
Item {
    id: view

    required property var backend

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool twoLines: Plasmoid.configuration.textLayout === 0
    // Most saturated color of the cover, brightened enough to stand out on the panel
    readonly property color accentColor: {
        const fallback = Plasmoid.configuration.accentColor;
        if (!Plasmoid.configuration.accentFromCover || art.status !== Image.Ready) {
            return fallback;
        }
        let best = null;
        let bestScore = 0;
        for (const swatch of imageColors.palette) {
            const c = swatch.color;
            const score = c.hslSaturation * Math.sqrt(swatch.ratio);
            if (c.hslSaturation >= 0.2 && score > bestScore) {
                best = c;
                bestScore = score;
            }
        }
        if (!best) {
            return fallback;
        }
        return Qt.hsla(best.hslHue, Math.max(best.hslSaturation, 0.45),
                       Math.min(Math.max(best.hslLightness, 0.45), 0.65), 1);
    }
    readonly property color textColor: Plasmoid.configuration.useThemeColors
        ? Kirigami.Theme.textColor : Plasmoid.configuration.textColor

    // BEGIN track change transition
    // Data actually on screen; swapped while the content is faded out
    property string shownTrack
    property string shownArtist
    property string shownArt
    property real contentOpacity: 1

    function applyTrack(): void {
        shownTrack = backend.track;
        shownArtist = backend.artist;
        shownArt = backend.albumArt;
    }

    Connections {
        target: view.backend
        function onTrackChanged(): void { changeTimer.restart(); }
        function onArtistChanged(): void { changeTimer.restart(); }
        function onAlbumArtChanged(): void { changeTimer.restart(); }
    }

    // Players send title, artist and cover in separate updates; coalesce them
    Timer {
        id: changeTimer
        interval: 50
        onTriggered: {
            if (view.shownTrack === view.backend.track && view.shownArtist === view.backend.artist
                    && view.shownArt === view.backend.albumArt) {
                return;
            }
            if (!view.visible || view.shownTrack === "") {
                view.applyTrack();
                return;
            }
            trackTransition.restart();
        }
    }

    SequentialAnimation {
        id: trackTransition
        NumberAnimation {
            target: view
            property: "contentOpacity"
            to: 0
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: view.applyTrack()
        }
        NumberAnimation {
            target: view
            property: "contentOpacity"
            to: 1
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutQuad
        }
    }

    Component.onCompleted: applyTrack()
    // END track change transition

    Kirigami.ImageColors {
        id: imageColors
        source: art
    }

    // BEGIN playback time
    readonly property bool showTime: backend.length > 0
    // While hovering / dragging the seek bar, show the target time instead
    readonly property real shownTime: backend.seekPreview >= 0 ? backend.seekPreview * backend.length
                                                               : backend.position
    readonly property real timeWidth: Math.ceil(timeMetrics.advanceWidth)

    // Width of the longest possible string, so the text next to it does not jump
    TextMetrics {
        id: timeMetrics
        font.pixelSize: view.fontPixelSize
        font.features: { "tnum": 1 }
        text: view.backend.formatTime(view.backend.length) + " / " + view.backend.formatTime(view.backend.length)
    }

    component TimeText: Text {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: view.timeWidth
        horizontalAlignment: Text.AlignRight
        text: view.backend.formatTime(view.shownTime) + " / " + view.backend.formatTime(view.backend.length)
        textFormat: Text.PlainText
        color: view.textColor
        opacity: 0.75
        font.pixelSize: view.fontPixelSize
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
    }
    // END playback time

    readonly property real coverSize: vertical ? width : height
    readonly property real spacing: Kirigami.Units.smallSpacing * 2
    readonly property int fixedWidth: Plasmoid.configuration.widgetWidth
    readonly property real textWidth: Math.max(0, fixedWidth - coverSize - spacing)

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    Layout.minimumWidth: vertical ? -1 : fixedWidth
    Layout.preferredWidth: vertical ? -1 : fixedWidth
    Layout.maximumWidth: vertical ? -1 : fixedWidth
    Layout.preferredHeight: vertical ? width : -1
    Layout.maximumHeight: vertical ? width : -1

    // Pixel size that lets one / two text lines plus the bar fit into the panel
    readonly property real barHeight: Math.max(2, Math.round(height / 14))
    readonly property real lineSpace: twoLines ? (textColumn.height - barHeight - spacing / 2) / 2
                                               : textColumn.height - barHeight - spacing / 2
    readonly property int defaultPixelSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 4 / 3)
    readonly property int fontPixelSize: Math.max(7, Math.min(defaultPixelSize, Math.floor(lineSpace * 0.78)))

    Item {
        id: cover
        x: 0
        y: 0
        width: view.coverSize
        height: view.coverSize

        Image {
            id: art
            anchors.fill: parent
            source: view.shownArt
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // players often reuse the same temp file path for different covers
            cache: false
            smooth: true
            opacity: view.contentOpacity
            onStatusChanged: if (status === Image.Ready) imageColors.update()
        }

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: parent.width * 0.15
            visible: art.status === Image.Null || art.status === Image.Error
            opacity: view.contentOpacity
            source: view.backend.playerIcon || "media-album-cover"
            color: view.textColor
        }

        // Playback state badge (playing / paused)
        Rectangle {
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: Math.round(parent.width * 0.06)
            }
            width: Math.max(12, Math.round(parent.width * 0.4))
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.6)
            opacity: view.backend.isPlaying || view.backend.isPaused ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.6)
                height: width
                isMask: true
                color: "white"
                source: view.backend.isPlaying ? "media-playback-start-symbolic"
                                               : "media-playback-pause-symbolic"
            }
        }
    }

    Item {
        id: textColumn
        visible: !view.vertical
        anchors {
            left: cover.right
            leftMargin: view.spacing
            top: parent.top
            bottom: parent.bottom
        }
        width: view.textWidth

        Column {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            // The line right above the bar (artist, or "Artist — Title" in one-line mode)
            // carries the playback time on its right edge
            Item {
                width: parent.width
                height: titleLabel.implicitHeight

                ScrollingText {
                    id: titleLabel
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width - (titleTime.visible ? view.timeWidth + view.spacing : 0)
                    text: view.twoLines || !view.shownArtist
                        ? view.shownTrack
                        : i18nc("@label artist — title", "%1 — %2", view.shownArtist, view.shownTrack)
                    color: view.textColor
                    font.pixelSize: view.fontPixelSize
                    font.weight: view.twoLines ? Font.DemiBold : Font.Normal
                    opacity: view.contentOpacity
                    running: view.backend.isPlaying
                }

                TimeText {
                    id: titleTime
                    visible: !view.twoLines && view.showTime
                }
            }

            Item {
                width: parent.width
                height: artistLabel.implicitHeight
                visible: view.twoLines && (artistLabel.text !== "" || view.showTime)

                ScrollingText {
                    id: artistLabel
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width - (artistTime.visible ? view.timeWidth + view.spacing : 0)
                    text: view.shownArtist
                    color: view.textColor
                    opacity: 0.75 * view.contentOpacity
                    font.pixelSize: view.fontPixelSize
                    running: view.backend.isPlaying
                }

                TimeText {
                    id: artistTime
                    visible: view.twoLines && view.showTime
                }
            }

            Item {
                width: parent.width
                height: view.spacing / 2
            }

            // Thin progress bar under the text; click or drag to seek.
            // The slot keeps a fixed height so the text does not move when the bar grows on hover.
            Item {
                id: barSlot
                width: parent.width
                height: view.barHeight
                opacity: view.backend.length > 0 ? 1 : 0

                readonly property bool interactive: view.backend.canSeek && view.backend.length > 0
                readonly property bool active: interactive && (seekArea.containsMouse || seekArea.pressed)
                readonly property real progress: seekArea.pressed
                    ? seekArea.dragProgress
                    : Math.max(0, Math.min(1, view.backend.position / view.backend.length))

                Rectangle {
                    id: track
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    height: barSlot.active ? view.barHeight * 2 : view.barHeight
                    radius: height / 2
                    color: Qt.alpha(view.textColor, 0.2)

                    Behavior on height {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * barSlot.progress
                        radius: parent.radius
                        color: view.accentColor

                        Behavior on color {
                            ColorAnimation { duration: Kirigami.Units.longDuration }
                        }

                        Behavior on width {
                            enabled: view.backend.isPlaying && !seekArea.pressed
                            NumberAnimation { duration: 500; easing.type: Easing.Linear }
                        }
                    }
                }

                // Handle
                Rectangle {
                    x: track.width * barSlot.progress - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: view.barHeight * 4
                    height: width
                    radius: width / 2
                    color: view.accentColor
                    border.width: 1
                    border.color: Qt.alpha("black", 0.3)
                    opacity: barSlot.active ? 1 : 0
                    scale: barSlot.active ? 1 : 0.5

                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }

                MouseArea {
                    id: seekArea
                    // Bigger hit area than the thin bar itself
                    anchors {
                        fill: parent
                        topMargin: -view.spacing
                        bottomMargin: -view.spacing
                    }
                    enabled: barSlot.interactive
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    property real dragProgress: 0
                    readonly property real hoverProgress: Math.max(0, Math.min(1, mouseX / width))

                    onPressed: mouse => dragProgress = hoverProgress
                    onPositionChanged: mouse => {
                        if (pressed) {
                            dragProgress = hoverProgress;
                        }
                    }
                    onReleased: mouse => view.backend.seek(dragProgress * view.backend.length)

                    // Show the target time in the widget tooltip while hovering the bar
                    onContainsMouseChanged: view.backend.seekPreview = containsMouse ? hoverProgress : -1
                    onHoverProgressChanged: if (containsMouse || pressed) view.backend.seekPreview = hoverProgress
                    onPressedChanged: if (!pressed && !containsMouse) view.backend.seekPreview = -1
                }
            }
        }
    }
}
