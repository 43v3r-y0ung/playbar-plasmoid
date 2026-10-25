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
    readonly property color accentColor: Plasmoid.configuration.accentColor
    readonly property color textColor: Plasmoid.configuration.useThemeColors
        ? Kirigami.Theme.textColor : Plasmoid.configuration.textColor

    readonly property real coverSize: vertical ? width : height
    readonly property real spacing: Kirigami.Units.smallSpacing * 2
    readonly property real maxTextWidth: Math.max(0, Plasmoid.configuration.maximumWidth - coverSize - spacing)
    readonly property real wantedTextWidth: Math.max(titleLabel.implicitWidth, artistLabel.visible ? artistLabel.implicitWidth : 0)
    readonly property real textWidth: Math.min(maxTextWidth, Math.max(Kirigami.Units.gridUnit * 3, wantedTextWidth))

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    Layout.minimumWidth: vertical ? -1 : coverSize + spacing + Math.min(maxTextWidth, Kirigami.Units.gridUnit * 3)
    Layout.preferredWidth: vertical ? -1 : coverSize + spacing + textWidth
    Layout.maximumWidth: vertical ? -1 : Plasmoid.configuration.maximumWidth
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
            source: view.backend.albumArt
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // players often reuse the same temp file path for different covers
            cache: false
            smooth: true
            visible: status === Image.Ready
        }

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: parent.width * 0.15
            visible: art.status !== Image.Ready
            source: view.backend.playerIcon || "media-album-cover"
            color: view.textColor
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

            ScrollingText {
                id: titleLabel
                width: parent.width
                text: view.twoLines || !view.backend.artist
                    ? view.backend.track
                    : i18nc("@label artist — title", "%1 — %2", view.backend.artist, view.backend.track)
                color: view.textColor
                font.pixelSize: view.fontPixelSize
                font.weight: view.twoLines ? Font.DemiBold : Font.Normal
                running: view.backend.isPlaying
            }

            ScrollingText {
                id: artistLabel
                width: parent.width
                visible: view.twoLines && text !== ""
                text: view.backend.artist
                color: view.textColor
                opacity: 0.75
                font.pixelSize: view.fontPixelSize
                running: view.backend.isPlaying
            }

            Item {
                width: parent.width
                height: view.spacing / 2
            }

            // Thin progress bar under the text
            Rectangle {
                width: parent.width
                height: view.barHeight
                radius: height / 2
                color: Qt.alpha(view.textColor, 0.2)
                opacity: view.backend.length > 0 ? 1 : 0

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: parent.width * Math.max(0, Math.min(1, view.backend.position / view.backend.length))
                    radius: parent.radius
                    color: view.accentColor

                    Behavior on width {
                        enabled: view.backend.isPlaying
                        NumberAnimation { duration: 500; easing.type: Easing.Linear }
                    }
                }
            }
        }
    }
}
