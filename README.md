# Omarchy News

A dedicated bar panel for official [Omarchy](https://omarchy.org/) and [Omacom Foundation](https://omarchy.org/foundation/) announcements. Built for [DHH's RSS request](https://x.com/dhh/status/2095473790650048879). This is not a generic RSS reader and it is not News Radar — it pins one feed: `https://omarchy.org/news/rss.xml`.

## Install

```sh
omarchy plugin add https://github.com/kkoontz/omarchy-news-rss.git --enable
```

The widget lands on the right of the bar. Plugins run unsandboxed inside the long-lived `omarchy-shell` process; read the code before you enable it.

## Update

```sh
omarchy plugin update io.github.kkoontz.omarchy-news-rss
```

## Remove

```sh
omarchy plugin remove io.github.kkoontz.omarchy-news-rss
```

Removal does not delete `~/.local/state/omarchy/omarchy-news-rss/`. Delete that directory yourself if you want a clean first-run.

## Usage

- Left-click the RSS icon to open or close the panel
- Right-click to refresh
- Middle-click to mark all read
- The icon stays theme-colored. Unread count is the `9+` badge
- In-article https links use the theme's alt color (accent, or the other Hyprland border stop when accent matches the body text)
- Tooltip shows the latest headline, or `N new announcements`
- Click a row (or press Enter) to read the article as plain text in the panel
- From an article: Back, Open original, toggle unread
- `?` shows the key list. `z` undoes mark-all for five seconds

First launch records `firstSeenAt` and marks every item already in the feed as read. Only posts published after that moment become unread, so installing does not dump a historical badge.

The service polls every 15 minutes while the panel is closed (override with `refreshMinutes`). Opening the panel or pressing `r` also refreshes. There are no desktop notifications.

This plugin does **not** write a Hyprland keybind. To summon it from the keyboard, add this yourself to `~/.config/hypr/bindings.lua` (the community chord for official Omarchy News; `Super+Shift+N` is already Editor):

```lua
o.bind("SUPER + ALT + N", "Omarchy News", "omarchy-shell shell toggle io.github.kkoontz.omarchy-news-rss")
```

## Keyboard

| Key | Action |
|---|---|
| `j` / `k` or arrows | Move |
| Enter | Open article |
| `o` | Open original in the browser |
| `y` | Copy the canonical https link |
| `r` | Refresh |
| `x` or `m` | Toggle unread on the selected row |
| `c` or Shift+A | Mark all read |
| `z` | Undo mark-all (5 seconds) |
| `?` | Key cheatsheet |
| Backspace / Escape in article | Back to the list |
| Escape on the list | Close the panel |
| Tab | Hand off to the next bar panel |

## Configure

```sh
omarchy bar move io.github.kkoontz.omarchy-news-rss --section right
omarchy bar set io.github.kkoontz.omarchy-news-rss refreshMinutes 15
```

## Data

```
~/.local/state/omarchy/omarchy-news-rss/
  feed.json    last good parsed items + fetchedAt
  read.json    read identities + firstSeenAt
```

Deleting this directory is safe. The next poll rebuilds it. Offline opens show the last cached items, not a blank panel.

## Security

- Pinned URL only: `https://omarchy.org/news/rss.xml`
- Fetch and state IO go through `helper/io.sh` (absolute `/usr/bin` paths, `O_NOFOLLOW` reads, exclusive temp + `rename` writes)
- `curl -q` over HTTPS (`--proto =https --max-redirs 0 --max-time 10 --max-filesize`, write to an exclusive temp, reject oversize, `--noproxy '*'`)
- Helper stdout is chunked with a 1 MiB cap; no `StdioCollector`, no `FileView`
- Non-RSS 2.0 or non-official payloads are discarded
- Article pages are not fetched; the panel renders `content:encoded` as `Text.PlainText` after tag stripping. https links stay clickable as separate plain-text runs; `javascript:` and `http://` hrefs are not.
- Canonical article URLs must be `https` on `omarchy.org` with no userinfo
- Originals open with `omarchy-launch-browser`, never `xdg-open`
- Runtime: Omarchy + `curl` + the bash helper. No Python or bundled binaries

## Test

```sh
node test/model.js
```

## License

MIT
