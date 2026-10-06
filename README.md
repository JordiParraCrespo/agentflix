# super-plex

Plex Media Server for watching your films at home, run with Docker.

## Setup

1. Install [Docker](https://docs.docker.com/get-docker/) on the machine that will be your server (a PC, NAS, mini-PC or Raspberry Pi 4/5).
2. Configure:
   ```bash
   cp .env.example .env     # set MEDIA_DIR, TZ, and optionally PLEX_CLAIM
   id -u; id -g             # use these values for PUID / PGID
   ```
3. Organise your films:
   ```
   $MEDIA_DIR/movies/Inception (2010)/Inception (2010).mkv
   $MEDIA_DIR/tv/Show Name/Season 01/Show Name - S01E01.mkv
   ```
4. Start it:
   ```bash
   docker compose up -d
   ```
5. Open <http://SERVER_IP:32400/web>, sign in with a free Plex account, and add libraries:
   **Movies → `/movies`**, **TV Shows → `/tv`**.
6. Install the Plex app on your TV, phone or console and sign in. It finds the server automatically on your home network.

## Maintenance

```bash
docker compose pull && docker compose up -d   # update
docker compose logs -f plex                   # logs
docker compose down                           # stop
```

Your Plex settings and library database live in `./config` — back it up.

## Notes

- Uses `network_mode: host` so devices on your LAN discover the server; this works on Linux. On Docker Desktop (Mac/Windows) replace it with `ports: ["32400:32400"]`.
- Hardware transcoding needs a Plex Pass; uncomment the `devices` block for Intel GPUs.
- Only add media you own or have the right to use.
