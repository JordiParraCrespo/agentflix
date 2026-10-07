#!/bin/sh
# Creates the folder layout from .env with the right owner. Safe to re-run.
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found: run 'cp .env.example .env' and edit it first." >&2
  exit 1
fi
set -a; . ./.env; set +a

for d in \
  "$DATA/torrents/movies" "$DATA/torrents/tv" \
  "$DATA/media/movies" "$DATA/media/tv" \
  "$CONFIG/jellyfin" "$CONFIG/seerr" "$CONFIG/radarr" "$CONFIG/sonarr" \
  "$CONFIG/prowlarr" "$CONFIG/bazarr" "$CONFIG/qbittorrent"
do
  mkdir -p "$d"
done

chown -R "$PUID:$PGID" "$DATA" "$CONFIG"
echo "Folders ready in $DATA and $CONFIG"

if [ -d /dev/dri ]; then
  echo "GPU found (/dev/dri): uncomment COMPOSE_FILE in .env for hardware transcoding."
fi
