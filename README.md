# Steam — Omarchy bar widget

Your recently played Steam games, one click from the bar.

![The panel, open](preview.png)

A Steam mark sits in the bar. Clicking it drops a list of the games you
actually play — most recent first, with the cover art Steam has already
cached on disk, when you last played, and how long you've played. Clicking a
game launches it and closes the panel.

Everything is read from files Steam already keeps locally. No API key, no
network call, no account login, and nothing is sent anywhere.

## Install

```bash
omarchy plugin add https://github.com/Unr3leas3d/omarchy-steam-recent --enable right
```

Or clone it yourself and rescan:

```bash
git clone https://github.com/Unr3leas3d/omarchy-steam-recent \
  ~/.config/omarchy/plugins/io.github.unr3leas3d.steam-recent
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.unr3leas3d.steam-recent right
```

Drag the icon along the bar to move it; the bar writes the new position back
to `shell.json` itself.

## Using it

| Interaction | What it does |
|---|---|
| Left click | Open the panel |
| Click a game | Launch it and close the panel |
| ↑ / ↓ then Enter | Pick and launch from the keyboard |
| Esc | Close |
| Right click (bar mark) | Skip the list, open the Steam library |
| Refresh (↻, top right) | Rescan the library now |

## Settings

Set these on the widget's entry in `~/.config/omarchy/shell.json`. It
hot-reloads on save.

```json
{ "id": "io.github.unr3leas3d.steam-recent", "count": 8, "covers": true }
```

| Key | Default | Meaning |
|---|---|---|
| `count` | `5` | How many games to list (1–12) |
| `covers` | `true` | Show cover art; `false` gives a tighter text-only list |

## How it finds your games

| What | Where it comes from |
|---|---|
| Installed games | `appmanifest_*.acf` in every library in `libraryfolders.vdf` |
| Last played | `LastPlayed` in each manifest |
| Playtime | `Playtime` in each account's `userdata/*/config/localconfig.vdf` |
| Cover art | `appcache/librarycache/<appid>/library_600x900.jpg` |

`scripts/steam-recent` does the reading and prints one tab-separated row per
game. You can run it directly to see exactly what the panel sees:

```bash
~/.config/omarchy/plugins/io.github.unr3leas3d.steam-recent/scripts/steam-recent 5
```

Only installed games are listed. Proton, the Steam Linux Runtimes, and the
redistributables live in `steamapps` alongside real games and are filtered out
by name, because the manifests carry no field that distinguishes them.

## Requirements

Bash, `awk` (gawk, the Arch default — the parser uses `match()` with a
capture array), and Steam. No language runtime, no extra packages.

Steam flushes playtime when it exits, so a session's minutes may not appear
until you close Steam. Last-played updates as soon as a game exits.

## Removing it

```bash
omarchy plugin remove io.github.unr3leas3d.steam-recent
```

## License

MIT — see [LICENSE](LICENSE).

Not affiliated with Valve or Steam.
