# super-plex

Your own Netflix at home: a Docker stack that serves your films and series to
your TV, phone, Chromecast or browser, and can download and organise new
episodes automatically.

| Service | What it does | Address |
|---|---|---|
| **Plex** | Media server: streams your library to every device at home | `http://SERVER_IP:32400/web` |
| **Samba** | Network folders so you can drag files onto the server from any computer | `\\SERVER_IP\media` (Windows) / `smb://SERVER_IP/media` (Mac) |
| **Transmission** | Torrent client with a web UI | `http://SERVER_IP:9091` |
| **FlexGet** | Every 30 min: copies finished downloads into the library (renamed so Plex recognises them), fetches new episodes of your shows from an RSS feed, and cleans up seeded torrents | — |

Runs on Linux (recommended: a mini-PC, NAS or Raspberry Pi 4/5 with a USB
disk, left on all the time), and also on Mac/Windows with Docker Desktop.

## 1. Install Docker

- Linux / Raspberry Pi: `curl -fsSL https://get.docker.com | sh`, then `sudo usermod -aG docker $USER` and log out and back in.
- Mac / Windows: install [Docker Desktop](https://www.docker.com/products/docker-desktop/).

## 2. Configure

```bash
git clone <this repo> super-plex && cd super-plex
cp .env.example .env
```

Edit `.env`:

- `MEDIA`: the folder holding your library. Films go in `MEDIA/movies`, series in `MEDIA/series`.
- `STORAGE`: where configs, the Plex database and torrent downloads go. On a Raspberry Pi, put both on the USB disk, not the SD card.
- `PUID` / `PGID`: output of `id -u` and `id -g`, so files are owned by you.
- `TZ`: your time zone.
- **Change the Samba and Transmission passwords.**

## 3. Start

```bash
# Linux
docker compose up -d --build

# Mac / Windows (Docker Desktop has no host networking)
docker compose -f docker-compose.yml -f docker-compose.desktop.yml up -d --build
```

Run `docker compose ps` and check that every container is `running`. If one
keeps restarting, run `docker compose logs <name>` to see why.

## 4. Set up Plex (first time only)

1. Open `http://SERVER_IP:32400/web` and sign in with a free Plex account.
   (On Mac/Windows, if it doesn't offer to set up a new server, start again with
   a `PLEX_CLAIM` token from <https://plex.tv/claim> in `.env`.)
2. Name the server, then **Add Library**:
   - **Movies** → folder `/media/movies`
   - **TV Shows** → folder `/media/series`
3. **Settings → Library**: turn on **Scan my library automatically**, so new
   files appear on their own.
4. Install the Plex app on your TV, phone or console and sign in with the same
   account.

### Avoid slow, stuttering playback

Weak servers like a Raspberry Pi can't convert video on the fly (transcoding).
In **each client app** (phone, TV), open **Settings → Quality** and set:

- Home streaming / Remote streaming / Music quality → **Maximum / Original**
- Turn **off** "Limit cellular data" and "Automatically adjust quality"

The video then plays as-is ("Direct Play"). The FlexGet sort step also converts
E-AC3 audio, which Chromecast can't play directly, to AC3.

## Adding films

**By hand:** copy files over the `media` network share into `movies/` or
`series/`, named like this:

```
movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).mp4
series/Show Name/Season 1/Show.Name.S01E01.mkv
```

**With Transmission:** open `http://SERVER_IP:9091`, add a `.torrent` file or
magnet link, and keep the default download folder (`/downloads/complete`). When
it finishes, FlexGet copies it into the library within 30 minutes, detecting
the title, year, show and season from the file name. To test, try the
public-domain film *Big Buck Bunny* from <https://peach.blender.org/download/>.

Run the sort now instead of waiting:

```bash
docker compose exec flexget flexget -c /data/config.yml execute --tasks sort-movies sort-series
```

If a file is skipped because FlexGet already handled it, clear it and retry:

```bash
docker compose exec flexget flexget -c /data/config.yml seen forget "<file name or title>"
```

## Automatic series downloads (optional)

In `flexget/config.yml`, under the `download-series` task:

1. Replace the `rss:` URL with a torrent RSS feed you're allowed to use.
2. List your shows under `series → default`.
3. Add `download-series` to the `schedules` list at the top.
4. Run `docker compose restart flexget`.

New episodes are then downloaded in 720p (skipping x265 releases; change
`quality` for 1080p or 2160p), copied into `series/`, and removed from
Transmission once they've seeded to ratio 1.

## Tips

- **Bandwidth:** in Transmission, open **Edit preferences → Speed** to limit upload
  speed or schedule "alternative speeds" during the day.
- **Watching away from home:** in Plex, go to **Settings → Remote Access** and
  forward port 32400 on your router.
- **Hardware transcoding:** needs Plex Pass. Uncomment the `devices` block for
  the `plex` service.
- **Updating:** `docker compose pull && docker compose up -d --build`
- **Backups:** everything that matters lives in `STORAGE/` (configs, Plex
  database) and `MEDIA/`.

Only download and share content you own or have the right to use.
