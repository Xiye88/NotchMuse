#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
FEED="$ROOT/dist.noindex/final-staged/feed"
LABEL="app.notchmuse.preview-appcast"
DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOGS="$ROOT/dist.noindex/final-staged/server-logs"
URL="http://127.0.0.1:1337/appcast.xml"

case "${1:-}" in
  start)
    [[ -f "$FEED/appcast.xml" ]] || {
      echo "Missing staged feed: $FEED/appcast.xml" >&2
      exit 1
    }
    if launchctl print "$SERVICE" >/dev/null 2>&1; then
      echo "Service already loaded; use status, or stop before restarting." >&2
      exit 1
    fi
    if lsof -nP -iTCP:1337 -sTCP:LISTEN >/dev/null 2>&1; then
      echo "Port 1337 is already in use; no existing process was stopped." >&2
      exit 1
    fi
    PYTHON="$(command -v python3)"
    mkdir -p "$(dirname "$PLIST")" "$LOGS"
    "$PYTHON" - "$PLIST" "$LABEL" "$FEED" "$LOGS" <<'PY'
import os
import plistlib
import sys

path, label, feed, logs = sys.argv[1:]
job = {
    "Label": label,
    "ProgramArguments": [os.path.realpath(sys.executable), "-u", "-m", "http.server",
                         "1337", "--bind", "127.0.0.1", "--directory", feed],
    "WorkingDirectory": feed,
    "RunAtLoad": True,
    "KeepAlive": True,
    "ThrottleInterval": 5,
    "StandardOutPath": os.path.join(logs, "stdout.log"),
    "StandardErrorPath": os.path.join(logs, "stderr.log"),
}
with open(path, "wb") as output:
    plistlib.dump(job, output)
PY
    plutil -lint "$PLIST"
    launchctl bootstrap "$DOMAIN" "$PLIST"
    for attempt in {1..20}; do
      if curl --noproxy '*' --fail --silent --max-time 1 "$URL" >/dev/null; then
        echo "Serving $FEED at $URL (launchd KeepAlive)"
        exit 0
      fi
      sleep 0.25
    done
    echo "Service loaded but feed is not reachable; inspect $LOGS and run status." >&2
    exit 1
    ;;
  stop)
    if launchctl print "$SERVICE" >/dev/null 2>&1; then
      launchctl bootout "$SERVICE"
    fi
    if [[ -f "$PLIST" ]]; then
      rm "$PLIST"
    fi
    echo "Stopped $LABEL; staged feed preserved."
    ;;
  status)
    launchctl print "$SERVICE"
    curl --noproxy '*' --fail --silent --show-error --max-time 3 -o /dev/null "$URL"
    echo "Feed reachable: $URL"
    ;;
  *)
    echo "Usage: $0 {start|stop|status}" >&2
    exit 2
    ;;
esac
