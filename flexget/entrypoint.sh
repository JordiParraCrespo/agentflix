#!/bin/sh
# Starts the FlexGet daemon as PUID:PGID so copied files are owned by you.
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

mkdir -p /data
cp /config/config.yml /data/config.yml

# Credentials come from .env, so they only live in one place.
cat > /data/variables.yml <<VARS
transmission:
  user: "${TRANSMISSION_USER}"
  password: "${TRANSMISSION_PASSWORD}"
VARS

chown -R "$PUID:$PGID" /data
# Remove a stale lock left behind if the container was killed.
rm -f /data/.config-lock

exec gosu "$PUID:$PGID" flexget -c /data/config.yml daemon start
