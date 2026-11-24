#!/bin/bash
# Installs the WhatsApp bridge as a LaunchAgent on this Mac (com.jc.whatsapp).
# Runtime lives outside ~/Documents: launchd can't run binaries there (TCC).
# The repo's whatsapp-bridge/store becomes a symlink to the runtime store,
# so the MCP server keeps finding messages.db at its usual path.
set -euo pipefail
umask 077

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$HOME/.local/share/air-apps/whatsapp-bridge"
LABEL="com.jc.whatsapp"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

cd "$REPO/whatsapp-bridge"
go build -o whatsapp-bridge .

# Stop the running service (if any) before touching the store
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
# Two bridges on one session fight over the connection: stop every copy
pkill -x whatsapp-bridge 2>/dev/null || true
sleep 1

mkdir -p "$RUNTIME/state"
install -m 700 whatsapp-bridge "$RUNTIME/whatsapp-bridge"

# First install: move the real store (session keys + messages) to the runtime
if [ -d store ] && [ ! -L store ]; then
  if [ -e "$RUNTIME/store" ]; then
    echo "Both $REPO/whatsapp-bridge/store and $RUNTIME/store exist; resolve by hand." >&2
    exit 1
  fi
  rm -f store/bridge.log store/qr.txt
  mv store "$RUNTIME/store"
  ln -s "$RUNTIME/store" store
fi
chmod 700 "$RUNTIME/store"

sed "s#__RUNTIME__#$RUNTIME#g" "$REPO/deploy/$LABEL.plist" > "$PLIST"
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $LABEL (runtime: $RUNTIME)"
