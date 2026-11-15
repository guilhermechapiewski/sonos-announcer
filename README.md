# sonos-announcer

Make announcements on your Sonos speakers from the command line.

```sh
sonos-announce "Dinner is ready!"
```

Your Mac speaks the message through the speakers you choose. Then whatever
was playing before comes back: same track, same position, same volume.

## Features

- **Text to speech** with the voices built into macOS (`say`).
- **Resumes your music** afterwards: track, queue position, radio station and
  volume.
- **Asks which room** to use the first time, and remembers your answer. Nothing
  plays everywhere unless you ask for it.
- **Forgiving room names.** Case doesn't matter, and partial names work:
  `-r kitchen,living` finds "Kitchen" and "Living Room".
- **Plays audio files** (MP3, WAV, …) as well as text.
- **Works in scripts**: pipe text in, or use it in cron jobs, shell aliases or
  build hooks.
- **No setup beyond `uv`.** It's a single file, and its dependencies install
  automatically the first time it runs.

## Requirements

- macOS (the speech uses the built-in `say` command; `--sound` works without it)
- [uv](https://docs.astral.sh/uv/), e.g. `brew install uv`
- Sonos speakers on the same local network as your computer

## Installation

With one command:

```sh
curl -fsSL https://raw.githubusercontent.com/guilhermechapiewski/sonos-announcer/main/install.sh | sh
```

Or from a clone:

```sh
git clone https://github.com/guilhermechapiewski/sonos-announcer.git
cd sonos-announcer
./install.sh            # add --link to symlink instead, so `git pull` updates it
```

The installer puts `sonos-announce` in a folder that's already on your `PATH`
(`/opt/homebrew/bin`, `/usr/local/bin` or `~/.local/bin`, whichever is writable
without `sudo`), so it works from any directory. If none of them is on your
`PATH`, it uses `~/.local/bin` and shows you the line to add to your shell
profile. Use `--dir DIR` to choose the folder yourself.

It also downloads the one dependency, [SoCo](https://github.com/SoCo/SoCo), so
the first announcement starts quickly.

To uninstall:

```sh
./install.sh --uninstall           # add --purge to also delete ~/.sonos-announce
```

> **macOS firewall:** the speakers download the audio from your computer. If
> the firewall is on, allow incoming connections for Python when macOS asks,
> otherwise the speakers will stay silent.

## Usage

```sh
sonos-announce "Dinner is ready"                     # rooms you chose (or asks)
sonos-announce -r kitchen "Dinner is ready"          # one room
sonos-announce -r kitchen,office -v 40 "Leaving in 5 minutes"
sonos-announce --all -V Samantha "Good night"        # every room, another voice
echo "Build finished" | sonos-announce -r office     # message from a pipe
sonos-announce --sound ~/chime.mp3 -r office         # play an audio file
sonos-announce --list                                # show speakers
sonos-announce --setup                               # change where to announce
```

| Option | Description |
|---|---|
| `-r`, `--room`, `--rooms ROOM` | Room(s) to announce in. Repeat the option or separate names with commas. Partial names work. |
| `-a`, `--all` | Announce in every room. |
| `-v`, `--volume`, `--vol 0-100` | Volume for the announcement. The previous volume comes back afterwards. |
| `-V`, `--voice VOICE` | macOS voice to use. List them with `say -v '?'`. |
| `-s`, `--sound`, `-f`, `--file FILE` | Play an audio file instead of speaking text. |
| `-l`, `--list` | List your speakers with their IP addresses, volumes and groups. |
| `-c`, `--setup`, `--config` | Choose where announcements play by default. |
| `-h`, `--help` | Show help. |

Press **Ctrl-C** during an announcement to stop it. Your speakers still go back
to what they were playing. Press it again to quit immediately.

## Choosing rooms

If you have more than one speaker, the first run lists them and asks:

```
Where should announcements play?

   1) Kitchen  (grouped with Living Room)
   2) Living Room  (grouped with Kitchen)
   3) Office

   a) All rooms
   e) Ask me every time

Choose room numbers (e.g. 1 or 1,3), 'a' for all, 'e' to ask every time:
```

Pick one or more rooms to always use, `a` for all rooms, or `e` to see this
list (without the `e` option) before every announcement. Your answer goes into
`~/.sonos-announce` (a small JSON file). Run `sonos-announce --setup` to change
it.

Rooms given on the command line always take priority. The order is:

1. `-r ROOM` or `--all`
2. The `SONOS_ANNOUNCE_ROOM` environment variable
3. The saved choice in `~/.sonos-announce`

If there's no terminal to ask in (e.g. under cron) and nothing tells the script
which rooms to use, it stops with an error rather than playing everywhere.

**Grouped speakers:** an announcement plays on the whole group a room belongs
to. If the kitchen is grouped with the living room, announcing in the kitchen
plays in both.

## Environment variables

| Variable | Description |
|---|---|
| `SONOS_ANNOUNCE_ROOM` | Default room(s), separated by commas. |
| `SONOS_ANNOUNCE_VOLUME` | Default announcement volume (0–100). |
| `SONOS_ANNOUNCE_VOICE` | Default macOS voice. |

## How it works

1. `say` turns the text into a WAV file.
2. The script finds your speakers on the local network using
   [SoCo](https://github.com/SoCo/SoCo).
3. It starts a temporary web server on your computer so the speakers can
   download the audio.
4. For each speaker group, it saves the current state (track, position, queue,
   volume), plays the announcement, waits for it to finish, and restores
   everything.
5. The web server and the temporary files go away when the script exits.

## Troubleshooting

- **No speakers found:** make sure your computer is on the same network as your
  speakers. Discovery uses multicast, which some guest networks and VPNs block.
- **The speakers say nothing:** check the macOS firewall note above.
- **"room is ambiguous":** type more of the name, or check the exact names with
  `--list`.

## License

[MIT](LICENSE)
