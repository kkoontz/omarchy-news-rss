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

- Left-click the RSS glyph to open or close the panel
- Right-click to refresh
- Middle-click to mark all read
- Unread badge hides at 0 and caps at `9+`
- Tooltip shows the latest headline, or `N new announcements`
- Click a row (or press Enter) to read the sanitized `content:encoded` in the panel
- From an article: Back, Open original, Mark unread

First launch records `firstSeenAt` and marks every item already in the feed as read. Only posts published after that moment become unread, so installing does not dump a historical badge.

The service polls every 15 minutes while the panel is closed. Opening the panel or pressing `r` also refreshes. There are no desktop notifications.

## Keyboard

| Key | Action |
|---|---|
| `j` / `k` or arrows | Move |
| Enter | Open article |
| `o` | Open original in the browser |
| `r` | Refresh |
| `x` or `m` | Mark selected read |
| `c` or Shift+A | Mark all read |
| Backspace / Escape in article | Back to the list |
| Escape on the list | Close the panel |
| Tab | Hand off to the next bar panel |

## Configure

```sh
omarchy bar move io.github.kkoontz.omarchy-news-rss --section right
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
- Fetched with `curl` over HTTPS (`--proto =https --max-redirs 0 --max-time 10 --max-filesize 1048576 --noproxy '*'`)
- Non-RSS 2.0 or non-official payloads are discarded
- Article pages are not fetched; the panel renders sanitized `content:encoded`
- Canonical article URLs must be `https` on `omarchy.org`
- Originals open with `omarchy-launch-browser`, never `xdg-open`
- Runtime: Omarchy + `curl`. No Node, Python, or bundled binaries

## License

MIT
