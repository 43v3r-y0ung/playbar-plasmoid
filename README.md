# Playbar

A compact "now playing" widget for the KDE Plasma 6 panel. No control buttons
and no popup — just click-to-seek on the progress bar and middle-click to
pause.

![Playbar in the panel](docs/screenshot.png)

- album cover (a square as tall as the panel)
- track title and artist — two lines, or a single "Artist — Title" line;
  long text scrolls smoothly
- playback time (`1:23 / 8:06`) on the right of the line above the bar
- a thin progress bar under the text; click or drag on it to seek
  (if the player supports it), with a tooltip showing the time on hover
- a playback state icon (playing / paused) in the corner of the cover
- middle-click on the widget toggles play / pause
- smooth track changes: the cover and text fade out and back in
- the progress bar color can be taken from the album cover
- fixed width in the panel (configurable)
- hides itself from the panel when nothing is playing
  (it stays visible in panel edit mode so you can move it)
- hover tooltip: track, artist, album, player

Data comes from MPRIS (the `org.kde.plasma.private.mpris` module, the same one
the built-in "Media Player" widget uses), so it works with Strawberry and any
other MPRIS-compatible player. No external dependencies — only what already
ships with Plasma 6.

## Installation

```sh
git clone https://github.com/43v3r-y0ung/playbar-plasmoid.git
cd playbar-plasmoid
kpackagetool6 -t Plasma/Applet -i .
```

Then: right-click the panel → "Add Widgets…" → find **Playbar** and drag it
onto the panel.

### Updating

```sh
kpackagetool6 -t Plasma/Applet -u .
plasmashell --replace &   # or log out and back in
```

### Removing

```sh
kpackagetool6 -t Plasma/Applet -r org.aeou.playbar
```

## Testing without a panel

`plasmoidviewer` is part of the `plasma6-sdk` package:

```sh
sudo zypper in plasma6-sdk
plasmoidviewer -a org.aeou.playbar -f horizontal -s 400x44
```

QML errors are printed to the terminal.

## Settings

| Setting | Default |
|---|---|
| Text: two lines / one "Artist — Title" line | two lines |
| Accent color (progress bar) | `#73BA25` (openSUSE green) |
| Take the accent color from the album cover (the set color is the fallback) | yes |
| Text color / "Use Plasma theme colors" | theme colors |
| Player: active (automatic) or a specific one | active |
| Hide when paused | no |
| Width in the panel (fixed) | 350 px |

A specific player is remembered by its desktop entry (for example,
`org.strawberrymusicplayer.strawberry`), so the choice survives a player
restart. If the selected player isn't running, the widget is hidden.

## Structure

```
metadata.json
contents/config/main.xml        settings schema
contents/config/config.qml      settings pages
contents/ui/main.qml            player selection, position, visibility
contents/ui/NowPlaying.qml      panel view
contents/ui/ScrollingText.qml   scrolling text line
contents/ui/configGeneral.qml   "General" page
```

## Building a `.plasmoid`

A `.plasmoid` is a zip archive of the package:

```sh
git archive --format=zip -o playbar.plasmoid HEAD metadata.json contents LICENSE
```

Installing the built file:

```sh
kpackagetool6 -t Plasma/Applet -i playbar.plasmoid
```

## License

GPL-2.0-or-later, see [LICENSE](LICENSE).
