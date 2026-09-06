#!/usr/bin/bash
# Bounded fetch and descriptor-safe state for Omarchy News.
# argv: init | fetch | read feed|read | write feed|read
set -euo pipefail

CURL=/usr/bin/curl
HEAD=/usr/bin/head
MKTEMP=/usr/bin/mktemp
MV=/usr/bin/mv
DD=/usr/bin/dd
MKDIR=/usr/bin/mkdir
CHMOD=/usr/bin/chmod
FIND=/usr/bin/find
RM=/usr/bin/rm
TIMEOUT=/usr/bin/timeout
WC=/usr/bin/wc

MAX=1048576
FEED_URL="https://omarchy.org/news/rss.xml"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/omarchy-news-rss"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

name_ok() {
  case "$1" in
    feed|read) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_state() {
  local parent
  parent="$(/usr/bin/dirname -- "$STATE")"
  "$MKDIR" -p -m 700 "$parent" "$STATE" || die "could not create state dir"
  if [[ -L "$STATE" ]]; then
    die "state dir is a symlink"
  fi
  [[ -d "$STATE" ]] || die "state dir missing"
  "$CHMOD" 700 "$STATE" || die "could not chmod state dir"
  "$FIND" "$STATE" -mindepth 1 -maxdepth 1 ! -type f -exec "$RM" -rf -- {} + 2>/dev/null || true
  "$FIND" "$STATE" -mindepth 1 -maxdepth 1 -type f -exec "$CHMOD" 600 -- {} + 2>/dev/null || true
}

cmd_init() {
  ensure_state
}

cmd_fetch() {
  ensure_state
  set -o pipefail
  local t got
  t="$("$MKTEMP" -p "$STATE" .fetch.XXXXXXXXXX)"
  "$TIMEOUT" -k 2 12 "$CURL" -q -fsS \
    --proto =https --proto-redir =https \
    --max-time 10 \
    --max-redirs 0 \
    --max-filesize "$MAX" \
    --noproxy '*' \
    -- \
    "$FEED_URL" | "$HEAD" -c $((MAX + 1)) > "$t" || {
    /usr/bin/rm -f -- "$t"
    die "fetch failed"
  }
  got="$("$WC" -c < "$t")"
  got="${got// /}"
  if (( got > MAX )); then
    /usr/bin/rm -f -- "$t"
    die "feed too large"
  fi
  /usr/bin/cat "$t"
  /usr/bin/rm -f -- "$t"
}

cmd_read() {
  local name="$1"
  name_ok "$name" || die "bad name"
  ensure_state
  local file="$STATE/${name}.json"
  if [[ -L "$file" ]]; then
    die "state file is a symlink"
  fi
  if [[ ! -e "$file" ]]; then
    exit 2
  fi
  local t got
  t="$("$MKTEMP" -p "$STATE" .read.XXXXXXXXXX)"
  "$DD" if="$file" of="$t" iflag=nofollow,nonblock,count_bytes,fullblock \
    bs=4096 count=$(( (MAX + 1 + 4095) / 4096 )) status=none || {
    /usr/bin/rm -f -- "$t"
    die "read failed"
  }
  got="$("$WC" -c < "$t")"
  got="${got// /}"
  if (( got > MAX )); then
    /usr/bin/rm -f -- "$t"
    die "state file too large"
  fi
  /usr/bin/cat "$t"
  /usr/bin/rm -f -- "$t"
}

cmd_write() {
  local name="$1"
  name_ok "$name" || die "bad name"
  ensure_state
  local dest="$STATE/${name}.json"
  local hdr n t got
  IFS= read -r hdr || die "missing length"
  [[ "$hdr" =~ ^[0-9]{1,8}$ ]] || die "bad length"
  n=$((10#$hdr))
  (( n >= 1 && n <= MAX )) || die "length out of range"
  t="$("$MKTEMP" -p "$STATE" .tmp.XXXXXXXXXX)"
  "$DD" of="$t" bs=1 count="$n" iflag=fullblock,count_bytes status=none || {
    /usr/bin/rm -f -- "$t"
    die "write failed"
  }
  got="$("$WC" -c < "$t")"
  got="${got// /}"
  if (( got != n )); then
    /usr/bin/rm -f -- "$t"
    die "short write"
  fi
  "$CHMOD" 600 "$t"
  "$MV" -f -T -- "$t" "$dest"
}

op="${1:-}"
shift || true
case "$op" in
  init) cmd_init ;;
  fetch) cmd_fetch ;;
  read) cmd_read "${1:-}" ;;
  write) cmd_write "${1:-}" ;;
  *) die "usage: io.sh init|fetch|read NAME|write NAME" ;;
esac
