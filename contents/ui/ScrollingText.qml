/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

// Single-line label that scrolls in a seamless loop when the text does not fit.
Item {
    id: root

    property string text
    property alias color: first.color
    property alias font: first.font
    property real speed: 30          // px per second
    property int pauseDuration: 2000 // ms at the start of every cycle
    property bool running: true

    readonly property real textWidth: first.implicitWidth
    readonly property bool overflowing: textWidth > width + 0.5
    readonly property real gap: Math.max(24, first.font.pixelSize * 3)

    implicitWidth: textWidth
    implicitHeight: first.implicitHeight
    clip: true

    Row {
        id: row
        spacing: root.gap
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: first
            text: root.text
            textFormat: Text.PlainText
            maximumLineCount: 1
            renderType: Text.NativeRendering
        }
        // Copy that follows the first one so the loop is seamless
        Text {
            visible: root.overflowing
            text: root.text
            textFormat: Text.PlainText
            color: first.color
            font: first.font
            maximumLineCount: 1
            renderType: Text.NativeRendering
        }
    }

    SequentialAnimation {
        id: scroll
        loops: Animation.Infinite
        running: root.overflowing && root.running && root.visible

        PropertyAction { target: row; property: "x"; value: 0 }
        PauseAnimation { duration: root.pauseDuration }
        NumberAnimation {
            target: row
            property: "x"
            from: 0
            to: -(root.textWidth + root.gap)
            duration: (root.textWidth + root.gap) / root.speed * 1000
        }

        onRunningChanged: if (!running) row.x = 0
    }

    onTextChanged: {
        row.x = 0;
        if (scroll.running) {
            scroll.restart();
        }
    }
}
