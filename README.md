# super-plex

Your own Netflix at home, built on Jellyfin (free and open source) with
automatic downloads. Search for a film or series, click **Request**, and it
appears in Jellyfin on your TV a little later, with subtitles.

| App | What it does | Address |
|---|---|---|
| **Jellyfin** | Media server: streams your library to TV, phone, browser, Chromecast | `http://SERVER_IP:8096` |
| **Seerr** | Netflix-style page to browse and request films/series | `http://SERVER_IP:5055` |
| **Radarr** | Finds, downloads, renames and upgrades **films** | `http://SERVER_IP:7878` |
| **Sonarr** | Same for **series**, including new episodes as they air | `http://SERVER_IP:8989` |
| **Prowlarr** | Manages download sources (indexers) for Radarr and Sonarr | `http://SERVER_IP:9696` |
| **Bazarr** | Downloads subtitles in your languages | `http://SERVER_IP:6767` |
| **qBittorrent** | Torrent client that does the downloading | `http://SERVER_IP:8080` |
| **Samba** | Network folders to copy your own files in | `\\SERVER_IP\media` |

```
Seerr ──request──▶ Radarr / Sonarr ──search──▶ Prowlarr
                        │
                        ├──send torrent──▶ qBittorrent ──▶ /data/torrents
                        │
                        └──hardlink + rename──▶ /data/media ──▶ Jellyfin ──▶ your TV
                                                    ▲
                                          Bazarr adds subtitles
```

## The hardware: Dell OptiPlex Micro

A good choice for this: small, quiet, low power, and its Intel CPU has
**Quick Sync**, a built-in video engine that lets Jellyfin convert video for
any device without straining the CPU.

- **Disks:** keep the SSD for the operating system and app settings (`CONFIG`).
  Put films on a bigger drive (`DATA`), such as a USB 3 external disk or a larger
  SSD in the 2.5" bay, with the OS on an M.2 NVMe if your model has the slot.
  `DATA` must be **one** disk so downloads can be hardlinked into the library.
- **BIOS** (F2 at boot): set **Power Management → AC Recovery → Power On**, so
  it restarts by itself after a power cut.
- **CPU generation** (run `lscpu | grep "Model name"` once Linux is installed):
  6th gen (i5-6500T etc.) handles H.264 and 8-bit HEVC; 7th gen and newer also
  handle 10-bit HEVC (most 4K files).

## 1. Install Linux and Docker

1. Install **Ubuntu Server 24.04 LTS** (or Debian) on the SSD from a USB stick.
   Enable "OpenSSH server" during install so you can manage it from your laptop.
2. Install Docker:
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER   # then log out and back in
   ```
3. Plug in and mount the media disk, for example at `/srv/data`. Ubuntu's docs
   explain how to add it to `/etc/fstab` so it mounts at boot.
4. Give the server a fixed IP in your router (look for "DHCP reservation").

## 2. Configure and start

```bash
git clone <this repo> super-plex && cd super-plex
cp .env.example .env
nano .env          # set DATA, CONFIG, PUID/PGID (from `id -u` / `id -g`), SAMBA_PASSWORD
sudo ./setup.sh    # creates the folders with the right owner
docker compose up -d
docker compose ps  # everything should say "running"
```

If something keeps restarting: `docker compose logs <name>`.

## 3. Connect the apps (once, about 20 minutes)

Inside the stack, apps reach each other by name, e.g. `http://radarr:7878`.
Set a login on each app the first time it asks.

**qBittorrent** (`:8080`)
1. User `admin`. The temporary password is in `docker compose logs qbittorrent`.
   Set a new one in **Tools → Options → Web UI**.
2. **Options → Downloads**: set **Default Torrent Management Mode** to
   **Automatic** and **Default Save Path** to `/data/torrents`. Torrents then
   land in `/data/torrents/movies` or `/data/torrents/tv` by category.

**Prowlarr** (`:9696`)
1. **Indexers → Add**: add the sources you're allowed to use.
2. **Settings → Apps**: add **Radarr** (`http://radarr:7878`) and **Sonarr**
   (`http://sonarr:8989`), pasting each app's API key from its
   **Settings → General**. Prowlarr then syncs the indexers to both.

**Radarr** (`:7878`) and **Sonarr** (`:8989`), same steps in each:
1. **Settings → Media Management → Add Root Folder**: `/data/media/movies`
   (Radarr) or `/data/media/tv` (Sonarr). Leave **Use Hardlinks** on.
2. **Settings → Download Clients → qBittorrent**: host `qbittorrent`, port
   `8080`, your login, category `movies` (Radarr) or `tv` (Sonarr).
3. **Settings → Profiles**: pick your quality (e.g. 1080p) and, under
   **Language**, Spanish/English/Any.

**Bazarr** (`:6767`)
1. **Settings → Sonarr / Radarr**: hosts `sonarr` / `radarr`, plus their API keys.
2. **Settings → Languages**: create a profile (e.g. Spanish + English) and set
   it as the default. **Settings → Providers**: add a few, e.g. OpenSubtitles.com.

**Jellyfin** (`:8096`)
1. Create your admin user and add libraries: **Movies → `/data/media/movies`**,
   **Shows → `/data/media/tv`**. Preferred language: Spanish.
2. **Hardware transcoding:** **Dashboard → Playback → Transcoding**, set
   **Hardware acceleration** to **Intel QuickSync (QSV)**, then tick the codecs
   your CPU supports (H264, HEVC, and on 7th gen+ also HEVC 10bit). If playback
   fails, try **VAAPI** instead.
3. Create a user for each person in the house.

**Seerr** (`:5055`)
1. Choose **Jellyfin**, server `http://jellyfin:8096`, sign in with your
   Jellyfin admin.
2. Add **Radarr** (`radarr`, 7878) and **Sonarr** (`sonarr`, 8989) with their
   API keys, root folders and quality profiles. Mark both as default.
3. Import your Jellyfin users so the family can log in and make requests.

Done. Request something in Seerr and watch it go through the queues in Radarr
or Sonarr, then appear in Jellyfin.

## 4. Watch

Install **Jellyfin** on your TV (Android TV / Google TV, LG webOS, Samsung
Tizen, Fire TV, Apple TV via Swiftfin or Infuse), phone or tablet, or open
`http://SERVER_IP:8096` in a browser. Apps on your home network find the server
automatically. It's all free, with no account and no subscription.

## Your own files

Copy them over the network share: on Windows open `\\SERVER_IP\media`, on Mac
use **Finder → Go → Connect to Server**, `smb://SERVER_IP/media`. User:
`media`, with your `SAMBA_PASSWORD`. Name them so Jellyfin recognises them:

```
movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).mkv
tv/Show Name (2020)/Season 01/Show Name S01E01.mkv
```

Or put them in `torrents/` and use **Wanted → Manual Import** in Radarr or
Sonarr to rename and move them for you.

## Optional extras

**Watch away from home: Tailscale (recommended).** Install
[Tailscale](https://tailscale.com/download) on the server
(`curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`) and
on your phone or laptop. Then `http://SERVER_NAME:8096` works from anywhere,
encrypted, without opening any port on your router. Free for personal use.

**VPN for downloads.** To send only qBittorrent's traffic through a VPN, fill in
the `VPN_*` values in `.env` (see the
[gluetun provider guides](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers))
and start with:

```bash
docker compose -f docker-compose.yml -f docker-compose.vpn.yml up -d
```

Then change the qBittorrent host in Radarr and Sonarr from `qbittorrent` to `gluetun`.

## Maintenance

```bash
docker compose pull && docker compose up -d   # update everything
docker image prune -f                          # free space from old versions
```

Back up the `CONFIG` folder: it holds all your settings and watch history.

Only download content you own or have the right to use.
