/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // BEGIN player selection
    readonly property string preferredPlayer: Plasmoid.configuration.preferredPlayer

    // Row 0 of Mpris2Model is the multiplexer ("active player"), other rows are real players
    property var player: null

    function selectPlayer(): void {
        if (root.preferredPlayer === "") {
            root.player = mpris2Model.currentPlayer;
            return;
        }
        for (let i = 0; i < playerRows.count; ++i) {
            const row = playerRows.objectAt(i);
            if (row && !row.isMultiplexer
                    && (row.desktopEntry === root.preferredPlayer || row.identity === root.preferredPlayer)) {
                root.player = row.container;
                return;
            }
        }
        root.player = null;
    }

    Mpris.Mpris2Model {
        id: mpris2Model
        onCurrentPlayerChanged: root.selectPlayer()
    }

    Instantiator {
        id: playerRows
        model: mpris2Model
        delegate: QtObject {
            required property bool isMultiplexer
            required property string desktopEntry
            required property string identity
            required property var container
        }
        onObjectAdded: root.selectPlayer()
        onObjectRemoved: Qt.callLater(root.selectPlayer)
    }

    onPreferredPlayerChanged: selectPlayer()
    // END player selection

    // BEGIN model properties
    readonly property string track: player?.track ?? ""
    readonly property string artist: player?.artist ?? ""
    readonly property string album: player?.album ?? ""
    readonly property string albumArt: player?.artUrl ?? ""
    readonly property string identity: player?.identity ?? ""
    readonly property string playerIcon: player?.iconName ?? ""
    readonly property int playbackStatus: player?.playbackStatus ?? Mpris.PlaybackStatus.Unknown
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool isPaused: playbackStatus === Mpris.PlaybackStatus.Paused
    readonly property real rate: player?.rate ?? 1
    readonly property real length: player?.length ?? 0 // microseconds
    // END model properties

    // Players only report position on seek / on request, so we extrapolate locally
    property real position: 0

    function syncPosition(): void {
        if (root.player) {
            root.player.updatePosition();
            root.position = root.player.position;
        } else {
            root.position = 0;
        }
    }

    onPlayerChanged: syncPosition()
    onTrackChanged: syncPosition()
    onLengthChanged: syncPosition()
    onIsPlayingChanged: syncPosition()

    Connections {
        target: root.player
        function onPositionChanged(): void {
            root.position = root.player.position;
        }
    }

    Timer {
        id: tick
        interval: 500
        repeat: true
        running: root.isPlaying && root.length > 0 && root.Plasmoid.status !== PlasmaCore.Types.HiddenStatus
        property int count: 0
        onTriggered: {
            root.position = Math.min(root.length, root.position + interval * 1000 * root.rate);
            // resync with the player every ~5 s to avoid drift
            if (++count % 10 === 0) {
                root.player?.updatePosition();
            }
        }
    }

    // BEGIN visibility
    readonly property bool shouldShow: track !== ""
        && (isPlaying || (isPaused && !Plasmoid.configuration.hideWhenPaused))

    Plasmoid.status: PlasmaCore.Types.HiddenStatus

    // Delay hiding a bit: some players briefly report "Stopped" between tracks
    onShouldShowChanged: {
        if (shouldShow) {
            hideTimer.stop();
            Plasmoid.status = PlasmaCore.Types.ActiveStatus;
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: Kirigami.Units.humanMoment
        onTriggered: Plasmoid.status = root.shouldShow ? PlasmaCore.Types.ActiveStatus
                                                       : PlasmaCore.Types.HiddenStatus
    }
    // END visibility

    Plasmoid.icon: "media-playback-start"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: track || i18n("No media playing")
    toolTipSubText: {
        const lines = [];
        if (artist) lines.push(artist);
        if (album) lines.push(album);
        if (identity) lines.push(isPaused ? i18n("%1 (paused)", identity) : identity);
        return lines.join("\n");
    }
    toolTipTextFormat: Text.PlainText

    preferredRepresentation: fullRepresentation
    fullRepresentation: NowPlaying {
        backend: root
    }

    Component.onCompleted: {
        selectPlayer();
        if (shouldShow) {
            Plasmoid.status = PlasmaCore.Types.ActiveStatus;
        }
    }
}
